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
#' @param routing_type If `"first_depart"` (default), calculates the route
#' departing with the first available service from the nominated start station.
#' Any other value will calculate the route that arrives at the nominated
#' station on the earliest available service, which may not necessarily be the
#' first-departing service.
#' @param quiet Set to `TRUE` to suppress screen messages (currently just
#' regarding timetable construction).
#'
#' @note This function will by default calculate the route that departs on the
#' first available service after the specified `start_time`, although this may
#' arrive later than subsequent services. If the earliest arriving route is
#' desired, ...
#'
#' @return square matrix of distances between nodes
#'
#' @examples
#' berlin_gtfs_to_zip () # Write sample feed from Berlin, Germany to tempdir
#' f <- file.path (tempdir (), "vbb.zip") # name of feed
#' gtfs <- extract_gtfs (f)
#' from <- "Innsbrucker Platz" # U-bahn station, not "S"
#' to <- "Alexanderplatz"
#' start_time <- 12 * 3600 + 120 # 12:02
#' route <- gtfs_route (gtfs, from = from, to = to, start_time = start_time)
#' 
#' # Specify day of week
#' route <- gtfs_route (gtfs, from = from, to = to, start_time = start_time,
#'                      day = "Sunday")
#' 
#' # specify travel by "U" = underground only
#' route <- gtfs_route (gtfs, from = from, to = to, start_time = start_time,
#'                      day = "Sunday", route_pattern = "^U")
#' # specify travel by "S" = street-level only (not underground)
#' route <- gtfs_route (gtfs, from = from, to = to, start_time = start_time,
#'                      day = "Sunday", route_pattern = "^S")
#' 
#' # Route queries are generally faster if the GTFS data are pre-processed with
#' # `gtfs_timetable()`:
#' gt <- gtfs_timetable (gtfs, day = "Sunday", route_pattern = "^S")
#' route <- gtfs_route (gt, from = from, to = to, start_time = start_time)
#'
#' @export 
gtfs_route <- function (gtfs, from, to, start_time, day = NULL,
                        route_pattern = NULL, routing_type = "first_depart",
                        quiet = FALSE)
{
    # no visible binding note:
    departure_time <- NULL

    # IMPORTANT: data.table works entirely by reference, so all operations
    # change original values unless first copied!
    gtfs_cp <- data.table::copy (gtfs)

    if (!"timetable" %in% names (gtfs_cp))
        gtfs_cp <- gtfs_timetable (gtfs_cp, day, route_pattern, quiet = quiet)

    start_time <- convert_time (start_time)
    gtfs_cp$timetable <- gtfs_cp$timetable [departure_time >= start_time, ]
    if (nrow (gtfs_cp$timetable) == 0)
        stop ("There are no scheduled services after that time.")

    stations <- NULL # no visible binding note
    start_stns <- station_name_to_ids (from, gtfs_cp)
    end_stns <- station_name_to_ids (to, gtfs_cp)

    res <- gtfs_route1 (gtfs_cp, start_stns, end_stns, start_time)

    if (!routing_type == "first_depart")
    {
        arrival_time <- max_arrival_time (res)
        gtfs_cp$timetable <- reverse_timetable (gtfs_cp$timetable, arrival_time)
        start_stns <- station_name_to_ids (to, gtfs_cp) # reversed!
        end_stns <- station_name_to_ids (from, gtfs_cp)
        start_time <- 0
        res <- gtfs_route1 (gtfs_cp, start_stns, end_stns, start_time)
    }
    return (res)
}

# core route calculation
gtfs_route1 <- function (gtfs, start_stns, end_stns, start_time)
{
    # no visible binding note:
    stop_id <- stop_name <- stop_ids <- NULL

    route <- rcpp_csa (gtfs$timetable, gtfs$transfers,
                       nrow (gtfs$stop_ids), nrow (gtfs$trip_ids),
                       start_stns, end_stns, start_time)
    if (nrow (route) == 0)
        stop ("No route found between the nominated stations")

    stns <- gtfs$stop_ids [route$stop_id] [, stop_ids]
    route$stop_name <- gtfs$stops [match (stns,
                                gtfs$stops [, stop_id]), ] [, stop_name]
    route$trip_name <- gtfs$trip_ids [, trip_ids] [route$trip_id]

    # map_one_trip maps the integer-valued stations back on to actual station
    # names. This is done seperately for each distinct trip so trip identifiers
    # can also be easily added
    trip_ids <- gtfs$trip_ids [unique (route$trip_id)] [, trip_ids]
    res <- do.call (rbind, lapply (trip_ids, function (i)
                                   map_one_trip (gtfs, route, i)))
    res [order (res$departure_time), ]
}

#gtfs_route1_reverse <- function (gtfs, start_stns, end_stns, start_time)

# names generally match to multiple IDs, each of which is returned here, as
# 0-indexed IDs into gtfs$stations
station_name_to_ids <- function (stn_name, gtfs)
{
    # no visible binding notes:
    stop_name <- stop_id <- stop_ids <- stations <- NULL

    ret <- gtfs$stops [grep (stn_name, gtfs$stops [, stop_name]), ] [, stop_id]
    ret <- match (ret, gtfs$stop_ids [, stop_ids])
    if (length (ret) == 0)
        stop (stn_name, " does not match any stations")

    return (ret)
}

# Re-map the result of gtfs_route onto trip details (names of routes & stations,
# plus departure times). This is called seperately for each distinct route in
# the result.
map_one_trip <- function (gtfs, route, route_name = "")
{
    # no visible binding notes:
    trip_id <- stop_id <- stop_ids <- stop_name <-
        departure_time <- arrival_time <- NULL

    trip_stops <- gtfs$stop_times [trip_id == route_name, ]
    trip_stop_num <- match (trip_stops [, stop_id], gtfs$stop_ids [, stop_ids])
    trip_stop_num <- trip_stop_num [which (trip_stop_num %in% route$stop_id)]
    trip_stop_id <- gtfs$stop_ids [trip_stop_num, stop_ids]
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

# get arrival time of single routing result in seconds
max_arrival_time <- function (x)
{
    arrival_times <- vapply (x$arrival_time, function (i)
                             {
                                 y <- strsplit (i, ":") [[1]]
                                 as.numeric (y [1]) * 3600 +
                                     as.numeric (y [2]) * 60 +
                                     as.numeric (y [3])
                             }, numeric (1))
    max (as.numeric (arrival_times))
}

# reverse direction of timetable, and substract all times from arrival time
reverse_timetable <- function (timetable, arrival_time)
{
    x <- timetable$departure_station
    timetable$departure_station <- timetable$arrival_station
    timetable$arrival_station <- x
    x <- timetable$departure_time
    timetable$departure_time <- timetable$arrival_time
    timetable$arrival_time <- x
    # then subtract times
    timetable$departure_time <- arrival_time - timetable$departure_time
    timetable$arrival_time <- arrival_time - timetable$arrival_time

    timetable <- timetable [which (timetable$departure_time >= 0), ]
    timetable [order (timetable$departure_time), ]
}
