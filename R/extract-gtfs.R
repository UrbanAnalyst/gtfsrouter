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
    if (!("stop_times.txt" %in% flist$Name & "transfers.txt" %in% flist$Name))
        stop (filename, " does not appear to be a GTFS file; ",
              "it must contain 'stop_times.txt' and 'transfers.txt'")

    # suppress no visible binding for global variables notes:
    arrival_time <- departure_time <- stop_id <- min_transfer_time <- 
        from_stop_id <- to_stop_id <- `:=` <- NULL

    stop_times <- data.table::fread (cmd = paste0 ("unzip -p \"", filename,
                                                   "\" \"stop_times.txt\""),
                                     showProgress = FALSE)
    stop_times [, arrival_time := rcpp_time_to_seconds (arrival_time)]
    stop_times [, departure_time := rcpp_time_to_seconds (departure_time)]

    transfers <- data.table::fread (cmd = paste0 ("unzip -p \"", filename,
                                                  "\" \"transfers.txt\""),
                                    showProgress = FALSE)
    transfer = stop_times [, stop_id] %in% transfers [, from_stop_id]
    stop_times <- stop_times [, transfer := transfer] [order (departure_time)]

    index <- which (transfers [, from_stop_id] %in% stop_times [, stop_id] &
                    transfers [, to_stop_id] %in% stop_times [, stop_id])
    transfers <- transfers [index]
    transfers [, min_transfer_time := replace (min_transfer_time,
                                               is.na (min_transfer_time), 0)]

    list (stop_times = stop_times,
          transfers = transfers)
}

