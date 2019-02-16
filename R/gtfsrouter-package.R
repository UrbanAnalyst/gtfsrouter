#' gtfsrouter
#'
#' Find the quickest route between two points at a particular start time with
#' GTFS feed.
#' @name gtfsrouter
#' @docType package
#' @importFrom Rcpp evalCpp
#' @useDynLib gtfsrouter, .registration = TRUE
NULL

#' berlin_gtfs
#'
#' Sample GTFS data from Verkehrsverbund Berlin-Brandenburg street, reduced to U
#' and S Bahn only (underground and overground trains), and between the hours of
#' 12:00-13:00. Only those components of the GTFS data necessary for routing
#' have been retained. Note that non-ASCII characters have been removed from
#' these data, so umlauts are simply removed and eszetts become "ss". The
#' package will nevertheless work with full GTFS feeds and non-ASCII (UTF-8)
#' characters.
#'
#' @name berlin_gtfs
#' @docType data
#' @keywords datasets
#' @format A list of five \pkg{data.table} items necessary for routing:
#' \itemize{
#' \item calendar
#' \item routes
#' \item trips
#' \item stop_times
#' \item stops
#' \item transfers
#' }
#'
#' @note Can be re-created with the script in 
#' \url{https://github.com/ATFutures/gtfs-router/blob/master/data-raw/data-script.Rmd}.
#' @inherit gtfs_route return examples
NULL

