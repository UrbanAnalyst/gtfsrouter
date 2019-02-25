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
#' @param quiet Set to `TRUE` to suppress screen messages (currently just
#' regarding timetable construction).
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
                        route_pattern = NULL, quiet = FALSE)
{
    # IMPORTANT: data.table works entirely by reference, so all operations
    # change original values unless first copied! This function thus returns a
    # copy even when it does nothing else, so always entails some cost.
    gtfs_cp <- data.table::copy (gtfs)

    if (!"timetable" %in% names (gtfs_cp))
        gtfs_cp <- gtfs_timetable (gtfs_cp, day, route_pattern, quiet = quiet)

    # no visible binding note:
    departure_time <- stop_id <- stop_name <- stop_ids <- NULL

    start_time <- convert_time (start_time)
    gtfs_cp$timetable <- gtfs_cp$timetable [departure_time >= start_time, ]
    if (nrow (gtfs_cp$timetable) == 0)
        stop ("There are no scheduled services after that time.")

    stations <- NULL # no visible binding note
    start_stns <- station_name_to_ids (from, gtfs_cp)
    end_stns <- station_name_to_ids (to, gtfs_cp)

    route <- rcpp_csa (gtfs_cp$timetable, gtfs_cp$transfers,
                       nrow (gtfs_cp$stop_ids), nrow (gtfs_cp$trip_ids),
                       start_stns, end_stns, start_time)
    if (nrow (route) == 0)
        stop ("No route found between the nominated stations")

    stns <- gtfs_cp$stop_ids [route$stop_id] [, stop_ids]
    route$stop_name <- gtfs_cp$stops [match (stns,
                                gtfs_cp$stops [, stop_id]), ] [, stop_name]

    # map_one_trip maps the integer-valued stations back on to actual station
    # names. This is done seperately for each distinct trip so trip identifiers
    # can also be easily added
    do.call (rbind, lapply (rev (seq (unique (route$trip))), function (i)
                            map_one_trip (gtfs_cp, route, i)))
}

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
    trip_id <- stop_id <- stop_ids <- stop_name <-
        departure_time <- arrival_time <- NULL

    trip_ids <- gtfs$trip_ids [unique (route$trip)]
    trip <- trip_ids [trip_num, trip_ids]

    route_name <- get_route_name (gtfs, trip_id = trip)

    trip_stops <- gtfs$stop_times [trip_id == trip, ]
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
