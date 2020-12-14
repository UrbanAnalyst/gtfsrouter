#' gtfs_traveltimes
#'
#' Travel times from a nominated station departing at a nominated time to every
#' other reachable station in a system.
#'
#' @param cutoff After a period of traversing a timetable, very few new stations
#' will be able to be reached. The period between reaching new stations
#' generally remains very constant up until that point, after which it increases
#' notably. Cutoff stops the search for new stations once the mean plus standard
#' deviation in time between successive new stations being reached exceeds the
#' given multiple. This value should generally not be changed, but may be set to
#' '0' to search an entire timetable, although see Note.
#'
#' @note Searching for all connections over an entire timetable may return
#' anomalously high travel times for stations or platforms thereof which are only
#' very occasionally serviced. Results generated with `cutoff = 0` may need to
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
                              cutoff = 10,
                              quiet = FALSE) {

    if (!all (is.numeric (cutoff)) | all (cutoff < 0) | length (cutoff) > 1)
        stop ("cutoff must be a single number >= 0")
    if (cutoff == 0)
        cutoff <- .Machine$integer.max

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
                              cutoff)

    # C++ matrix is 1-indexed, so discard first row (= 0)
    stns <- stns [-1, ]
    stns <- data.frame (duration = stns [, 1],
                        ntransfers = stns [, 2],
                        stop_id = gtfs$stops$stop_id,
                        stop_name = gtfs$stops$stop_name,
                        stop_lon = gtfs$stops$stop_lon,
                        stop_lat = gtfs$stops$stop_lat,
                        stringsAsFactors = FALSE)
    stns <- stns [which (stns$duration < .Machine$integer.max), ]
    stns$duration <- hms::hms (stns$duration)

    return (stns)
}
