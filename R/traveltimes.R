#' gtfs_traveltimes
#'
#' Travel times from a nominated station departing at a nominated time to every
#' other reachable station in a system.
#'
#' @inheritParams gtfs_isochrone
#' @export
gtfs_traveltimes <- function (gtfs, from, start_time, day = NULL,
                              from_is_id = FALSE, route_pattern = NULL,
                              minimise_transfers = FALSE, quiet = FALSE) {

    if (!"timetable" %in% names (gtfs))
        gtfs <- gtfs_timetable (gtfs, day, route_pattern, quiet = quiet)

    gtfs_cp <- data.table::copy (gtfs)

    # no visible binding note:
    departure_time <- NULL

    start_time <- convert_time (start_time)
    end_time <- convert_time (end_time)
    gtfs_cp$timetable <- gtfs_cp$timetable [departure_time >= start_time, ]
    if (nrow (gtfs_cp$timetable) == 0)
        stop ("There are no scheduled services after that time.")

    stations <- NULL # no visible binding note # nolint
    start_stns <- station_name_to_ids (from, gtfs_cp, from_is_id)

    stns <- rcpp_traveltimes (gtfs_cp$timetable, gtfs_cp$transfers,
                              nrow (gtfs_cp$stop_ids),
                              start_stns, start_time, 
                              minimise_transfers)

    # C++ matrix is 1-indexed, so discard first row (= 0)
    stns <- stns [-1, ]
    stns <- data.frame (duration = stns [, 1],
                        ntransfers = stns [, 2],
                        id = gtfs$stops$stop_id,
                        stop_name = gtfs$stops$stop_name,
                        stop_lon = gtfs$stops$stop_lon,
                        stop_lat = gtfs$stops$stop_lat,
                        stringsAsFactors = FALSE)
    stns <- stns [which (stns$duration < .Machine$integer.max), ]
    stns$duration <- hms::hms (stns$duration)

    return (stns)
}
