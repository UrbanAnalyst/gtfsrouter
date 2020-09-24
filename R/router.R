#' gtfs_route
#'
#' Calculate single route between a start and end station departing at or after
#' a specified time.
#'
#' @param gtfs A set of GTFS data returned from \link{extract_gtfs} or, for more
#' efficient queries, pre-processed with \link{gtfs_timetable}.
#' @param from Names, IDs, or approximate (lon, lat) coordinates of start
#' stations (as `stop_name` or `stop_id` entry in the `stops` table, or a vector
#' of two numeric values). See Note.
#' @param to Corresponding Names, IDs, or coordinates of end station.
#' @param start_time Desired departure time at `from` station, either in seconds
#' after midnight, a vector of two or three integers (hours, minutes) or (hours,
#' minutes, seconds), an object of class \link{difftime}, \pkg{hms}, or
#' \pkg{lubridate}. If not provided, current time is used.
#' @param day Day of the week on which to calculate route, either as an
#' unambiguous string (so "tu" and "th" for Tuesday and Thursday), or a number
#' between 1 = Sunday and 7 = Saturday. If not given, the current day will be
#' used. (Not used if `gtfs` has already been prepared with
#' \link{gtfs_timetable}.)
#' @param route_pattern Using only those routes matching given pattern, for
#' example, "^U" for routes starting with "U" (as commonly used for underground
#' or subway routes. (Parameter not used at all if `gtfs` has already been
#' prepared with \link{gtfs_timetable}.)
#' @param earliest_arrival If `FALSE`, routing will be with the first-departing
#' service, which may not provide the earliest arrival at the `to` station. This
#' may nevertheless be useful for bulk queries, as earliest arrival searches
#' require two routing queries, while earliest departure searches require just
#' one, and so will be generally twice as fast.
#' @param include_ids If `TRUE`, result will include columns containing
#' GTFS-specific identifiers for routes, trips, and stops.
#' @param max_transfers If not `NA`, specify a maximum number of transfers
#' (including but not exceeding this number) for the route.
#' @param from_to_are_ids Set to `TRUE` to enable `from` and `to` parameter to
#' specify entries in `stop_id` rather than `stop_name` column of the `stops`
#' table.
#' @param quiet Set to `TRUE` to suppress screen messages (currently just
#' regarding timetable construction).
#'
#' @note This function will by default calculate the route that arrives earliest
#' at the specified destination, although this may depart later than the
#' earliest departing service. Routes which depart at the earliest possible time
#' can be calculated by setting `earliest_arrival = FALSE`.
#'
#' @return For single (from, to) values, a `data.frame` describing the route,
#' with each row representing one stop. For multiple (from, to) values, a list
#' of `data.frames`, each of which describes one route between the i'th start
#' and end stations (`from` and `to` values). Origin and destination stations
#' for which no route is possible return `NULL`.
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
gtfs_route <- function (gtfs, from, to, start_time = NULL, day = NULL,
                        route_pattern = NULL, earliest_arrival = TRUE,
                        include_ids = FALSE, max_transfers = NA,
                        from_to_are_ids = FALSE, quiet = FALSE)
{
    if (length (from) != length (to))
        stop ("from and to must have the same length")

    # no visible binding note:
    departure_time <- NULL

    # IMPORTANT: data.table works entirely by reference, so all operations
    # change original values unless first copied!
    gtfs_cp <- data.table::copy (gtfs)

    if (!"timetable" %in% names (gtfs_cp))
        gtfs_cp <- gtfs_timetable (gtfs_cp, day = day,
                                   route_pattern = route_pattern, quiet = quiet)

    if (is.null (start_time))
        start_time <- format (Sys.time (), "%H:%M:%S") # nocov
    start_time <- convert_time (start_time)
    gtfs_cp$timetable <- gtfs_cp$timetable [departure_time >= start_time, ]
    if (nrow (gtfs_cp$timetable) == 0)
        stop ("There are no scheduled services after that time.")

    start_stns <- from_to_to_stations (from, gtfs_cp, from_to_are_ids)
    end_stns <- from_to_to_stations (to, gtfs_cp, from_to_are_ids)

    res <- lapply (seq (start_stns), function (i)
                   gtfs_route1 (gtfs_cp, start_stns [[i]], end_stns [[i]],
                                start_time,
                                include_ids, max_transfers,
                                earliest_arrival, from_to_are_ids)
                   )

    if (length (res) == 1) {
        res <- res [[1]]
    } else {
        names (res) <- paste0 (from, " --> ", to)
    }

    return (res)
}

gtfs_route1 <- function (gtfs, start_stns, end_stns, start_time,
                         include_ids, max_transfers,
                         earliest_arrival, from_to_are_ids) {

    stations <- NULL # no visible binding note

    res <- gtfs_csa (gtfs, start_stns, end_stns, start_time,
                     include_ids, max_transfers)

    if (earliest_arrival & !is.null (res))
    {
        arrival_time <- max_arrival_time (res)
        gtfs$timetable <- reverse_timetable (gtfs$timetable, arrival_time)
        # reverse start and end stations:
        temp <- start_stns
        start_stns <- end_stns
        end_stns <- temp
        start_time <- 0
        res_e <- tryCatch (
                           gtfs_csa (gtfs, start_stns, end_stns,
                                     start_time, include_ids, max_transfers),
                           error = function (e) NULL)
        if (!is.null (res_e))
            res <- res_e
    }
    return (res)
}

# core CSA routing calculation
gtfs_csa <- function (gtfs, start_stns, end_stns, start_time,
                         include_ids, max_transfers)
{
    # no visible binding note:
   trip_id <- trip_headsign <- route_id <- route_short_name <- NULL

    if (is.na (max_transfers))
        max_transfers <- .Machine$integer.max
    route <- rcpp_csa (gtfs$timetable, gtfs$transfers,
                       nrow (gtfs$stop_ids), nrow (gtfs$trip_ids),
                       start_stns, end_stns, start_time, max_transfers)
    if (nrow (route) == 0)
        return (NULL)

    route$trip_id <- gtfs$trip_ids [, trip_ids] [route$trip_number]

    # map_one_trip maps the integer-valued stations back on to actual station
    # names. This is done seperately for each distinct trip so trip identifiers
    # can also be easily added
    trip_ids <- gtfs$trip_ids [unique (route$trip_number)] [, trip_ids]
    res <- do.call (rbind, lapply (trip_ids, function (i)
                                   map_one_trip (gtfs, route, i)))
    res <- res [order (res$departure_time), ]
    rownames (res) <- seq (nrow (res))

    # Then insert routes and trip headsigns
    res$trip_name <- NA_character_
    if ("trip_headsign" %in% names (gtfs$trips))
    {
        index <- match (res$trip_id, gtfs$trips [, trip_id])
        res$trip_name <- gtfs$trips [index, trip_headsign]
    }

    index <- match (res$trip_id, gtfs$trips [, trip_id])
    res$route_id <- gtfs$trips [index, route_id]
    index <- match (res$route_id, gtfs$routes [, route_id])
    res$route_name <- gtfs$routes [index, route_short_name]

    col_order <- c ("route_id", "route_name",
                    "trip_id", "trip_name",
                    "stop_id", "stop_name",
                    "arrival_time", "departure_time")
    if (!include_ids)
        col_order <- col_order [c (2, 4, 6:8)]
    res <- res [, col_order]

    if (all (is.na (res$trip_name)))
        res$trip_name <- NULL # nocov

    return (res)
}

# convert from and to values to indices into gtfs$stations
from_to_to_stations <- function (stns, gtfs, from_to_are_ids) {
    if (is.character (stns) | is.null (nrow (stns))) {
        ret <- lapply (stns, function (i)
                       unique (station_name_to_ids (i, gtfs, from_to_are_ids)))
    } else if (!is.null (nrow (stns))) {
        ret <- apply (stns, 1, function (i)
                      unique (station_name_to_ids (i, gtfs, from_to_are_ids)))
        if (!is.list (ret)) # for single row stns
            ret <- list (as.integer (ret))
    } else if (is.numeric (stns) & length (stns) == 2) {
        ret <- list (station_name_to_ids (stns, gtfs, from_to_are_ids))
    } else {
        stop ("from/to stations in unrecognised format")
    }
    return (ret)
}

# names generally match to multiple IDs, each of which is returned here, as
# 0-indexed IDs into gtfs$stations
station_name_to_ids <- function (stn_name, gtfs, from_to_are_ids)
{
    # no visible binding notes:
    stop_name <- stop_id <- stop_ids <- stations <- NULL

    ret <- stn_name
    if (is.numeric (stn_name))
    {
        if (length (stn_name) != 2)
            stop ("Numeric (from, to) values must have two values for (lon, lat)")
        requireNamespace ("geodist")
        names (stn_name) <- c ("lon", "lat")
        # geodist may issue warning about inaccracy of defalt 'cheap' distance,
        # but as we're only interested in the shortest distance, it can be used.
        suppressMessages (
            d <- geodist::geodist (stn_name, gtfs$stops)
        )
        # One stop name can have several IDs, each of which need to be extracted
        # here:
        this_stop <- gtfs$stops [which.min (d), ] [, stop_name]
        index <- grep (this_stop, gtfs$stops [, stop_name], fixed = TRUE)
        ret <- gtfs$stops [index, ] [, stop_id]
    }
    else if (!from_to_are_ids)
    {
        index <- grep (stn_name, gtfs$stops [, stop_name], fixed = TRUE)
        ret <- gtfs$stops [index, ] [, stop_id]
    }
    ret <- match (ret, gtfs$stops [, stop_id])
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

    this_route <- route [route$trip_id == route_name, ]

    trip_stops <- gtfs$stop_times [trip_id == route_name, ]
    # some lines are circular, and may have two entries for same start/end
    # stations.
    trip_stops <- trip_stops [trip_stops$departure_time >= min (this_route$time), ]

    trip_stop_num <- match (trip_stops [, stop_id], gtfs$stop_ids [, stop_ids])
    trip_stop_num <- trip_stop_num [which (trip_stop_num %in%
                                           this_route$stop_number)]
    trip_stop_id <- gtfs$stop_ids [trip_stop_num, stop_ids]
    trip_stop_names <- gtfs$stops [match (trip_stop_id, gtfs$stops [, stop_id]),
                                   stop_name]
    trip_stops <- trip_stops [which (trip_stops [, stop_id %in%
                                     trip_stop_id]), ]
    trip_stop_departure <- format_time (trip_stops [, departure_time])
    trip_stop_arrival <- format_time (trip_stops [, arrival_time])
    data.frame (trip_id = route_name,
                stop_name = trip_stop_names,
                stop_id = trip_stop_id,
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
