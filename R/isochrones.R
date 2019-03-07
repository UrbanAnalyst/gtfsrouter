#' gtfs_median_isochrones
#'
#' Calculate all possible isochrones from a given start station using the median
#' graph of a GTFS data set.
#'
#' @param graph A GTFS median graph, processed from a GTFS data set with
#' \link{extract_gtfs}, \link{gtfs_timetable}, \link{gtfs_median_timetable}, and
#' \link{gtfs_median_graph}
#' @param station Integer defining start station as index into `gtfs$stop_ids`
#'
#' @return Vector of median times taken to reach each station in
#' `gtfs$stop_ids`.
#'
#' @examples
#' berlin_gtfs_to_zip ()
#' f <- file.path (tempdir (), "vbb.zip")
#' gtfs <- extract_gtfs (f)
#' gtfs <- gtfs_timetable (gtfs, day = 1:7)
#' tt <- gtfs_median_timetable (gtfs)
#' graph <- gtfs_median_graph (tt, gtfs)
#' d <- gtfs_median_isochrones (graph, station = 100)
#' @export 
gtfs_median_isochrones <- function (graph, station)
{
    # nverts is +1 because they're all 1-indexed
    nverts <- max (c (graph$departure_station, graph$arrival_station)) + 1
    d <- rcpp_median_dijkstra (nverts, graph, station)
    d$time [d$time == max (d$time)] <- NA
    d$distance [d$distance == max (d$distance)] <- NA
    d <- d [-1, ] # because first one is the 0-index which is not used

    return (d)
}
