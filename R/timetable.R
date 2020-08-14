#' gtfs_timetable
#'
#' Convert GTFS data into format able to be used to calculate routes.
#'
#' @param gtfs A set of GTFS data returned from \link{extract_gtfs}.
#' @param day Day of the week on which to calculate route, either as an
#' unambiguous string (so "tu" and "th" for Tuesday and Thursday), or a number
#' between 1 = Sunday and 7 = Saturday. If not given, the current day will be
#' used - unless the following 'date' parameter is give.
#' @param date Some systems do not specify days of the week within their
#' 'calendar' table; rather they provide full timetables for specified calendar
#' dates via a 'calendar_date' table. Providing a date here as a single 8-digit
#' number representing 'yyyymmdd' will filter the data to the specified date.
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
gtfs_timetable <- function (gtfs, day = NULL, date = NULL, route_pattern = NULL,
                            quiet = FALSE)
{
    # IMPORTANT: data.table works entirely by reference, so all operations
    # change original values unless first copied! This function thus returns a
    # copy even when it does nothing else, so always entails some cost.
    gtfs_cp <- data.table::copy (gtfs)

    if (!attr (gtfs_cp, "filtered"))
    {
        if (is.null (date) & is.null (day))
        {
            # nocov start
            if (!check_calendar (gtfs))
                stop ("This appears to be a GTFS feed which uses a ",
                      "'calendar_dates' table instead of 'calendar'.\n",
                      "Please first construct timetable for a particular ",
                      "date using 'gtfs_timetable(gtfs, date = <date>)'\n",
                      "See https://developers.google.com/transit/gtfs/",
                      "reference/#calendar_datestxt for details.",
                      call. = FALSE)
            # nocov end
        }
        if (!is.null (date))
            gtfs_cp <- filter_by_date (gtfs_cp, date) # nocov - not in test data
        else # default day = NULL to current day
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

# Some feeds like Paris use calendar_date table with explicit dates instead of
# just calendar with days of week. This presumes such cases have empty
# 'calendar' tables, and so just checks for that. The alternative specification
# is described at:
# https://developers.google.com/transit/gtfs/reference/#calendar_datestxt
# ... note that it says nothing about what 'calendar' should hold in such cases,
# so this just follows the current patterns appeared to be used in Paris, as per
# issue #20.
check_calendar <- function (gtfs)
{
    days <- c ("monday", "tuesday", "wednesday", "thursday",
               "friday", "saturday", "sunday")
    index <- which (tolower (names (gtfs$calendar)) %in% days)
    #index <- match (days, tolower (names (gtfs$calendar)))
    # note: data.table also has the ..index notation, but that raises "no
    # visible binding" notes which can only be suppressed with `..index = NULL`,
    # but that raises a DT warning; see DT issue #2988.
    #tab <- as.integer (table (gtfs$calendar [, index, with = FALSE]))
    tab <- as.matrix (gtfs$calendar [, index, with = FALSE])
    tab <- as.integer (table (tab))
    length (tab) > 1
}

make_timetable <- function (gtfs)
{
    # no visible binding notes
    stop_id <- trip_id <- stop_ids <- from_stop_id <- to_stop_id <- NULL

    stop_ids <- force_char (unique (gtfs$stops [, stop_id]))
    trip_ids <- force_char (unique (gtfs$trips [, trip_id]))
    gtfs$stop_times [, trip_id := force_char (trip_id)]
    gtfs$stop_times [, stop_id := force_char (stop_id)]
    tt <- rcpp_make_timetable (gtfs$stop_times, stop_ids, trip_ids)
    # tt has [departure/arrival_station, departure/arrival_time,
    # trip_id], where the station and trip values are 1-based indices into
    # the vectors of stop_ids and trip_ids.

    # translate transfer stations into indices
    if ("transfers" %in% names (gtfs))
    {
        # feed may have been filtered, so not all transfer stations may be in
        # feed - these are first removed
        index <- which (gtfs$transfers$from_stop_id %in% stop_ids &
                        gtfs$transfers$to_stop_id %in% stop_ids)
        gtfs$transfers <- gtfs$transfers [index, ]

        index <- match (gtfs$transfers [, from_stop_id], stop_ids)
        gtfs$transfers <- gtfs$transfers [, from_stop_id := index]
        index <- match (gtfs$transfers [, to_stop_id], stop_ids)
        gtfs$transfers <- gtfs$transfers [, to_stop_id := index]
    }

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

# nocov start - not in test data
filter_by_date <- function (gtfs, date = NULL)
{
    if (is.null (date))
        stop ("An explicit date must be specified in order to filter by date")

    # no visible binding notes
    trip_id <- NULL

    index <- which (gtfs$calendar_dates$date == date)
    if (length (index) == 0)
        stop ("date does not match any values in the provided GTFS data")
    exception_type <- gtfs$calendar_dates$exception_type [index]
    # exception_type = 1: Service *added* for specified date
    #                  2: Service *removed* for specified date
    # https://developers.google.com/transit/gtfs/reference#calendar_datestxt
    index <- index [exception_type != 2]
    if (length (index) > 0) {
        service_id <- gtfs$calendar_dates [index, ] [, service_id]
        index <- which (gtfs$trips [, service_id] %in% service_id)
        if (length (index) == 0)
            stop ("The date restricts service_ids to [",
                  paste0 (service_id, collapse = ", "),
                  "] yet there are not trips for those service_ids")
        gtfs$trips <- gtfs$trips [index, ]
        index <- which (gtfs$stop_times [, trip_id] %in% gtfs$trips [, trip_id])
        gtfs$stop_times <- gtfs$stop_times [index, ]
    }

    return (gtfs)
}
# nocov end

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
