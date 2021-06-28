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
#' @return Modified version of the `gtfs` input with additional transfers table.
#'
#' @export
#'
#' @examples
#' berlin_gtfs_to_zip ()
#' f <- file.path (tempdir (), "vbb.zip")
#' g <- extract_gtfs (f, quiet = TRUE)
#' g <- gtfs_transfer_table (g, d_limit = 200)
#' # g$transfers then has fewer rows than original, because original transfer
#' # table contains duplicated rows.
gtfs_transfer_table <- function (gtfs, d_limit = 200, min_transfer_time = 120,
                                 network = NULL, network_times = FALSE) {

    if (is.null (network) & network_times)
        network <- dl_net (gtfs)

    stop_service <- join_service_id_to_stops (gtfs)

    transfers <- get_transfer_list (gtfs, stop_service, d_limit)

    if (network_times) {
        message ("The following stages may take some time. ",
                 "Please be patient.")
        transfer_times <- get_network_times (network, transfers)
    } else {
        xyf <- transfers [, c ("from_lon", "from_lat")]
        xyt <- transfers [, c ("to_lon", "to_lat")]
        transfer_times <- geodist::geodist (xyf, xyt, paired = TRUE,
                                            measure = "haversine")
        # use max speed of 4km/h, as for OpenTripPlanner pedestrian speed
        # -> 4000 / 3600 = 1.11 m / s
        transfer_times <- transfer_times / 1.111111
    }

    transfer_times [transfer_times < min_transfer_time] <- min_transfer_time

    transfers <- data.table::data.table (from_stop_id = transfers$from,
                                 to_stop_id = transfers$to,
                                 transfer_type = 2,
                                 min_transfer_time = ceiling (transfer_times))

    index <- which (!duplicated (transfers [, c ("from_stop_id",
                                                 "to_stop_id")]))

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
    } else
        net <- readRDS (net_name)

    return (net)
}

# join service IDs on to stop table, so we can select only those stops
# that are part of different services
join_service_id_to_stops <- function (gtfs) {

    stop_service <- gtfs$stop_times [, c ("trip_id", "stop_id")]
    stop_service <- stop_service [!duplicated (stop_service), ]
    stop_service$services <- gtfs$trips$service_id [match (stop_service$trip_id,
                                                           gtfs$trips$trip_id)]
    stop_service$trip_id <- NULL
    stop_service <- stop_service [which (!duplicated (stop_service)), ]
    return (stop_service)
}

get_transfer_list <- function (gtfs, stop_service, d_limit) {

    message (cli::symbol$play,
             cli::col_green (" Finding neighbouring services for each stop"),
             appendLF = FALSE)

    # reduce down to unique (lon, lat) pairs:
    xy <- round (gtfs$stops [, c ("stop_lon", "stop_lat")], digits = 6)
    xy_char <- paste0 (xy$stop_lon, "==", xy$stop_lat)
    index <- which (!duplicated (xy_char))
    index_back <- match (xy_char, xy_char [index])

    stops <- gtfs$stops [index, ]
    requireNamespace ("geodist")
    d <- geodist::geodist (stops [, c ("stop_lon", "stop_lat")],
                           measure = "haversine")

    ss_serv <- stop_service [order (stop_service$services), ]
    ss_stop <- stop_service [order (stop_service$stop_id), ]

    transfers <- rcpp_transfer_nbs (stops, ss_serv, ss_stop, d, d_limit)

    names (transfers) <- stops$stop_id

    transfers <- transfers [index_back]
    message ("\r", cli::col_green (cli::symbol$tick,
                                   " Found neighbouring services for each stop"))

    index <- which (vapply (transfers, function (i)
                            length (i) > 0,
                            logical (1)))
    transfers <- transfers [index]
    for (i in seq (transfers)) {
        transfers [[i]] <- cbind (from = names (transfers) [i],
                                  to = transfers [[i]])
    }
    transfers <- data.frame (do.call (rbind, transfers),
                             stringsAsFactors = FALSE)
    transfers$from_lon <-
        stops$stop_lon [match (transfers$from, stops$stop_id)]
    transfers$from_lat <-
        stops$stop_lat [match (transfers$from, stops$stop_id)]
    transfers$to_lon <-
        stops$stop_lon [match (transfers$to, stops$stop_id)]
    transfers$to_lat <-
        stops$stop_lat [match (transfers$to, stops$stop_id)]
    transfers <- transfers [which (transfers$from != transfers$to), ]

    return (transfers)
}

get_network_times <- function (network, transfers) {

    # convert net to contracted dodgr form:
    message (cli::symbol$play,
             cli::col_green (" Contracting street network ... "))
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
    message (cli::col_green (cli::symbol$tick, " Contracted street network"))

    # then calculate network times:
    message (cli::symbol$play,
             cli::col_green (paste0 (" Calculating transfer times between ",
                                     length (from_to), " pairs of stops")))
    x <- dodgr::dodgr_times (netc, from = from_to, to = from_to)
    message (cli::col_green (cli::symbol$tick,
                             paste0 (" Calculated transfer times between ",
                                     length (from_to), " pairs of stops")))

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

    # remove any duplicated rows from original:
    index <- which (!duplicated (gtfs$transfers [, c ("from_stop_id", "to_stop_id")]))
    tr_old <- gtfs$transfers [index, c ("from_stop_id",
                                   "to_stop_id",
                                   "transfer_type",
                                   "min_transfer_time")]

    # Exclude any transfers with type == 3 in original table; see #76
    tr3_index <- which (tr_old$transfer_type == 3)
    if (length (tr3_index) > 0) {
        from_to_old <- paste0 (tr_old$from_stop_id [tr3_index],
                               "==",
                               tr_old$to_stop_id [tr3_index])
        from_to_new <- paste0 (transfers$from_stop_id,
                               "==",
                               transfers$to_stop_id)
        transfers <- transfers [which (!from_to_new %in% from_to_old), ]
    }

    transfers <- rbind (tr_old, transfers)
    # duplicates always indexes the first values, so will always retain the
    # original entries in favour of those generated in the `gtfs_transfer_table`
    # fn.
    index <- which (!duplicated (transfers [, c ("from_stop_id", "to_stop_id")]))
    gtfs$transfers <- transfers [index, ]

    return (gtfs)
}
