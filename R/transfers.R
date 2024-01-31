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
#' `net` parameter, it will be automatically downloaded. If a network, is
#' provided, this parameter is automatically set to `TRUE`.
#' @param quiet Set to `TRUE` to suppress screen messages
#'
#' @return Modified version of the `gtfs` input with additional transfers table.
#'
#' @examples
#' # Examples must be run on single thread only:
#' nthr <- data.table::setDTthreads (1)
#'
#' berlin_gtfs_to_zip ()
#' f <- file.path (tempdir (), "vbb.zip")
#' g <- extract_gtfs (f, quiet = TRUE)
#' g <- gtfs_transfer_table (g, d_limit = 200)
#' # g$transfers then has fewer rows than original, because original transfer
#' # table contains duplicated rows.
#'
#' data.table::setDTthreads (nthr)
#' @family augment
#' @export
gtfs_transfer_table <- function (gtfs,
                                 d_limit = 200,
                                 min_transfer_time = 120,
                                 network = NULL,
                                 network_times = FALSE,
                                 quiet = FALSE) {

    if ("timetable" %in% names (gtfs)) {
        stop (
            "The 'gtfs_transfer_table' function must be called BEFORE ",
            "the 'gtfs_timetable' function. Please re-load the feed, ",
            "directly call this function, and then call ",
            "'gtfs_timetable'.",
            call. = FALSE
        )
    }

    if (is.null (network) && network_times) {
        network <- dl_net (gtfs)
    } else if (!is.null (network)) {
        network_times <- TRUE
    }

    # d_limit in r5 is 1000m on street networks:
    # https://github.com/conveyal/r5/blob/dev/src/main/java/com/conveyal/r5/transit/TransitLayer.java#L69-L73 # nolint
    # implemented at:
    # https://github.com/conveyal/r5/blob/dev/src/main/java/com/conveyal/r5/transit/TransferFinder.java#L128 # nolint
    # This identifies all potential transfers within straight-line distances of
    # 'd_limit':
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

        # use max speed of 4km/h, as for OpenTripPlanner pedestrian speed
        # -> 4000 / 3600 = 1.11 m / s
        # transfer_times <- transfers$d / 1.111111
        # ... but dodgr uses a max ped speed of 5 km/hr, which is then
        # 5 * 1000 / 3600 ~= 1.4 m / 2
        transfer_times <- transfers$d * 5 * 1000 / 3600
    }

    transfer_times [transfer_times < min_transfer_time] <- min_transfer_time

    transfers <- data.table::data.table (
        from_stop_id = transfers$from,
        to_stop_id = transfers$to,
        transfer_type = 2,
        d = transfers$d,
        min_transfer_time = ceiling (transfer_times)
    )

    # See #114: data.table::duplicated currently segfaults (Jan 2024):
    ft <- data.frame (transfers [, c ("from_stop_id", "to_stop_id")])
    index <- which (!duplicated (ft))
    transfers <- transfers [index, ]

    # Those transfers only include times, but these may then correspond to
    # actual transfer distances beyond 'd_limit', so calculat effective
    # distances, and reduce to actual 'd_limit' of network times. (This will
    # have no effect for non-network times.)
    #
    # 'dodgr' weighting of pedestrian networks uses a default maximal speed of 5
    # km/h.
    ped_speed <- 5 * 1000 / 3600 # ~ 1.4 m/s
    transfer_dists <- transfers$min_transfer_time / ped_speed
    index <- which (transfer_dists < d_limit)
    transfers <- transfers [index, ]
    transfer_dists <- transfer_dists [index]

    # Finally, where the GTFS feed extends beyond the spatial boundaries of the
    # network, resultant network times may be anomalously low. These will be
    # reflected in transfer_dists < actual network distances. Times for any such
    # cases are then replaced by equivalent straight-line times.
    index <- which (transfer_dists < transfers$d)
    transfers$min_transfer_time [index] <-
        ceiling (transfers$d [index] * 5 * 1000 / 3600)
    transfers$d <- NULL

    gtfs <- append_to_transfer_table (gtfs, transfers)

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

    transfers <- rcpp_transfer_nbs (gtfs$stops, d_limit)
    nstops <- nrow (gtfs$stops)
    index <- seq (nstops)
    dists <- transfers [index + nstops]
    transfers <- transfers [index]

    lens <- vapply (transfers, length, integer (1))
    for (i in which (lens > 0)) {
        transfers [[i]] <- cbind (
            from = gtfs$stops$stop_id [i],
            to = gtfs$stops$stop_id [transfers [[i]]],
            d = dists [[i]]
        )
    }
    transfers <- data.frame (do.call (rbind, transfers),
        stringsAsFactors = FALSE
    )

    index <- match (transfers$from, gtfs$stops$stop_id)
    transfers$from_lon <- gtfs$stops$stop_lon [index]
    transfers$from_lat <- gtfs$stops$stop_lat [index]

    index <- match (transfers$to, gtfs$stops$stop_id)
    transfers$to_lon <- gtfs$stops$stop_lon [index]
    transfers$to_lat <- gtfs$stops$stop_lat [index]

    transfers$d <- as.numeric (transfers$d)

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
    from_ids <- v$id [dodgr::match_points_to_verts (v, xyf)]
    to_ids <- v$id [dodgr::match_points_to_verts (v, xyt)]
    from_to <- unique (c (from_ids, to_ids))

    netc <- dodgr::dodgr_contract_graph (net, verts = from_to)

    if (!quiet) {
        message (cli::col_green (
            cli::symbol$tick,
            " Contracted street network"
        ))

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
