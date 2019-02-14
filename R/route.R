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
#' @param day Day of the week on which to calculate route, either as an
#' unambiguous string (so "tu" and "th" for Tuesday and Thursday), or a number
#' between 1 = Sunday and 7 = Saturday. If not given, the current day will be
#' used. (Not used if `gtfs` has already been prepared with
#' \link{gtfs_timetable}.)
#' @param route_pattern Using only those routes matching given pattern, for
#' example, "^U" for routes starting with "U" (as commonly used for underground
#' or subway routes. (Parameter not used at all if `gtfs` has already been
#' prepared with \link{gtfs_timetable}.)
#'
#' @return square matrix of distances between nodes
#'
#' @export 
gtfs_route <- function (gtfs, from, to, start_time, day = NULL,
                        route_pattern = NULL)
{
    if (!"timetable" %in% names (gtfs))
        gtfs <- gtfs_timetable (gtfs, day, route_pattern)

    # no visible binding note:
    departure_time <- stop_name <- stop_id <- NULL

    start_time <- convert_time (start_time)
    gtfs$timetable <- gtfs$timetable [departure_time >= start_time, ]
    if (nrow (gtfs$timetable) == 0)
        stop ("There are no scheduled services after that time.")

    stations <- NULL # no visible binding note
    start_stns <- station_name_to_ids (from, gtfs)
    end_stns <- station_name_to_ids (to, gtfs)

    route <- rcpp_csa (gtfs$timetable, gtfs$transfers, gtfs$n_stations,
                     gtfs$n_trips, start_stns, end_stns, start_time)
    if (nrow (route) == 0)
        stop ("No route found between the nominated stations")

    route$station_name <- sapply (route$station, function (i)
        gtfs$stops [stop_id == gtfs$stations [i] [, stations], ] [, stop_name])

    # map_one_trip maps the integer-valued stations back on to actual station
    # names. This is done seperately for each distinct trip so trip identifiers
    # can also be easily added
    do.call (rbind, lapply (rev (seq (unique (route$trip))), function (i)
                            map_one_trip (gtfs, route, i)))
}

# names generally match to multiple IDs, each of which is returned here
station_name_to_ids <- function (stn_name, gtfs)
{
    # no visible binding notes:
    stop_name <- stop_id <- stations <- NULL

    ret <- gtfs$stops [grep (stn_name, gtfs$stops [, stop_name]), ] [, stop_id]
    ret <- ret [which (ret %in% gtfs$stop_id [, stop_id])]
    ret <- match (ret, gtfs$stations [, stations]) - 1
    if (length (ret) == 0)
        stop (stn_name, " does not match any stations")

    return (ret)
}

get_route_name <- function (gtfs, trip_id = NULL)
{
    # no visible binding notes:
    route_id <- route_short_name <- NULL

    index <- match (trip_id, gtfs$trips [, trip_id])
    route <- gtfs$trips [index, ] [, route_id]
    gtfs$routes [route_id == route, ] [, route_short_name]
}

# Re-map the result of gtfs_route onto trip details (names of routes & stations,
# plus departure times). This is called seperately for each distinct route in
# the result.
map_one_trip <- function (gtfs, route, trip_num = 1)
{
    # no visible binding notes:
    trip_id <- stop_id <- stop_name <- departure_time <- arrival_time <- NULL

    trip_numbers <- gtfs$trip_numbers [unique (route$trip)]
    trip <- trip_numbers [trip_num, trip_numbers]

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
