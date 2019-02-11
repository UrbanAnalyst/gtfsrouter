#' extract_gtfs
#'
#' Extract "stop_times" and "transfers" table from a GTFS `zip` archive.
#'
#' @param filename Name of GTFS archive
#' @return List of 2 \pkg{data.table} objects, one for "stop_times" and one for
#' "transfers"
#' @importFrom data.table :=
#' @export
extract_gtfs <- function (filename = NULL)
{
    if (is.null (filename))
        stop ("filename must be given")
    if (!file.exists (filename))
        stop ("filename ", filename, " does not exist")

    flist <- utils::unzip (filename, list = TRUE)
    if (!(any (grepl ("routes.txt", flist$Name)) &
          any (grepl ("trips.txt", flist$Name)) &
          any (grepl ("stop_times.txt", flist$Name)) &
          any (grepl ("stops.txt", flist$Name)) &
          any (grepl ("transfers.txt", flist$Name))))
        stop (filename, " does not appear to be a GTFS file; ",
              "it must minimally contain\n   'routes.txt', stop_times.txt' ",
              "'stop_times.txt', 'stops.txt', and 'transfers.txt'")

    # suppress no visible binding for global variables notes:
    arrival_time <- departure_time <- stop_id <- min_transfer_time <- 
        from_stop_id <- to_stop_id <- trip_id <- `:=` <- NULL

    stop_times <- flist$Name [grep ("stop_times", flist$Name)]
    stop_times <- data.table::fread (cmd = paste0 ("unzip -p \"", filename,
                                                   "\" \"", stop_times, "\""),
                                     integer64 = "character",
                                     showProgress = FALSE)
    stop_times [, arrival_time := rcpp_time_to_seconds (arrival_time)]
    stop_times [, departure_time := rcpp_time_to_seconds (departure_time)]
    stop_times [, trip_id := paste0 (trip_id)]

    stops <- flist$Name [grep ("stops", flist$Name)]
    stops <- data.table::fread (cmd = paste0 ("unzip -p \"", filename,
                                                   "\" \"", stops, "\""),
                                integer64 = "character",
                                showProgress = FALSE)

    transfers <- flist$Name [grep ("transfers", flist$Name)]
    transfers <- data.table::fread (cmd = paste0 ("unzip -p \"", filename,
                                                  "\" \"", transfers, "\""),
                                    integer64 = "character",
                                    showProgress = FALSE)
    transfer = stop_times [, stop_id] %in% transfers [, from_stop_id]
    #stop_times <- stop_times [, transfer := transfer] [order (departure_time)]
    stop_times <- stop_times [, transfer := transfer]

    index <- which (transfers [, from_stop_id] %in% stop_times [, stop_id] &
                    transfers [, to_stop_id] %in% stop_times [, stop_id])
    transfers <- transfers [index]
    transfers [, min_transfer_time := replace (min_transfer_time,
                                               is.na (min_transfer_time), 0)]

    # trips and routes tables used just to map trips onto route IDs at final
    # step of route_gtfs().
    trips <- flist$Name [grep ("trips", flist$Name)]
    trips <- data.table::fread (cmd = paste0 ("unzip -p \"", filename,
                                                   "\" \"", trips, "\""),
                                     integer64 = "character",
                                     showProgress = FALSE)

    routes <- flist$Name [grep ("routes", flist$Name)]
    routes <- data.table::fread (cmd = paste0 ("unzip -p \"", filename,
                                               "\" \"", routes, "\""),
                                 integer64 = "character",
                                 showProgress = FALSE)

    list (stop_times = stop_times,
          stops = stops,
          transfers = transfers,
          trips = trips,
          routes = routes)
}

