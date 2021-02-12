#' gtfs_traveltimes
#'
#' Travel times from a nominated station departing at a nominated time to every
#' other reachable station in a system.
#'
#' @param prop_stops Stop scanning after this proportion of all potentially
#' reachable stops has been reached. Some stops may only be reached very
#' infrequently (like once per day), and scanning a timetable until all stops
#' have been reached may (1) yield anomalously long travel times for very
#' infrequently serviced stops; and (2) take a long time to calculate. The
#' `prop_stops` parameter should accordingly generally be less than 1. For large
#' systems with many stops (tens of thousands), values of 0.5 are often
#' sufficient to reach most of the system.
#'
#' @note Searching for all connections over an entire timetable may return
#' anomalously high travel times for stops which are only very occasionally
#' serviced. Results generated with values of `prop_stops` close to 1 may need to
#' be manually cleaned prior to analysis.
#'
#' @inheritParams gtfs_isochrone
#' @export
gtfs_traveltimes <- function (gtfs,
                              from,
                              start_time,
                              day = NULL,
                              from_is_id = FALSE,
                              grep_fixed = TRUE,
                              route_pattern = NULL,
                              minimise_transfers = FALSE,
                              prop_stops = 0.5,
                              quiet = FALSE) {

    if (!all (is.numeric (prop_stops)) | all (prop_stops <= 0) |
        all (prop_stops > 1) | length (prop_stops) > 1)
        stop ("prop_stops must be a single number between 0 and 1")

    if (!"timetable" %in% names (gtfs))
        gtfs <- gtfs_timetable (gtfs, day, route_pattern, quiet = quiet)

    gtfs_cp <- data.table::copy (gtfs)

    # no visible binding note:
    departure_time <- NULL

    start_time <- convert_time (start_time)
    gtfs_cp$timetable <- gtfs_cp$timetable [departure_time >= start_time, ]
    if (nrow (gtfs_cp$timetable) == 0)
        stop ("There are no scheduled services after that time.")

    stations <- NULL # no visible binding note # nolint
    start_stns <- station_name_to_ids (from, gtfs_cp, from_is_id, grep_fixed)

    stns <- rcpp_traveltimes (gtfs_cp$timetable,
                              gtfs_cp$transfers,
                              nrow (gtfs_cp$stop_ids),
                              start_stns,
                              start_time, 
                              minimise_transfers,
                              prop_stops)

    # C++ matrix is 1-indexed, so discard first row (= 0)
    stns <- stns [-1, ]
    stns <- data.frame (start_time = stns [, 1],
                        duration = stns [, 2],
                        ntransfers = stns [, 3],
                        stop_id = gtfs$stops$stop_id,
                        stop_name = gtfs$stops$stop_name,
                        stop_lon = gtfs$stops$stop_lon,
                        stop_lat = gtfs$stops$stop_lat,
                        stringsAsFactors = FALSE)
    stns <- stns [which (stns$duration < .Machine$integer.max), ]
    stns$start_time <- hms::hms (stns$start_time)
    stns$duration <- hms::hms (stns$duration)

    return (stns)
}
