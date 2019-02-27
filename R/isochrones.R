#' gtfs_isochrones
#'
#' Calculate all possible isochrones from a given start station.
#'
#' @param gtfs A set of GTFS data returned from \link{extract_gtfs} or, for more
#' efficient queries, pre-processed with \link{gtfs_timetable}.
#' @param from Name of start station
#' @param time_incr Temporal increment of isochrone in seconds.
#' @param quiet If `FALSE`, display progress bar and other information.
#'
#' @return don't know yet
#'
#' @examples
#' berlin_gtfs_to_zip ()
#' f <- file.path (tempdir (), "vbb.zip")
#' g <- extract_gtfs (f)
#' g <- gtfs_timetable (g)
#' from <- "Schonlein"
#' all_routes <- gtfs_isochrones (g, from, time_incr = 600)
#' @export 
gtfs_isochrones <- function (gtfs, from, time_incr, quiet = FALSE)
{
    # no visible binding notes:
    departure_time <- NULL

    start_stns <- station_name_to_ids (from, gtfs)

    start_time <- 0
    index <- which (gtfs$timetable$departure_station %in% start_stns)
    last_depart <- max (gtfs$timetable [index, departure_time])

    isotrips <- list (start_time = start_time)
    all_routes <- NULL
    if (!quiet)
        pb <- utils::txtProgressBar (style = 3)
    while (start_time < last_depart)
    {
        start_time <- isotrips$start_time + 1
        end_time <- start_time + time_incr
        isotrips <- tryCatch (get_isotrips (gtfs, start_stns,
                                            start_time, end_time),
                              error = function (e) e)
        if (methods::is (isotrips, "error"))
            next

        # cut to terminal routes only
        isoroutes <- lapply (isotrips$isotrips, function (i)
                             i [i$route_id == i$route_id [nrow (i)], ])
        if (is.null (all_routes))
        {
            isoroutes_all <- do.call (rbind, isoroutes)
            route_ids <- unique (isoroutes_all$route_id)
            all_routes <- rep (list (NULL), length (route_ids))
            names (all_routes) <- route_ids
        }
        all_routes <- increment_all_routes (isoroutes, all_routes)
        if (!quiet)
            utils::setTxtProgressBar (pb, start_time / last_depart)
    }
    if (!quiet)
        close (pb)

    return (all_routes)
}

increment_all_routes <- function (isoroutes, all_routes)
{
    for (i in isoroutes)
    {
        if (!i$route_id [1] %in% names (all_routes))
        {
            nms <- names (all_routes)
            temp <- rep (0, nrow (i))
            temp [length (temp)] <- 1
            names (temp) <- i$parent_station
            all_routes [[length (all_routes) + 1]] <- temp
            names (all_routes) <- c (nms, i$route_id [1])
        } else
        {
            j <- match (i$route_id [1], names (all_routes))
            if (is.null (all_routes [[j]]))
            {
                all_routes [[j]] <- rep (0, nrow (i))
                names (all_routes [[j]]) <- i$parent_station
                index <- match (i$parent_station [nrow (i)],
                                names (all_routes [[j]]))
                all_routes [[j]] [index] <- all_routes [[j]] [index] + 1
            } else
            {
                all_stops <- paste0 (names (all_routes [[j]]), collapse = "")
                stops_j <- paste0 (i$parent_station, collapse = "")
                if (grepl (stops_j, all_stops))
                {
                    index <- match (i$parent_station, names (all_routes [[j]]))
                    all_routes [[j]] [max (index)] <-
                        all_routes [[j]] [max (index)] + 1
                } else if (grepl (all_stops, stops_j))
                { # stops_j is larger than all_stops [[j]]
                    all_routes_j <- rep (0, nrow (i))
                    names (all_routes_j) <- i$parent_station
                    index <- match (names (all_routes [[j]]), i$parent_station)
                    all_routes_j [index] <- all_routes_j [index] + all_routes [[j]]
                    all_routes_j [length (all_routes_j)] <-
                        all_routes_j [length (all_routes_j)] + 1
                    all_routes [[j]] <- all_routes_j
                } else 
                {
                    # dunno?
                }
            }
        }
    }
    return (all_routes)
}

