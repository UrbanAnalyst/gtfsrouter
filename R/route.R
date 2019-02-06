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

    # IMPORTANT: data.table works entirely by reference, so all operations
    # change original values unless first copied! This function thus returns a
    # copy even when it does nothing else, so always entails some cost.
    gtfs_cp <- data.table::copy (gtfs)
    if (!"timetable" %in% names (gtfs))
    {
        tt <- rcpp_make_timetable (gtfs_cp$stop_times)
        # tt$timetable has [departure/arrival_station, departure/arrival_time,
        # trip_id], where the station and trip values are 0-based indices into the
        # vectors of tt$stop_ids and tt$trips.

        # translate transfer stations into indices, converting back to 0-based to
        # match the indices of tt$timetable
        index <- match (gtfs_cp$transfers [, from_stop_id], tt$stations) - 1
        gtfs_cp$transfers <- gtfs_cp$transfers [, from_stop_id := index]
        index <- match (gtfs_cp$transfers [, to_stop_id], tt$stations) - 1
        gtfs_cp$transfers <- gtfs_cp$transfers [, to_stop_id := index]

        # Then convert all output to data.table just for print formatting:
        gtfs_cp$timetable <- data.table::data.table (tt$timetable)
        gtfs_cp$stations <- data.table::data.table (stations = tt$stations)
        gtfs_cp$trips <- data.table::data.table (trips = tt$trips)
        # add a couple of extra pre-processing items, with 1 added to numbers here
        # because indices are 0-based:
        gtfs_cp$stop_ids <- data.table::data.table (
                                stop_id = unique (gtfs_cp$stop_times [, stop_id]))
        gtfs_cp$n_stations <- max (unique (c (gtfs_cp$timetable$departure_station,
                                           gtfs_cp$timetable$arrival_station))) + 1
        gtfs_cp$n_trips <- max (gtfs_cp$timetable$trip_id) + 1

        # And order the timetable by departure_time
        gtfs_cp$timetable <- gtfs_cp$timetable [order (gtfs_cp$timetable$departure_time), ]
    }

    return (gtfs_cp)
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
#' @return square matrix of distances between nodes
#'
#' @export 
gtfs_route <- function (gtfs, from, to, start_time)
{
    if (!"timetable" %in% names (gtfs))
        gtfs <- gtfs_timetable (gtfs)

    # no visible binding note:
    departure_time <- stop_name <- stop_id <- NULL

    start_time <- convert_time (start_time)
    gtfs$timetable <- gtfs$timetable [departure_time >= start_time, ]
    if (nrow (gtfs$timetable) == 0)
        stop ("There are no scheduled services after that time.")

    stations <- NULL # no visible binding note
    start_stns <- match (station_name_to_id (from, gtfs),
                         gtfs$stations [, stations]) - 1
    end_stns <- match (station_name_to_id (to, gtfs),
                       gtfs$stations [, stations]) - 1

    route <- rcpp_csa (gtfs$timetable, gtfs$transfers, gtfs$n_stations,
                     gtfs$n_trips, start_stns, end_stns, start_time)
    route$station_name <- sapply (route$station, function (i)
        gtfs$stops [stop_id == gtfs$stations [i] [, stations], ] [, stop_name])

    # map_one_trip maps the integer-valued stations back on to actual station
    # names. This is done seperately for each distinct trip so trip identifiers
    # can also be easily added
    do.call (rbind, lapply (rev (seq (unique (route$trip))), function (i)
                            map_one_trip (gtfs, route, i)))
}

convert_time <- function (my_time)
{
    if (methods::is (my_time, "difftime") || methods::is (my_time, "Period"))
    {
        my_time <- rcpp_convert_time (paste0 (my_time))
    } else if (is.numeric (my_time))
    {
        if (length (my_time) == 1)
        {
            # do nothing; presume to be seconds, not hours
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

get_route_name <- function (gtfs, trip_id = NULL)
{
    # no visible binding notes:
    route_id <- route_short_name <- NULL

    index <- match (trip_id, gtfs$trip_table [, trip_id])
    route <- gtfs$trip_table [index, ] [, route_id]
    gtfs$routes [route_id == route, ] [, route_short_name]
}

# Re-map the result of gtfs_route onto trip details (names of routes & stations,
# plus departure times). This is called seperately for each distinct route in
# the result.
map_one_trip <- function (gtfs, route, trip_num = 1)
{
    # no visible binding notes:
    trip_id <- stop_id <- stop_name <- departure_time <- arrival_time <- NULL

    trips <- gtfs$trips [unique (route$trip)]
    trip <- trips [trip_num, trips]

    route_name <- get_route_name (gtfs, trip_id = trip)

    trip_stops <- gtfs$stop_times [trip_id == trip, ]
    trip_stop_num <- match (trip_stops [, stop_id], gtfs$stop_ids [, stop_id])
    trip_stop_num <- trip_stop_num [which (trip_stop_num %in% route$station)]
    trip_stop_id <- gtfs$stop_ids [trip_stop_num, stop_id]
    trip_stop_names <- gtfs$stops [match (trip_stop_id, gtfs$stops [, stop_id]),
                                   stop_name]
    trip_stops <- trip_stops [which (trip_stops [, stop_id %in% trip_stop_id]), ]
    trip_stop_departure <- format_time (trip_stops [, departure_time])
    trip_stop_arrival <- format_time (trip_stops [, arrival_time])
    data.frame (route = route_name,
                stop = trip_stop_names,
                departure_time = trip_stop_departure,
                arrival_time = trip_stop_arrival,
                stringsAsFactors = FALSE)
}

# convert timevec in seconds into hh:mm:ss - functionality of hms::hms without
# dependency
format_time <- function (timevec)
{
    hh <- floor (timevec / 3600)
    timevec <- timevec - hh * 3600
    mm <- floor (timevec / 60)
    ss <- round (timevec - mm * 60)

    paste0 (zero_pad (hh), ":", zero_pad (mm), ":", zero_pad (ss))
}

zero_pad <- function (x)
{
    x <- paste0 (x)
    x [nchar (x) < 2] <- paste0 (0, x [nchar (x) < 2])
    return (x)
}
