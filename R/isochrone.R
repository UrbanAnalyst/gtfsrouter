#' gtfs_isochrone
#'
#' Calculate a single isochrone from a given start station, returning the list
#' of all stations reachable to the specified `end_time`.
#'
#' @param gtfs A set of GTFS data returned from \link{extract_gtfs} or, for more
#' efficient queries, pre-processed with \link{gtfs_timetable}.
#' @param from Name, ID, or approximate (lon, lat) coordinates of start station
#' (as `stop_name` or `stop_id` entry in the `stops` table, or a vector of two
#' numeric values).
#' @param start_time Desired departure time at `from` station, either in seconds
#' after midnight, a vector of two or three integers (hours, minutes) or (hours,
#' minutes, seconds), an object of class \link{difftime}, \pkg{hms}, or
#' \pkg{lubridate}.
#' @param end_time End time to calculate isochrone
#' @param from_is_id Set to `TRUE` to enable `from` parameter to specify entry
#' in `stop_id` rather than `stop_name` column of the `stops` table (same as
#' `from_to_are_ids` parameter of \link{gtfs_route}).
#' @param minimise_transfers If `TRUE`, isochrones are calculated with
#' minimal-transfer connections to each end point, even if those connections are
#' slower than alternative connections with transfers.
#' @param hull_alpha alpha value of non-convex hulls returned as part of result
#' (see ?alphashape::ashape for details).
#'
#' @inheritParams gtfs_route
#'
#' @return An object of class `gtfs_isochrone`, including \pkg{sf}-formatted
#' points representing the `from` station (`start_point`), the terminal end
#' stations (`end_points`), and all intermediate stations (`mid_points`) each
#' with the earliest possible arrival time, along with lines representing the
#' individual routes. A non-convex ("alpha") hull is also returned (as an
#' \pkg{sf} `POLYGON` object), including measures of area and "elongation",
#' which equals zero for a circle, and increases towards one for more elongated
#' shapes.
#'
#' @examples
#' berlin_gtfs_to_zip ()
#' f <- file.path (tempdir (), "vbb.zip")
#' g <- extract_gtfs (f)
#' g <- gtfs_timetable (g)
#' from <- "Alexanderplatz"
#' start_time <- 12 * 3600 + 600
#' end_time <- start_time + 600
#' ic <- gtfs_isochrone (g,
#'                       from = from,
#'                       start_time = start_time,
#'                       end_time = end_time)
#' \dontrun{
#' plot (ic)
#' }
#' @export
gtfs_isochrone <- function (gtfs, from, start_time, end_time, day = NULL,
                            from_is_id = FALSE, route_pattern = NULL,
                            minimise_transfers = FALSE,
                            hull_alpha = 0.1, quiet = FALSE) {

    requireNamespace ("geodist")
    requireNamespace ("lwgeom")

    if (!"timetable" %in% names (gtfs))
        gtfs <- gtfs_timetable (gtfs, day, route_pattern, quiet = quiet)

    gtfs_cp <- data.table::copy (gtfs)

    # no visible binding note:
    departure_time <- NULL

    start_time <- convert_time (start_time)
    end_time <- convert_time (end_time)
    gtfs_cp$timetable <- gtfs_cp$timetable [departure_time >= start_time, ]
    if (nrow (gtfs_cp$timetable) == 0)
        stop ("There are no scheduled services after that time.")

    stations <- NULL # no visible binding note # nolint
    start_stns <- station_name_to_ids (from, gtfs_cp, from_is_id)

    isotrips <- get_isotrips (gtfs_cp, start_stns, start_time, end_time,
                              minimise_transfers)

    routes <- route_to_linestring (isotrips$isotrips)
    xy <- as.numeric (isotrips$isotrips [[1]] [1, c ("stop_lon", "stop_lat")])
    startpt <- sf::st_sfc (sf::st_point (xy), crs = 4326)
    nm <- isotrips$isotrips [[1]] [1, "stop_name"]
    id <- isotrips$isotrips [[1]] [1, "stop_id"]
    startpt <- sf::st_sf ("stop_name" = nm,
                          "stop_id" = id,
                          geometry = startpt)

    hull <- NULL
    if (length (isotrips$isotrips) > 1)
        hull <- isohull (isotrips$isotrips, hull_alpha = hull_alpha)

    res <- list (start_point = startpt,
                 mid_points = route_midpoints (isotrips$isotrips),
                 end_points = route_endpoints (isotrips$isotrips),
                 routes = routes,
                 hull = hull,
                 start_time = isotrips$start_time,
                 end_time = isotrips$end_time)

    class (res) <- c ("gtfs_isochrone", class (res))
    return (res)
}

get_isotrips <- function (gtfs, start_stns, start_time, end_time,
                          minimise_transfers = FALSE) {

    stop_id <- trip_id <- NULL # no visible binding note:# nolint

    # the C++ function returns a single list with elements group in threes:
    # 1. End stations
    # 2. Trip numbers
    # 3. Arrival times at each end station
    stns <- rcpp_isochrone (gtfs$timetable, gtfs$transfers,
                            nrow (gtfs$stop_ids), start_stns,
                            start_time, end_time,
                            minimise_transfers)
    if (length (stns) < 2)
        stop ("No isochrone possible") # nocov

    index <- 3 * 1:((length (stns) - 1) / 3) - 2
    trips <- stns [index + 1]
    earliest_arrival <- stns [index + 2]
    stns <- stns [index]

    index <- which (vapply (stns, function (i) !is.null (i), logical (1)))
    # replace MAXINT trips with NA:
    trips <- lapply (trips [index], function (i) {
                     i [which (i == .Machine$integer.max)] <- NA_integer_
                     return (i) })
    earliest_arrival <- earliest_arrival [index]
    stns <- stns [index]

    # rm any notional end stations which are part of other journeys
    end_stns <- vapply (stns, function (i) i [length (i)], integer (1))
    non_end_stns <- unlist (lapply (stns, function (i) i [-length (i)]))
    index <- which (!end_stns %in% non_end_stns)

    trips <- trips [index]
    earliest_arrival <- earliest_arrival [index]
    stns <- stns [index]

    actual_start_time <- min (vapply (earliest_arrival, min, integer (1)))

    isotrips <- lapply (seq (stns), function (i) {
                       s <- gtfs$stops [stns [[i]],
                                        c ("stop_id",
                                           "stop_name",
                                           "parent_station",
                                           "stop_lon",
                                           "stop_lat")]
                       tr <- gtfs$trips [trips [[i]],
                                         c ("route_id",
                                            "trip_id",
                                            "trip_headsign")]
                       # get num transfers
                       index <- which (!is.na (trips [[i]]))
                       tripi <- stats::na.omit (trips [[i]])
                       ntransfers <- match (tripi, unique (tripi)) - 1L
                       tr$ntransfers <- NA_integer_
                       tr$ntransfers [index] <- ntransfers

                       e <- hms::hms (earliest_arrival [[i]])
                       ret <- data.frame (cbind (s,
                                                 tr,
                                                 earliest_arrival = e))
                   })

    # Then cut them down to within the alloted isochrone durations:
    dur <- end_time - start_time
    isotrips <- lapply (isotrips, function (i) {
                            tdiff <- i$earliest_arrival - i$earliest_arrival [1]
                            return (i [which (tdiff < dur), ])  })
    isotrips <- isotrips [which (!duplicated (isotrips))]

    list (isotrips = isotrips,
          start_time = actual_start_time,
          end_time = as.integer (actual_start_time + end_time - start_time))
}

# convert each isotrip to sf linestring
route_to_linestring <- function (x) {

    xy <- lapply (x, function (i)
                  sf::st_linestring (cbind (i$stop_lon, i$stop_lat)))
    sf::st_sfc (xy, crs = 4326)
}

# extract endpoints of each route as sf point objects
route_endpoints <- function (x) {

    xy <- lapply (x, function (i)
                  as.numeric (i [nrow (i), c ("stop_lon", "stop_lat")]))
    xy <- do.call (rbind, xy)
    xy <- data.frame ("x" = xy [, 1], "y" = xy [, 2])
    g <- sf::st_as_sf (xy, coords = 1:2, crs = 4326)$geometry
    nms <- vapply (x, function (i)
                  i [nrow (i), "stop_name"], character (1))
    ids <- vapply (x, function (i)
                  i [nrow (i), "stop_id"], character (1))
    arrival <- vapply (x, function (i)
                       i [nrow (i), "earliest_arrival"],
                       hms::hms (1))
    departure <- vapply (x, function (i)
                        i$earliest_arrival [1],
                        hms::hms (1))

    transfers <- vapply (x, function (i)
                         max (i$ntransfers, na.rm = TRUE),
                         integer (1))

    sf::st_sf ("stop_name" = nms,
               "stop_id" = ids,
               "departure" = hms::hms (departure),
               "arrival" = hms::hms (arrival),
               "duration" = hms::hms (arrival - departure),
               "transfers" = transfers,
               geometry = g)
}

route_midpoints <- function (x) {

    # NAs for trip IDs between transfer stations, which can be removed here
    # anyway
    x <- lapply (x, function (i) stats::na.omit (i))

    xy <- lapply (x, function (i)
                  as.matrix (i [-c (1, nrow (i)), c ("stop_lon", "stop_lat")]))
    xy <- do.call (rbind, xy)
    xy <- data.frame ("x" = xy [, 1], "y" = xy [, 2])
    g <- sf::st_as_sf (xy, coords = 1:2, crs = 4326)$geometry
    nms <- lapply (x, function (i)
                  i [-c (1, nrow (i)), "stop_name"])
    ids <- lapply (x, function (i)
                  i [-c (1, nrow (i)), "stop_id"])

    arrival <- lapply (x, function (i) i$earliest_arrival [-c (1, nrow (i))])
    arrival <- do.call (c, arrival)

    departure <- lapply (x, function (i)
                        rep (i$earliest_arrival [1], nrow (i) - 2))
    departure <- do.call (c, departure)

    duration <- hms::hms (as.integer (arrival) - departure)

    transfers <- do.call (c, lapply (x, function (i)
                                     i$ntransfers [-c (1, nrow (i))]))

    sf::st_sf ("stop_name" = do.call (c, nms),
               "stop_id" = do.call (c, ids),
               "departure" = departure,
               "arrival" = arrival,
               "duration" = duration,
               "transfers" = transfers,
               geometry = g)
}

# x is isolines
isohull <- function (x, hull_alpha) {

    xy <- lapply (x, function (i)
                  as.matrix (i [, c ("stop_lon", "stop_lat")]))
    xy <- do.call (rbind, xy)
    if (length (which (!duplicated (xy))) < 3)
        return (NULL) # nocov
    hull <- get_ahull (xy, alpha = hull_alpha)
    if (nrow (hull) < 3)
        return (NULL) # nocov

    hull <- rbind (hull, hull [1, ])

    bdry <- sf::st_polygon (list (as.matrix (hull [, 2:3])))
    geometry <- sf::st_sfc (bdry, crs = 4326)
    sf::st_sf (area = sf::st_area (geometry),
               elongation = 1 - hull_ratio (geometry),
               geometry = geometry)
}

# ratio of lengths of minor / major axes of the hull
hull_ratio <- function (x) {

    xy <- sf::st_coordinates (x)
    d <- geodist::geodist (xy)
    d [lower.tri (d)] <- 0
    i <- which.max (apply (d, 1, max))
    j <- which.max (apply (d, 2, max))
    major_axis <- rbind (xy [i, c ("X", "Y")],
                         xy [j, c ("X", "Y")])
    major_axis <- sf::st_sfc (sf::st_linestring (major_axis), crs = 4326)
    index <- seq (nrow (xy)) [!seq (nrow (xy)) %in% c (i, j)]
    pts <- sf::st_as_sf (data.frame (xy [index, ]), coords = 1:2, crs = 4326)

    minor_axis_dist <- as.numeric (max (sf::st_distance (pts, major_axis)))
    minor_axis_dist / max (d)
}

get_ahull <- function (x, alpha = alpha) {

    x <- stats::na.omit (x [!duplicated (x), ])
    alpha <- 0.1
    a <- data.frame (alphahull::ashape (x, alpha = alpha)$edges)

    xy <- rbind (data.frame (ind = a$ind1, x = a$x1, y = a$y1),
                 data.frame (ind = a$ind2, x = a$x2, y = a$y2))
    xy <- xy [!duplicated (xy), ]
    xy <- xy [order (xy$ind), ]
    inds <- data.frame (ind1 = a$ind1, ind2 = a$ind2)
    # Wrap those indices around xy:
    # TODO: Find a better way to do this!
    ind_seq <- as.numeric (inds [1, ])
    inds <- inds [-1, ]
    while (nrow (inds) > 0) {
        j <- which (inds$ind1 == utils::tail (ind_seq, n = 1))
        if (length (j) > 0) {
            ind_seq <- c (ind_seq, inds [j, 2])
        } else {
            j <- which (inds$ind2 == utils::tail (ind_seq, n = 1))
            ind_seq <- c (ind_seq, inds [j, 1])
        }
        inds <- inds [-j, , drop = FALSE] #nolint
    }
    xy [match (ind_seq, xy$ind), ]
}
