#' gtfs_isochrone
#'
#' Calculate an isochrone from a given start station, returning the list of all
#' stations reachable to the specified `end_time`.
#'
#' @param gtfs A set of GTFS data returned from \link{extract_gtfs} or, for more
#' efficient queries, pre-processed with \link{gtfs_timetable}.
#' @param from Name of start station
#' @param start_time Desired departure time at `from` station, either in seconds
#' after midnight, a vector of two or three integers (hours, minutes) or (hours,
#' minutes, seconds), an object of class \link{difftime}, \pkg{hms}, or
#' \pkg{lubridate}.
#' @param end_time End time to calculate isochrone
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
#' @export 
gtfs_isochrone <- function (gtfs, from, start_time, end_time, day = NULL,
                            route_pattern = NULL)
{
    if (!"timetable" %in% names (gtfs))
        gtfs <- gtfs_timetable (gtfs, day, route_pattern)

    # no visible binding note:
    departure_time <- stop_id <- NULL

    start_time <- convert_time (start_time)
    gtfs$timetable <- gtfs$timetable [departure_time >= start_time, ]
    if (nrow (gtfs$timetable) == 0)
        stop ("There are no scheduled services after that time.")

    stations <- NULL # no visible binding note
    start_stns <- station_name_to_ids (from, gtfs)

    stns <- rcpp_csa_isochrone (gtfs$timetable, gtfs$transfers,
                                gtfs$n_stations, gtfs$n_trips, start_stns,
                                start_time, end_time)
    stns <- gtfs$stations [stns] [, stations]

    stops <- gtfs$stops [match (stns, gtfs$stops [, stop_id]), ]
    stops <- data.frame (stops [, c ("stop_name", "stop_lat", "stop_lon")])

    class (stops) <- c ("gtfs_isochrone", class (stops))
    return (stops)
}


#' plot.gtfs_isochrone
#'
#' @name plot.gtfs_ischrone
#' @param x object to be plotted
#' @param hull_alpha alpha value of non-convex hulls (see ?alphashape::ashape
#' for details).
#' @param ... ignored here
#' @export
plot.gtfs_isochrone <- function (x, ..., hull_alpha = 0.1)
{
    requireNamespace ("sf")
    requireNamespace ("alphahull")
    requireNamespace ("mapview")

    hull <- get_ahull (x)

    bdry <- sf::st_polygon (list (as.matrix (hull [, 2:3])))
    bdry <- sf::st_sf (sf::st_sfc (bdry, crs = 4326))

    x_sf <- sapply (seq (nrow (x)), function (i) {
        sf::st_sfc (sf::st_point (as.numeric (x [i, c ("stop_lon", "stop_lat")])))
                                })
    x_sf <- sf::st_sf (name = x$stop_name,
                       geometry= sf::st_sfc (x_sf, crs = 4326))

    m <- mapview::mapview (x_sf, cex = 5, color = "red", col.regions = "blue",
                           legend = FALSE)
    mapview::addFeatures (m, bdry, color = "orange")
}

get_ahull <- function (x)
{
    xy <- data.frame ("x" = x$stop_lon, "y" = x$stop_lat)
    xy <- xy [!duplicated (xy), ]
    alpha <- 0.1
    a <- data.frame (alphahull::ashape (xy, alpha = alpha)$edges)

    xy <- rbind (data.frame (ind = a$ind1, x = a$x1, y = a$y1),
                 data.frame (ind = a$ind2, x = a$x2, y = a$y2))
    xy <- xy [!duplicated (xy), ]
    xy <- xy [order (xy$ind), ]
    inds <- data.frame (ind1 = a$ind1, ind2 = a$ind2)
    # Wrap those indices around xy:
    # TODO: Find a better way to do this!
    ind_seq <- as.numeric (inds [1, ])
    inds <- inds [-1, ]
    while (nrow (inds) > 0)
    {
        j <- which (inds$ind1 == utils::tail (ind_seq, n = 1))
        if (length (j) > 0)
        {
            ind_seq <- c (ind_seq, inds [j, 2])
        } else
        {
            j <- which (inds$ind2 == utils::tail (ind_seq, n = 1))
            ind_seq <- c (ind_seq, inds [j, 1])
        }
        inds <- inds [-j, , drop = FALSE] #nolint
    }
    xy [match (ind_seq, xy$ind), ]
}
