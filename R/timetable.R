#' gtfs_timetable
#'
#' Convert GTFS data into format able to be used to calculate routes.
#'
#' @param gtfs A set of GTFS data returned from \link{extract_gtfs}.
#' @param day Day of the week on which to calculate route, either as an
#' unambiguous string (so "tu" and "th" for Tuesday and Thursday), or a number
#' between 1 = Sunday and 7 = Saturday. If not given, the current day will be
#' used.
#' @param route_pattern Using only those routes matching given pattern, for
#' example, "^U" for routes starting with "U" (as commonly used for underground
#' or subway routes.
#'
#' @return The input data with an addition items, `timetable`, `stations`, and
#' `trips`, containing data formatted for more efficient use with
#' \link{gtfs_route} (see Note).
#'
#' @note This function is merely provided to speed up calls to the primary
#' function, \link{gtfs_route}. If the input data to that function do not
#' include a formatted `timetable`, it will be calculated anyway, but queries in
#' that case will generally take longer.
#'
#' @inheritParams gtfs_route
#' @inherit gtfs_route return examples
#'
#' @export
gtfs_timetable <- function (gtfs, day = NULL, route_pattern = NULL,
                            quiet = FALSE)
{
    # IMPORTANT: data.table works entirely by reference, so all operations
    # change original values unless first copied! This function thus returns a
    # copy even when it does nothing else, so always entails some cost.
    gtfs_cp <- data.table::copy (gtfs)

    if (!attr (gtfs_cp, "filtered"))
    {
        gtfs_cp <- filter_by_day (gtfs_cp, day, quiet = quiet)
        if (!is.null (route_pattern))
            gtfs_cp <- filter_by_route (gtfs_cp, route_pattern)
        attr (gtfs_cp, "filtered") <- TRUE
    }

    if (!"timetable" %in% names (gtfs_cp))
    {
        gtfs_cp <- make_timetable (gtfs_cp)
    }

    return (gtfs_cp)
}

make_timetable <- function (gtfs)
{
    # no visible binding notes
    stop_id <- trip_id <- stop_ids <- from_stop_id <- to_stop_id <- NULL

    stop_ids <- unique (gtfs$stops [, stop_id])
    trip_ids <- unique (gtfs$trips [, trip_id])
    tt <- rcpp_make_timetable (gtfs$stop_times, stop_ids, trip_ids)
    # tt has [departure/arrival_station, departure/arrival_time,
    # trip_id], where the station and trip values are 1-based indices into
    # the vectors of stop_ids and trip_ids.

    # translate transfer stations into indices
    index <- match (gtfs$transfers [, from_stop_id], stop_ids)
    gtfs$transfers <- gtfs$transfers [, from_stop_id := index]
    index <- match (gtfs$transfers [, to_stop_id], stop_ids)
    gtfs$transfers <- gtfs$transfers [, to_stop_id := index]

    # order the timetable by departure_time
    tt <- tt [order (tt$departure_time), ]
    # Then convert all output to data.table just for print formatting:
    gtfs$timetable <- data.table::data.table (tt)
    gtfs$stop_ids <- data.table::data.table (stop_ids = stop_ids)
    gtfs$trip_ids <- data.table::data.table (trip_ids = trip_ids)

    return (gtfs)
}

filter_by_day <- function (gtfs, day = NULL, quiet = FALSE)
{
    days <- c ("sunday", "monday", "tuesday", "wednesday", "thursday",
               "friday", "saturday")

    if (is.null (day))
    {
        day <- strftime (Sys.time (), "%A")
        if (!quiet)
            message ("Day not specified; extracting timetable for ", day)
    } else if (is.numeric (day))
    {
        if (any (day %% 1 != 0))
            stop ("day must be an integer value")
        if (any (day < 0 | day > 7))
            stop ("numeric days must be between 1 (Sun) and 7 (Sat)") # nocov
        day <- days [day]
    }
    day <- tolower (day)

    day <- days [pmatch (day, days)]
    if (any (is.na (day)))
        stop ("day must be a day of the week")

    # no visible binding notes
    trip_id <- NULL

    # Find indices of all services on nominated days
    index <- lapply (day, function (i)
                     which (gtfs$calendar [, get (i)] == 1))
    index <- sort (unique (do.call (c, index)))
    service_id <- gtfs$calendar [index, ] [, service_id]
    index <- which (gtfs$trips [, service_id] %in% service_id)
    gtfs$trips <- gtfs$trips [index, ]
    index <- which (gtfs$stop_times [, trip_id] %in% gtfs$trips [, trip_id])
    gtfs$stop_times <- gtfs$stop_times [index, ]

    return (gtfs)
}

filter_by_route <- function (gtfs, route_pattern = NULL)
{
    # no visible binding notes:
    route_short_name <- route_id <- trip_id <- stop_id <-
        from_stop_id <- to_stop_id <- NULL

    index <- grep (route_pattern, gtfs$routes [, route_short_name])
    gtfs$routes <- gtfs$routes [index, ]

    gtfs$trips <- gtfs$trips [which (gtfs$trips [, route_id] %in%
                                     gtfs$routes [, route_id]), ]

    gtfs$stop_times <- gtfs$stop_times [which (gtfs$stop_times [, trip_id] %in%
                                               gtfs$trips [, trip_id]), ]

    gtfs$stops <- gtfs$stops [which (gtfs$stops [, stop_id] %in% 
                                     gtfs$stop_times [, stop_id]), ]

    index <- which ((gtfs$transfers [, from_stop_id] %in% 
                     gtfs$stops [, stop_id]) &
                    (gtfs$transfers [, to_stop_id] %in% 
                     gtfs$stops [, stop_id]))
    gtfs$transfers <- gtfs$transfers [index, ]

    return (gtfs)
}

#' gtfs_median_timetable
#'
#' Convert GTFS data into format able to be used to calculate routes.
#'
#' @param gtfs A set of GTFS data with timetable returned from
#' \link{extract_gtfs} and \link{gtfs_timetable}.
#'
#' @return A `data.frame` containing the median timetable.
#'
#' @inherit gtfs_median_isochrones return examples
#'
#' @export
gtfs_median_timetable <- function (gtfs)
{
    if (!methods::is (gtfs, "gtfs"))
        stop ("Object must be of class gtfs")
    if (!"timetable" %in% names (gtfs))
        stop ("Object must have a timetable added by gtfs_timetable")

    cache_prefix <- "MED_TT_"
    tt <- load_cached_file (gtfs, cache_prefix)
    if (is.null (tt))
    {
        tt <- rcpp_median_timetable (gtfs$timetable)
        cache_file (gtfs, tt, cache_prefix)
    }
    return (tt)
}

#' gtfs_median_graph
#'
#' Construct graph from median timetable including all transfers
#'
#' @param timetable Median timetable returned from \link{gtfs_median_timetable}.
#' @param gtfs GTFS data set with timetable obtained from \link{extract_gtfs}
#' and \link{gtfs_timetable}.
#'
#' @return A `data.frame` containing 3 columns: the departure and arrival
#' stations as integer indices into `gtfs$stop_ids`, and a column of edge
#' lengths measured as median durations between each departure and arrival
#' station.
#'
#' @inherit gtfs_median_isochrones return examples
#'
#' @export
gtfs_median_graph <- function (timetable, gtfs)
{
    nverts <- max (c (timetable$departure_station,
                      timetable$arrival_station)) + 1
    x <- rcpp_median_graph (timetable, gtfs$transfers)
    x <- rbind (data.frame (departure_station = timetable$departure_station,
                            arrival_station = timetable$arrival_station,
                            duration = timetable$duration_median),
                x)
    x$distance <- station_distances (x, gtfs)
    return (x)
}
