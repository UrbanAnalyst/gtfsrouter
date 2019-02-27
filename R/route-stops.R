#' gtfs_route_stops
#'
#' Get lists of stop sequences for a specified route
#'
#' @param gtfs A set of GTFS data returned from \link{extract_gtfs} or, for more
#' efficient queries, pre-processed with \link{gtfs_timetable}.
#' @param route_id Character vector of `route_id` from the GTFS "routes.txt" table
#' @return List of `data.frame` objects containing sequences of `stop_id` and
#' `stop_name` values for that route.
#'
#' @examples
#' berlin_gtfs_to_zip ()
#' f <- file.path (tempdir (), "vbb.zip")
#' g <- extract_gtfs (f)
#' route_id <- "10141_109"
#' r <- gtfs_route_stops (g, route_id)
#'
#' @export
gtfs_route_stops <- function (gtfs, route_id)
{
    route_stops <- get_all_route_stops (gtfs, route_id)
    route_stops <- clean_all_route_stops (route_stops)
    all_stops <- data.frame (gtfs$stops [, c ("stop_id", "stop_name")])
    lapply (route_stops, function (i)
            all_stops [match (i, all_stops$stop_id), ])
}

# return initial list of all sequences of route stops. Some of these may differ
# by only one station, in which case they are subsequently removed with
# `clean_route_stops()`.
get_all_route_stops <- function (gtfs, route_id_i)
{
    # no visible binding notes:
    route_id <- trip_id <- stop_id <- NULL

    trips <- gtfs$trips [route_id == route_id_i] [, trip_id]
    stops <- list ()
    for (i in trips)
    {
        stops_i <- gtfs$stop_times [trip_id == i] [, stop_id]
        if (length (stops_i) == 0)
            next
        if (length (stops) == 0)
            stops [[1]] <- stops_i
        else {
            # return values:
            # 1 : contained in a current list; don't do anything
            # 2 : extends a current list;
            # 3 : diverges from a current list
            # 4 : not included at all in any current list
            chk <- vapply (stops, function (j) {
                               index <- match (stops_i, j)
                               if (!any (is.na (index)))
                                   ret <- 1L
                               else if (all (is.na (index)))
                                   ret <- 4L
                               else {
                                   mini <- min (index, na.rm = TRUE)
                                   maxi <- max (index, na.rm = TRUE)
                                   if (min (index, na.rm = TRUE) == 1 |
                                       max (index, na.rm = TRUE) == length (i))
                                       ret <- 2L
                                   else
                                       ret <- 3L
                               }
                               return (ret)
                        }, integer (1))
            if (min (chk) > 2)
                stops [[length (stops) + 1]] <- stops_i
            else if (any (chk) == 2)
            {
                stops_j <- stops [[which.min (chk)]]
                index <- match (stops_i, stops_j)
                if (index [length (index)] == 1)
                    stops [[which.min (chk)]] <- c (stops_i, stops_j [-1])
            }
        }
    }
    return (stops)
}

clean_all_route_stops <- function (route_stops)
{
    rms <- NULL
    for (i in seq (route_stops))
    {
        stops_i <- route_stops [-i]
        chk <- vapply (stops_i, function (j) {
                           index <- match (j, route_stops [[i]])
                           length (which (is.na (index))) == 1
                        }, logical (1))
        if (any (chk))
            rms <- c (rms, seq (route_stops) [-i] [which (chk)])
    }
    route_stops [unique (rms)] <- NULL

    return (route_stops)
}
