#' gtfs_transfer_table
#'
#' Construct a transfer table for a GTFS feed.
#'
#' @param gtfs A GTFS feed obtained from the \link{extract_gtfs} function.
#' @param d_limit Upper straight-line distance limit in metres for transfers.
#' @param min_transfer_time Minimum time in seconds for transfers; all values
#' below this will be replaced with this value, particularly all those defining
#' in-place transfers where stop longitudes and latitudes remain identical.
#' @param network Optional Open Street Map representation of the street network
#' encompassed by the GTFS feed (see Examples).
#' @param network_times If `TRUE`, transfer times are calculated by routing
#' throughout the underlying street network. If this is not provided as the
#' `net` parameter, it will be automatically downloaded.
#' @param quiet Set to `TRUE` to suppress screen messages
#'
#' @return Modified version of the `gtfs` input with additional transfers table.
#'
#' @examples
#' berlin_gtfs_to_zip ()
#' f <- file.path (tempdir (), "vbb.zip")
#' g <- extract_gtfs (f, quiet = TRUE)
#' g <- gtfs_transfer_table (g, d_limit = 200)
#' # g$transfers then has fewer rows than original, because original transfer
#' # table contains duplicated rows.
#'
#' @family augment
#' @export
gtfs_transfer_table <- function (gtfs,
                                 d_limit = 200,
                                 min_transfer_time = 120,
                                 network = NULL,
                                 network_times = FALSE,
                                 quiet = FALSE) {

    if (is.null (network) & network_times) {
        network <- dl_net (gtfs)
    }

    transfers <- get_transfer_list (gtfs, d_limit)

    if (network_times) {

        if (!quiet) {
            message (
                "The following stages may take some time. ",
                "Please be patient."
            )
        }

        transfer_times <- get_network_times (network, transfers, quiet)

    } else {

        xyf <- transfers [, c ("from_lon", "from_lat")]
        xyt <- transfers [, c ("to_lon", "to_lat")]
        transfer_times <- geodist::geodist (
            xyf,
            xyt,
            paired = TRUE,
            measure = "haversine"
        )
        # use max speed of 4km/h, as for OpenTripPlanner pedestrian speed
        # -> 4000 / 3600 = 1.11 m / s
        transfer_times <- transfer_times / 1.111111
    }

    transfer_times [transfer_times < min_transfer_time] <- min_transfer_time

    transfers <- data.table::data.table (
        from_stop_id = transfers$from,
        to_stop_id = transfers$to,
        transfer_type = 2,
        min_transfer_time = ceiling (transfer_times)
    )

    index <- which (!duplicated (transfers [, c (
        "from_stop_id",
        "to_stop_id"
    )]))

    gtfs <- append_to_transfer_table (gtfs, transfers [index, ])

    return (gtfs)
}

dl_net <- function (gtfs) {

    stops <- gtfs$stops [, c ("stop_lon", "stop_lat")]
    requireNamespace ("digest")
    hash <- digest::digest (stops)
    net_name <- file.path (tempdir (), paste0 ("net", hash, ".Rds"))

    if (!file.exists (net_name)) {
        requireNamespace ("dodgr")
        net <- dodgr::dodgr_streetnet_sc (pts = stops)
        saveRDS (net, file = net_name)
    } else {
        net <- readRDS (net_name)
    }

    return (net)
}

get_transfer_list <- function (gtfs, d_limit) {

    # reduce down to unique (lon, lat) pairs:
    xy <- round (gtfs$stops [, c ("stop_lon", "stop_lat")], digits = 6)
    xy_char <- paste0 (xy$stop_lon, "==", xy$stop_lat)
    index <- which (!duplicated (xy_char))
    index_back <- lapply (xy_char [index], function (i) {
        which (xy_char == i)
    })

    stops <- gtfs$stops

    requireNamespace ("geodist")
    d <- geodist::geodist (stops [index, c ("stop_lon", "stop_lat")],
        measure = "haversine"
    )

    nbs <- apply (d, 1, function (i) {
        j <- which (i <= d_limit & !is.na (i))
        ret <- integer (0)
        if (length (j) > 0) {
            ret <- unlist (lapply (j, function (k) {
                index_back [[k]]
            }))
        }
        return (ret) })

    nbs <- lapply (seq_along (nbs), function (i) {
        out <- c (nbs [[i]], index_back [[i]])
        out <- sort (unique (out))
        return (out [which (!out == i)])
    })
    index_back <- match (xy_char, xy_char [index])
    transfers <- nbs [index_back]

    lens <- vapply (transfers, length, integer (1))
    for (i in which (lens > 0)) {
        transfers [[i]] <- cbind (
            from = gtfs$stops$stop_id [i],
            to = gtfs$stops$stop_id [transfers [[i]]]
        )
    }
    transfers <- data.frame (do.call (rbind, transfers),
        stringsAsFactors = FALSE
    )

    index <- match (transfers$from, stops$stop_id)
    transfers$from_lon <- stops$stop_lon [index]
    transfers$from_lat <- stops$stop_lat [index]

    index <- match (transfers$to, stops$stop_id)
    transfers$to_lon <- stops$stop_lon [index]
    transfers$to_lat <- stops$stop_lat [index]

    return (transfers)
}

get_network_times <- function (network, transfers, quiet = FALSE) {

    # convert net to contracted dodgr form:
    if (!quiet) {
        message (
            cli::symbol$play,
            cli::col_green (" Contracting street network ... ")
        )
    }

    requireNamespace ("dodgr")
    dodgr::dodgr_cache_off ()
    net <- dodgr::weight_streetnet (network, wt_profile = "foot")
    net <- net [net$component == 1, ]
    v <- dodgr::dodgr_vertices (net)

    xyf <- transfers [, c ("from_lon", "from_lat")]
    xyt <- transfers [, c ("to_lon", "to_lat")]
    from_ids <- v$id [dodgr::match_points_to_graph (v, xyf)]
    to_ids <- v$id [dodgr::match_points_to_graph (v, xyt)]
    from_to <- unique (c (from_ids, to_ids))

    netc <- dodgr::dodgr_contract_graph (net, verts = from_to)

    if (!quiet) {
        message (cli::col_green (cli::symbol$tick, " Contracted street network"))

        message (
            cli::symbol$play,
            cli::col_green (
                " Calculating transfer times between ",
                length (from_to), " pairs of stops"
            )
        )
    }

    x <- dodgr::dodgr_times (netc, from = from_to, to = from_to)

    if (!quiet) {
        message (cli::col_green (
            cli::symbol$tick,
            " Calculated transfer times between ",
            length (from_to), " pairs of stops"
        ))
    }

    from_index <- match (from_ids, from_to)
    to_index <- match (to_ids, from_to)
    x [to_index + (from_index - 1) * nrow (x)]
}

#' Append new transfer table to pre-existing one if present
#'
#' @param gtfs The original feed which may or may not have a transfers table
#' @param transfers New transfer table constructed from main body of
#' `gtfs_transfer_table` function.
#'
#' @note "transfers.txt" may have additional columns which are discarded here
#' (such as 'from/to_route_id' or 'from/to_trip_id'), so the result may remove
#' information from original transfer tables.
#' @noRd
append_to_transfer_table <- function (gtfs, transfers) {

    if (!"transfers" %in% names (gtfs)) {

        gtfs$transfers <- transfers
        return (gtfs)
    }


    # Exclude any transfers with type == 3 in original table; see #76
    # These generally prohibit connectiosn between specified routes or services,
    # but including them as general transfers in a table will nevertheless
    # automatically connect these. Current approach is to just remove these,
    # although that should be done better ...
    tr_old <- gtfs$transfers
    tr3_index <- which (tr_old$transfer_type == 3)
    if (length (tr3_index) > 0) {
        from_to_old <- paste0 (
            tr_old$from_stop_id [tr3_index],
            "==",
            tr_old$to_stop_id [tr3_index]
        )
        from_to_new <- paste0 (
            transfers$from_stop_id,
            "==",
            transfers$to_stop_id
        )
        transfers <- transfers [which (!from_to_new %in% from_to_old), ]
    }

    # Expand table columns to match previous table:
    index <- which (!names (tr_old) %in% names (transfers))
    n <- nrow (transfers)
    for (i in index) {
        fn <- class (tr_old [[i]])
        nm_i <- names (tr_old) [i]
        if (fn == "character") {
            transfers [[nm_i]] <- rep (do.call (fn, list (1)), n)
        } else {
            transfers [[nm_i]] <- rep (NA, n)
            storage.mode (transfers [[nm_i]]) <- fn
        }
    }

    # Finally remove any new transfers that are in original table
    from_to_old <- paste0 (tr_old$from_stop_id, "==", tr_old$to_stop_id)
    from_to_new <- paste0 (transfers$from_stop_id, "==", transfers$to_stop_id)
    transfers <- transfers [which (!from_to_new %in% from_to_old), ]

    gtfs$transfers <- rbind (tr_old, transfers)

    return (gtfs)
}
