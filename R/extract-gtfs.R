#' extract_gtfs
#'
#' Extract "stop_times" and "transfers" table from a GTFS `zip` archive.
#'
#' @param filename Name of GTFS archive
#' @return List of 2 \pkg{data.table} objects, one for "stop_times" and one for
#' "transfers"
#' @importFrom data.table :=
#'
#' @examples
#' berlin_gtfs_to_zip () # Write sample feed from Berlin, Germany to tempdir
#' f <- file.path (tempdir (), "vbb.zip") # name of feed
#' gtfs <- extract_gtfs (f)
#'
#' @export
extract_gtfs <- function (filename = NULL)
{
    if (is.null (filename))
        stop ("filename must be given")
    if (!file.exists (filename))
        stop ("filename ", filename, " does not exist")

    # suppress no visible binding for global variables notes:
    arrival_time <- departure_time <- stop_id <- min_transfer_time <- 
        from_stop_id <- to_stop_id <- trip_id <- `:=` <- 
        routes <- stops <- stop_times <- trips <- NULL

    flist <- utils::unzip (filename, list = TRUE)

    # GTFS **must** contain "agency", "stops", "routes", "trips", and
    # "stop_times", but "agency" is not used here, so
    need_these_files <- c ("routes", "stops", "stop_times", "trips")
    checks <- vapply (need_these_files, function (i)
                      any (grepl (paste0 (i, ".txt"), flist$Name)), logical (1))
    if (!all (checks))
        stop (filename, " does not appear to be a GTFS file; ",
              "it must minimally contain\n  ",
              paste (need_these_files, collapse = ", "))
    missing_transfers <- type_missing (flist, "transfers")
    missing_calendar <- type_missing (flist, "calendar")

    for (f in flist$Name)
    {
        fout <- data.table::fread (cmd = paste0 ("unzip -p ", filename,
                                                 " \"", f, "\""),
                                   integer64 = "character",
                                   showProgress = FALSE)
        assign (gsub (".txt", "", basename (f)), fout, pos = -1)
    }
    if (nrow (routes) == 0 | nrow (stops) == 0 | nrow (stop_times) == 0 |
        nrow (trips) == 0)
        stop (filename, " does not appear to be a GTFS file; ",
              "it must minimally contain\n  ",
              paste (need_these_files, collapse = ", "))


    # NYC stop_id values have a base ID along with two repeated versions with either
    # "N" or "S" appended. These latter are redundant. First reduce the "stops"
    # table:
    remove_terminal_sn <- function (stop_ids)
    {
        last_char <- substr (stop_ids, nchar (stop_ids), nchar (stop_ids))
        index <- which (last_char == "N" | last_char == "S")
        if (length (index) > 0) # nocov start
            stop_ids [index] <- substr (stop_ids [index], 1,
                                        nchar (stop_ids [index]) - 1)
        # nocov end
        return (stop_ids)
    }
    stop_ids <- remove_terminal_sn (stops [, stop_id])
    index <- which (!duplicated (stop_ids))
    stops <- stops [index, ]
    stop_times [, stop_id := remove_terminal_sn (stop_times [, stop_id])]

    stop_times [, arrival_time := rcpp_time_to_seconds (arrival_time)]
    stop_times [, departure_time := rcpp_time_to_seconds (departure_time)]
    stop_times [, trip_id := paste0 (trip_id)]

    if (!missing_transfers)
    {
        transfer = stop_times [, stop_id] %in% transfers [, from_stop_id]
        #stop_times <- stop_times [, transfer := transfer] [order (departure_time)]
        stop_times <- stop_times [, transfer := transfer]

        index <- which (transfers [, from_stop_id] %in% stop_times [, stop_id] &
                        transfers [, to_stop_id] %in% stop_times [, stop_id])
        transfers <- transfers [index, ]
        transfers [, min_transfer_time := replace (min_transfer_time,
                                                   is.na (min_transfer_time), 0)]
    }

    trips <- trips [, trip_id := paste0 (trip_id)]

    objs <- gsub (".txt", "", basename (flist$Name))
    # Note: **NOT** lapply (objs, get)!!
    # https://stackoverflow.com/questions/18064602/why-do-i-need-to-wrap-get-in-a-dummy-function-within-a-j-lapply-call
    res <- lapply (objs, function (i) get (i))
    names (res) <- objs
    attr (res, "filtered") <- FALSE

    class (res) <- c ("gtfs", class (res))

    return (res)
}


type_missing <- function (flist, type)
{
    ret <- FALSE
    type <- paste0 (type, ".txt")
    
    if (!any (grepl (type, flist$Name)))
    {
        warning (paste ("This feed contains no", type), call. = FALSE)
        ret <- TRUE
    }

    return (ret)
}
