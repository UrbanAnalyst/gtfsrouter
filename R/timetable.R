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
#' Also the 'calendar' is scanned for services that operate on the selected
#' date. Therefore also a merge of feeds that combine 'calendar' and
#' 'calendar_dates' options is covered.
#' @param route_pattern Using only those routes matching given pattern, for
#' example, "^U" for routes starting with "U" (as commonly used for underground
#' or subway routes. To negative the `route_pattern` -- that is, to include all
#' routes except those matching the patter -- prepend the value with "!"; for
#' example "!^U" with include all services except those starting with "U".
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
#' @family extract
#' @export
gtfs_timetable <- function (gtfs, day = NULL, date = NULL, route_pattern = NULL,
                            quiet = FALSE) {
    # IMPORTANT: data.table works entirely by reference, so all operations
    # change original values unless first copied! This function thus returns a
    # copy even when it does nothing else, so always entails some cost.
    gtfs_cp <- data.table::copy (gtfs)

    if (!attr (gtfs_cp, "filtered")) {
        if (is.null (date) && is.null (day)) {
            # nocov start
            if (!check_calendar (gtfs)) {
                stop ("This appears to be a GTFS feed which uses a ",
                    "'calendar_dates' table instead of 'calendar'.\n",
                    "Please first construct timetable for a particular ",
                    "date using 'gtfs_timetable(gtfs, date = <date>)'\n",
                    "See https://developers.google.com/transit/gtfs/",
                    "reference/#calendar_datestxt for details.",
                    call. = FALSE
                )
            }
            # nocov end
        }
        if (!is.null (date)) {
            gtfs_cp <- filter_by_date (gtfs_cp, date) # nocov - not in test data
        } else {
            # default day = NULL to current day
            gtfs_cp <- filter_by_day (gtfs_cp, day, quiet = quiet)
        }
        if (!is.null (route_pattern)) {
            gtfs_cp <- filter_by_route (gtfs_cp, route_pattern)
        }
        attr (gtfs_cp, "filtered") <- TRUE
    }

    if (!"timetable" %in% names (gtfs_cp)) {
        gtfs_cp <- make_timetable (gtfs_cp)
    }

    gtfs_cp$transfers <- rm_transfer_type_3 (gtfs_cp$transfers)

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
check_calendar <- function (gtfs) {
    days <- c (
        "monday",
        "tuesday",
        "wednesday",
        "thursday",
        "friday",
        "saturday",
        "sunday"
    )
    index <- which (tolower (names (gtfs$calendar)) %in% days)
    # index <- match (days, tolower (names (gtfs$calendar)))
    # note: data.table also has the ..index notation, but that raises "no
    # visible binding" notes which can only be suppressed with `..index = NULL`,
    # but that raises a DT warning; see DT issue #2988.
    # tab <- as.integer (table (gtfs$calendar [, index, with = FALSE]))
    tab <- as.matrix (gtfs$calendar [, index, with = FALSE])
    tab <- as.integer (table (tab))
    length (tab) > 1
}

make_timetable <- function (gtfs) {
    # no visible binding notes
    stop_id <- trip_id <- stop_ids <- from_stop_id <- to_stop_id <- NULL

    stop_ids <- force_char (unique (gtfs$stops [, stop_id]))
    trip_ids <- force_char (unique (gtfs$trips [, trip_id]))
    gtfs$stop_times [, trip_id := force_char (trip_id)]
    gtfs$stop_times [, stop_id := force_char (stop_id)]

    # trip_id values may be modified by rcpp_freqs_to_stop_times, by appending
    # "_[0-9]+", so need to grep for actual 'trip_id' values in 'stop_times'
    # table here:
    index <- grep (paste0 (trip_ids, collapse = "|"), gtfs$stop_times$trip_id)
    trip_ids <- unique (gtfs$stop_times$trip_id [index])
    tt <- rcpp_make_timetable (gtfs$stop_times, stop_ids, trip_ids)
    # tt has [departure/arrival_station, departure/arrival_time,
    # trip_id], where the station and trip values are 1-based indices into
    # the vectors of stop_ids and trip_ids.

    # translate transfer stations into indices
    if ("transfers" %in% names (gtfs)) {
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

filter_by_day <- function (gtfs, day = NULL, quiet = FALSE) {

    # no visible binding notes
    trip_id <- NULL

    day <- convert_day (day, quiet)

    # calendar.txt may be omitted if "calendar_dates" contains all days of
    # service.
    if (!"calendar" %in% names (gtfs)) {

        requireNamespace ("lubridate")
        dates <- strptime (gtfs$calendar_dates$date, "%Y%m%d")
        weekdays <- lubridate::wday (dates, label = TRUE)
        weekdays <- tolower (as.character (weekdays))

        index <- which (weekdays == substring (day, 1, 3))
        service_id <- unique (gtfs$calendar_dates$service_id [index])

    } else {

        # Find indices of all services on nominated days
        index <- lapply (day, function (i) {
            which (gtfs$calendar [, get (i)] == 1)
        })
        index <- sort (unique (do.call (c, index)))
        service_id <- gtfs$calendar [index, ] [, service_id]
    }

    index <- which (gtfs$trips [, service_id] %in% service_id)
    gtfs$trips <- gtfs$trips [index, ]
    # trip_id values in stop_times can be modified by rcpp_freq_to_stop_times,
    # which appends "_[0:9]+" values.
    trip_ids <- paste0 (gtfs$trips [, trip_id], collapse = "|")
    index <- grep (trip_ids, gtfs$stop_times [, trip_id])
    gtfs$stop_times <- gtfs$stop_times [index, ]

    return (gtfs)
}

convert_day <- function (day = NULL, quiet = FALSE) {

    # start at monday because strftime "%u" give monday = 1
    days <- c (
        "monday",
        "tuesday",
        "wednesday",
        "thursday",
        "friday",
        "saturday",
        "sunday"
    )

    if (is.null (day)) {
        day <- days [as.integer (strftime (Sys.time (), "%u"))]
        if (!quiet) {
            message ("Day not specified; extracting timetable for ", day)
        }
    } else if (is.numeric (day)) {
        if (any (day %% 1 != 0)) {
            stop ("day must be an integer value")
        }
        if (any (day < 0 | day > 7)) {
            stop ("numeric days must be between 1 (Sun) and 7 (Sat)")
        } # nocov
        day <- days [day]
    }
    day <- tolower (day)

    day <- days [pmatch (day, days)]
    if (any (is.na (day))) {
        stop ("day must be a day of the week")
    }

    return (day)
}

# nocov start - not in test data
# date is passed from timetable, so must be in form YYYYMMDD
filter_by_date <- function (gtfs, date = NULL) {
    if (is.null (date)) {
        stop ("An explicit date must be specified in order to filter by date")
    }

    # no visible binding notes
    trip_id <- NULL
    start_date <- NULL
    end_date <- NULL
    index <- which (gtfs$calendar_dates$date == date)

    # get all service_ids in calendar.txt that are valid for the given date
    date_int <- date
    date <- strptime (date, format = "%Y%m%d") # YYYYMMDD date as POSIX
    days <- c (
        "monday", "tuesday", "wednesday", "thursday",
        "friday", "saturday", "sunday"
    )
    day <- days [as.integer (strftime (date, format = "%u"))]
    if (is.na (day)) {
        stop ("Date must be provided in the format YYYYMMDD")
    }

    calendars_in_range <- gtfs$calendar [(start_date <= date_int) &
        (end_date >= date_int), ]
    if (nrow (calendars_in_range) == 0) {
        stop ("Calendar contains no matching dates")
    }

    index_day <- lapply (day, function (i) {
        which (calendars_in_range [, get (i)] == 1)
    })
    index_day <- sort (unique (do.call (c, index_day)))

    if (length (index) == 0 && length (index_day) == 0) {
        stop ("date does not match any values in the provided GTFS data")
    }
    exception_type <- gtfs$calendar_dates$exception_type [index]
    # exception_type = 1: Service *added* for specified date
    #                  2: Service *removed* for specified date
    # https://developers.google.com/transit/gtfs/reference#calendar_datestxt
    index <- index [exception_type != 2]
    service_id <- c ()
    if (length (index) > 0) {
        service_id <- gtfs$calendar_dates [index, ] [, service_id]
    }
    # Find indices of all services on nominated days that are within start and
    # end date of calendar
    if (length (index_day) > 0) {
        service_id <- c (
            service_id,
            calendars_in_range [index_day, ] [, service_id]
        )
    }
    if (length (service_id > 0)) {
        index <- which (gtfs$trips [, service_id] %in% service_id)
        if (length (index) == 0) {
            stop (
                "The date restricts service_ids to [",
                paste0 (service_id, collapse = ", "),
                "] yet there are not trips for those service_ids"
            )
        }
        gtfs$trips <- gtfs$trips [index, ]
        index <- which (gtfs$stop_times [, trip_id] %in% gtfs$trips [, trip_id])
        gtfs$stop_times <- gtfs$stop_times [index, ]
    }

    return (gtfs)
}
# nocov end

filter_by_route <- function (gtfs, route_pattern = NULL) {
    # no visible binding notes:
    route_short_name <- route_id <- trip_id <- stop_id <-
        from_stop_id <- to_stop_id <- NULL

    invert <- FALSE
    if (substring (route_pattern, 1, 1) == "!") {
        if (nchar (route_pattern) == 1) {
            stop ("Oh come on, route_pattern = '!' is silly")
        }
        invert <- TRUE
        route_pattern <- substring (route_pattern, 2, nchar (route_pattern))
    }
    index <- grep (route_pattern,
        gtfs$routes [, route_short_name],
        invert = invert
    )
    if (length (index) == 0) {
        stop ("There are no routes matching that pattern")
    }

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

# transfers$transfer_type == 3 is used to flag prohibited transfers, which must
# be excluded. See #76.
rm_transfer_type_3 <- function (transfers) {

    if (!any (transfers$transfer_type == 3)) {
        return (transfers)
    }

    # check whether any pairs of stations have different transfer_type values,
    # and error if so. The following is a non-dplyr version of
    # group_by (from_stop_id, to_stop_id) %>% summarise (length (from_stop_id))
    index <- which (duplicated (cbind (
        transfers$from_stop_id,
        transfers$to_stop_id
    )))
    if (length (index) > 0) {
        tr <- transfers [index, ]
        tr$temp <- paste0 (tr$from_stop_id, tr$to_stop_id)
        tr <- split (tr, f = as.factor (tr$temp))
        n_ttypes <- vapply (tr, function (i) {
            length (table (i$transfer_type))
        },
        integer (1),
        USE.NAMES = FALSE
        )
        if (any (n_ttypes > 1)) {
            tr_out <- do.call (rbind, tr [which (n_ttypes > 1)])
            tr_out$temp <- NULL
            message (
                "transfer table has different transfer types between ",
                "same pairs of stops: "
            )
            print (tr_out)
            stop ("Please rectify this problem with this feed.")
        }
    }

    transfer_type <- NULL # suppress no visible binding message

    return (transfers [transfer_type < 3])
}
