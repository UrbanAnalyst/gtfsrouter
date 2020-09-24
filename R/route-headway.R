
headway_times <- function (gtfs, start_stns, end_stns, start_time) {
    from_to_are_ids <- include_ids <- FALSE
    max_transfers <- .Machine$integer.max
    route <- rcpp_csa (gtfs$timetable, gtfs$transfers,
                       nrow (gtfs$stop_ids), nrow (gtfs$trip_ids),
                       start_stns, end_stns, start_time, max_transfers)
    return (range (route$time))
}

#' Route headway
#'
#' Calculate a vector of headway values -- that is, time intervals between
#' consecutive services -- for all routes between two specified stations.
#'
#' @inheritParams gtfs_route
#' @param quiet If `TRUE`, display a progress bar
#' @return A single vector of integer values containing headways between all
#' services across a single 24-hour period
#' @export
gtfs_route_headway <- function (gtfs, from, to, quiet = FALSE) {

    departure_time <- NULL # suppress no visible binding note

    from_to_are_ids <- FALSE
    start_stns <- from_to_to_stations (from, gtfs, from_to_are_ids) [[1]]
    end_stns <- from_to_to_stations (to, gtfs, from_to_are_ids) [[1]]

    start_time <- 0
    heads <- NULL
    if (!quiet)
        pb <- utils::txtProgressBar (style = 3)
    while (start_time < (24 * 3600)) {
        gtfs$timetable <- gtfs$timetable [departure_time >= start_time, ]
        times <- headway_times (gtfs, start_stns, end_stns, start_time)
        heads <- rbind (heads, unname (times))
        start_time <- times [1] + 1
        if (!quiet)
            utils::setTxtProgressBar (pb, start_time / (24 * 3600))
    }
    if (!quiet)
        close (pb)

    # reduce down to latest departures for any duplicated arrival times
    # and then extract only the corresponding departure times
    heads <- heads [which (diff (heads [, 2]) > 0), 1]

    return (diff (heads))
}
