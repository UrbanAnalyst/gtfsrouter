#' gtfs_timetable
#'
#' Convert GTFS data into format able to be used to calculate routes.
#'
#' @param gtfs A set of GTFS data returned from \link{extract_gtfs}.
#' @return The input data with an addition items, `timetable`, `stations`, and
#' `trips`, containing data formatted for more efficient use with
#' \link{gtfs_route} (see Note).
#'
#' @note This function is merely provided to speed up calls to the primary
#' function, \link{gtfs_route}. If the input data to that function do not
#' include a formatted `timetable`, it will be calculated anyway, but queries in
#' that case will generally take longer.
#'
#' @export
gtfs_timetable <- function (gtfs)
{
    # no visible binding notes
    from_stop_id <- to_stop_id <- stop_id <- NULL

    tt <- rcpp_make_timetable (gtfs$stop_times)
    # tt$timetable has [departure/arrival_station, departure/arrival_time,
    # trip_id], where the station and trip values are 0-based indices into the
    # vectors of tt$stop_ids and tt$trips.

    # translate transfer stations into indices, converting back to 0-based to
    # match the indices of tt$timetable
    index <- match (gtfs$transfers [, from_stop_id], tt$stations) - 1
    gtfs$transfers <- gtfs$transfers [, from_stop_id := index]
    index <- match (gtfs$transfers [, to_stop_id], tt$stations) - 1
    gtfs$transfers <- gtfs$transfers [, to_stop_id := index]

    # Then convert all output to data.table just for print formatting:
    gtfs$timetable <- data.table::data.table (tt$timetable)
    gtfs$stations <- data.table::data.table (stations = tt$stations)
    gtfs$trips <- data.table::data.table (trips = tt$trips)
    # add a couple of extra pre-processing items, with 1 added to numbers here
    # because indices are 0-based:
    gtfs$stop_ids <- data.table::data.table (stop_id =
                            unique (gtfs$stop_times [, stop_id]))
    gtfs$n_stations <- max (unique (c (gtfs$timetable$departure_station,
                                       gtfs$timetable$arrival_station))) + 1
    gtfs$n_trips <- max (gtfs$timetable$trip_id) + 1

    # And order the timetable by departure_time
    gtfs$timetable <- gtfs$timetable [order (gtfs$timetable$departure_time), ]

    return (gtfs)
}

#' gtfs_route
#'
#' Calculate single route between a start and end station departing at or after
#' a specified time.
#'
#' @param gtfs A set of GTFS data returned from \link{extract_gtfs} or, for more
#' efficient queries, pre-processed with \link{gtfs_timetable}.
#' @param from Name of start station
#' @param to Name of end station
#' @param start_time Desired departure time at `from` station, either in seconds
#' after midnight, a vector of two or three integers (hours, minutes) or (hours,
#' minutes, seconds), an object of class \link{difftime}, \pkg{hms}, or
#' \pkg{lubridate}.
#' @param quiet If `FALSE`, dump progress notifications to screen.
#' @return square matrix of distances between nodes
#'
#' @export 
gtfs_route <- function (gtfs, from, to, start_time, quiet = TRUE)
{
    if (!"timetable" %in% names (gtfs))
    {
        if (!quiet)
            message ("Converting GTFS data to timetable form; ",
                     "this step can also be pre-processed with ",
                     "`gtfs_timetable()`")

        gtfs <- gtfs_timetable (gtfs)
    }

    start_time <- convert_time (start_time)
    gtfs$timetable <- gtfs$timetable [departure_time >= start_time, ]

    stations <- NULL # no visible binding note
    start_stns <- match (station_name_to_id (from, gtfs),
                         gtfs$stations [, stations]) - 1
    end_stns <- match (station_name_to_id (to, gtfs),
                       gtfs$stations [, stations]) - 1

    rcpp_csa (gtfs$timetable, gtfs$transfers, gtfs$n_stations, gtfs$n_trips,
              start_stns, end_stns, start_time)
}

convert_time <- function (my_time, quiet = TRUE)
{
    if (methods::is (my_time, "difftime") ||
        methods::is (my_time, "Period"))
    {
        my_time <- rcpp_convert_time (paste0 (my_time))
    } else if (is.numeric (my_time))
    {
        if (length (my_time) == 1)
        {
            if (!quiet)
                message ("Mumeric time of length 1 are presumed to be seconds")
        } else if (length (my_time) == 2)
            my_time <- 3600 * my_time [1] + 60 * my_time [2]
        else if (length (my_time) == 3)
            my_time <- 3600 * my_time [1] + 60 * my_time [2] + my_time [3]
        else
            stop ("Don't know how to parse time vectors of length ",
                  length (my_time))
    } else
        stop ("Time is of unknown class")

    return (my_time)
}

station_name_to_id <- function (stn_name, gtfs)
{
    # no visible binding notes:
    stop_name <- stop_id <- NULL

    ret <- gtfs$stops [grep (stn_name, gtfs$stops [, stop_name]), ] [, stop_id]
    ret [which (ret %in% gtfs$stop_id [, stop_id])]
}
