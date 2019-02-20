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
#' @inherit gtfs_route return examples
#'
#' @export
gtfs_timetable <- function (gtfs, day = NULL, route_pattern = NULL)
{
    if (!attr (gtfs, "filtered"))
    {
        gtfs <- filter_by_day (gtfs, day)
        if (!is.null (route_pattern))
            gtfs <- filter_by_route (gtfs, route_pattern)
        attr (gtfs, "filtered") <- TRUE
    }

    # no visible binding notes
    from_stop_id <- to_stop_id <- stop_id <- NULL

    # IMPORTANT: data.table works entirely by reference, so all operations
    # change original values unless first copied! This function thus returns a
    # copy even when it does nothing else, so always entails some cost.
    gtfs_cp <- data.table::copy (gtfs)
    if (!"timetable" %in% names (gtfs))
    {
        stop_ids <- unique (gtfs$stops [, stop_id])
        trip_ids <- unique (gtfs$trips [, trip_id])
        tt <- rcpp_make_timetable (gtfs_cp$stop_times, stop_ids, trip_ids)
        # tt has [departure/arrival_station, departure/arrival_time,
        # trip_id], where the station and trip values are 1-based indices into
        # the vectors of stop_ids and trip_ids.

        # translate transfer stations into indices
        index <- match (gtfs_cp$transfers [, from_stop_id], stop_ids)
        gtfs_cp$transfers <- gtfs_cp$transfers [, from_stop_id := index]
        index <- match (gtfs_cp$transfers [, to_stop_id], stop_ids)
        gtfs_cp$transfers <- gtfs_cp$transfers [, to_stop_id := index]

        # order the timetable by departure_time
        tt <- tt [order (tt$departure_time), ]
        # Then convert all output to data.table just for print formatting:
        gtfs_cp$timetable <- data.table::data.table (tt)
        gtfs_cp$stop_ids <- data.table::data.table (stop_ids = stop_ids)
        gtfs_cp$trip_ids <- data.table::data.table (trip_ids = trip_ids)
        # add a couple of extra pre-processing items, with 1 added to numbers here
    }

    return (gtfs_cp)
}

filter_by_day <- function (gtfs, day = NULL)
{
    days <- c ("sunday", "monday", "tuesday", "wednesday", "thursday",
               "friday", "saturday")

    if (is.null (day))
        day <- strftime (Sys.time (), "%A")
    else if (is.numeric (day))
    {
        if (any (day %% 1 != 0))
            stop ("day must be an integer value")
        if (any (day < 0 | day > 7))
            stop ("numeric days must be between 1 (Sun) and 7 (Sat)")
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
