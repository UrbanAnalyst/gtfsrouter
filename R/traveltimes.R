#' gtfs_traveltimes
#'
#' Travel times from a nominated station departing at a nominated time to every
#' other reachable station in a system.
#'
#' @param gtfs A set of GTFS data returned from \link{extract_gtfs} or, for more
#' efficient queries, pre-processed with \link{gtfs_timetable}.
#' @param from Name, ID, or approximate (lon, lat) coordinates of start station
#' (as `stop_name` or `stop_id` entry in the `stops` table, or a vector of two
#' numeric values).
#' @param start_time_limits A vector of two integer values denoting the earliest
#' and latest departure times in seconds for the traveltime values.
#' @param from_is_id Set to `TRUE` to enable `from` parameter to specify entry
#' in `stop_id` rather than `stop_name` column of the `stops` table (same as
#' `from_to_are_ids` parameter of \link{gtfs_route}).
#' @param minimise_transfers If `TRUE`, isochrones are calculated with
#' minimal-transfer connections to each end point, even if those connections are
#' slower than alternative connections with transfers.
#' @param max_traveltime The maximal traveltime to search for, specified in
#' seconds (with default of 1 hour). See note for details.
#' @inheritParams gtfs_route
#'
#' @note Higher values of `max_traveltime` will return traveltimes for greater
#' numbers of stations, but may lead to considerably longer calculation times.
#' For repeated usage, it is recommended to first establish a value sufficient
#' to reach all or most stations desired for a particular query, rather than set
#' `max_traveltime` to an arbitrarily high value.
#'
#' @examples
#' # Examples must be run on single thread only:
#' data.table::setDTthreads (1)
#'
#' berlin_gtfs_to_zip ()
#' f <- file.path (tempdir (), "vbb.zip")
#' g <- extract_gtfs (f)
#' g <- gtfs_timetable (g)
#' from <- "Alexanderplatz"
#' start_times <- 12 * 3600 + c (0, 60) * 60 # 8:00-9:00
#' res <- gtfs_traveltimes (g, from, start_times)
#' @family main
#' @export
gtfs_traveltimes <- function (gtfs,
                              from,
                              start_time_limits,
                              day = NULL,
                              from_is_id = FALSE,
                              grep_fixed = TRUE,
                              route_pattern = NULL,
                              minimise_transfers = FALSE,
                              max_traveltime = 60 * 60,
                              quiet = FALSE) {

    if (!all (is.numeric (max_traveltime)) ||
        all (max_traveltime <= 0) ||
        length (max_traveltime) > 1) {
        stop ("max_traveltime must be a single number greater than 0",
            call. = FALSE
        )
    }

    if (!"transfers" %in% names (gtfs)) {
        stop ("gtfs must have a transfers table; ",
            "please use 'gtfs_transfer_table()' to construct one",
            call. = FALSE
        )
    }

    if (!"timetable" %in% names (gtfs)) {
        gtfs <- gtfs_timetable (gtfs, day, route_pattern, quiet = quiet)
    }

    gtfs_cp <- data.table::copy (gtfs)

    # no visible binding note:
    departure_time <- NULL

    start_time_limits <- convert_start_time_limits (start_time_limits)

    gtfs_cp$timetable <- gtfs_cp$timetable [departure_time >=
        start_time_limits [1], ]
    if (nrow (gtfs_cp$timetable) == 0) {
        stop ("There are no scheduled services after that time.")
    }

    stations <- NULL # no visible binding note # nolint
    start_stns <- station_name_to_ids (from, gtfs_cp, from_is_id, grep_fixed)

    stns <- rcpp_traveltimes (
        gtfs_cp$timetable,
        gtfs_cp$transfers,
        nrow (gtfs_cp$stop_ids),
        start_stns,
        start_time_limits [1],
        start_time_limits [2],
        minimise_transfers,
        max_traveltime
    )

    # C++ matrix is 1-indexed, so discard first row (= 0)
    stns <- stns [-1, ]
    stns <- data.frame (
        start_time = stns [, 1],
        duration = stns [, 2],
        ntransfers = stns [, 3],
        stop_id = gtfs$stops$stop_id,
        stop_name = gtfs$stops$stop_name,
        stop_lon = gtfs$stops$stop_lon,
        stop_lat = gtfs$stops$stop_lat,
        stringsAsFactors = FALSE
    )
    stns <- stns [which (stns$duration < .Machine$integer.max), ]
    if (nrow (stns) > 0) {
        stns$start_time <- format_time (stns$start_time)
        stns$duration <- format_time (stns$duration)
    }

    rownames (stns) <- NULL

    return (stns)
}

convert_start_time_limits <- function (start_time_limits) {

    if (length (start_time_limits) != 2) {
        stop ("start_time_limits must have exactly two entries")
    }
    if (!is.numeric (start_time_limits)) {
        stop ("start_time_limits must be a vector of 2 integers")
    }
    if (start_time_limits [1] > start_time_limits [2]) {
        stop ("start_time_limits must be (min, max) values")
    }

    vapply (start_time_limits, convert_time, integer (1))
}
