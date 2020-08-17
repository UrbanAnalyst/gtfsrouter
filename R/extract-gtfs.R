#' extract_gtfs
#'
#' Extract data from a GTFS `zip` archive.
#'
#' @param filename Name of GTFS archive
#' @param quiet If `FALSE`, display progress information on screen
#' @param stn_suffixes Any values provided will be removed from terminal
#' characters of station IDs. Useful for feeds like NYC for which some stations
#' are appended with values of "N" and "S" to indicate directions. Specifying
#' `stn_suffixes = c ("N", "S")` will automatically remove these suffixes.
#' @return List of several \pkg{data.table} objects corresponding to the tables
#' present in the nominated GTFS data set.
#' @importFrom data.table :=
#'
#' @examples
#' berlin_gtfs_to_zip () # Write sample feed from Berlin, Germany to tempdir
#' f <- file.path (tempdir (), "vbb.zip") # name of feed
#' gtfs <- extract_gtfs (f)
#'
#' @export
extract_gtfs <- function (filename = NULL, quiet = FALSE, stn_suffixes = NULL)
{
    if (is.null (filename))
        stop ("filename must be given")
    if (!file.exists (filename))
        stop ("filename ", filename, " does not exist")
    if (!(is.null (stn_suffixes) | is.character (stn_suffixes)))
        stop ("stn_suffixes must be a character vector")

    # suppress no visible binding for global variables notes:
    arrival_time <- departure_time <- stop_id <- min_transfer_time <-
        from_stop_id <- to_stop_id <- trip_id <- `:=` <- # nolint
        routes <- stops <- stop_times <- trips <- NULL

    #flist <- utils::unzip (filename, list = TRUE)
    # the fread(cmd = paste0 ("unzip -p ..")) stuff is not portable, and has
    # issues on windows, so unzip all into tempdir and work from there

    if (!quiet)
        message (cli::symbol$play, cli::col_green (" Unzipping GTFS archive"),
                 appendLF = FALSE)
    flist <- utils::unzip (filename, exdir = tempdir ())
    if (!quiet)
        message ("\r", cli::col_green (cli::symbol$tick,
                                       " Unzipped GTFS archive  "))

    # GTFS **must** contain "agency", "stops", "routes", "trips", and
    # "stop_times", but "agency" is not used here, so
    need_these_files <- c ("routes", "stops", "stop_times", "trips")
    checks <- vapply (need_these_files, function (i)
                      any (grepl (paste0 (i, ".txt"), flist)), logical (1))
    if (!all (checks))
        stop (filename, " does not appear to be a GTFS file; ",
              "it must minimally contain\n  ",
              paste (need_these_files, collapse = ", "))
    missing_transfers <- type_missing (flist, "transfers")

    if (!quiet)
        message (cli::symbol$play, cli::col_green (" Extracting GTFS feed"),
                 appendLF = FALSE)
    for (f in seq (flist))
    {
        fout <- data.table::fread (flist [f],
                                   integer64 = "character",
                                   showProgress = FALSE)
        assign (gsub (".txt", "", basename (flist [f])), fout, pos = -1)
        chk <- file.remove (flist [f])

    }
    if (!quiet)
        message ("\r", cli::col_green (cli::symbol$tick, " Extracted GTFS feed "))

    if (nrow (routes) == 0 | nrow (stops) == 0 | nrow (stop_times) == 0 |
        nrow (trips) == 0)
        stop (filename, " does not appear to be a GTFS file; ",
              "it must minimally contain\n  ",
              paste (need_these_files, collapse = ", "))


    # NYC stop_id values have a base ID along with two repeated versions with
    # either "N" or "S" appended. These latter are redundant. First reduce the
    # "stops" table:
    remove_terminal_sn <- function (stop_ids, stn_suffixes)
    {
        if (!is.null (stn_suffixes)) {
            for (i in stn_suffixes) {
                index <- grep (paste0 (i, "$"), stop_ids)
                if (length (index) > 0)
                    stop_ids [index] <- gsub (paste0 (i, "$"), "", stop_ids [index])
            }
        }
        # nocov end
        return (stop_ids)
    }
    if (storage.mode(stops$stop_id) != "character") {
        stops$stop_id <- as.character(stops$stop_id)
    }
    
    stops [, stop_id := remove_terminal_sn (stops [, stop_id], stn_suffixes)]

    index <- which (!duplicated (stops [, stop_id]))
    stops <- stops [index, ]
    stop_times [, stop_id := remove_terminal_sn (stop_times [, stop_id],
                                                 stn_suffixes)]

    if (!quiet)
        message (cli::symbol$play,
                 cli::col_green (" Converting stop times to seconds"),
                 appendLF = FALSE)

    stop_times [, arrival_time := rcpp_time_to_seconds (arrival_time)]
    stop_times [, departure_time := rcpp_time_to_seconds (departure_time)]
    stop_times [, trip_id := paste0 (trip_id)]

    if (!quiet) {
        message ("\r", cli::col_green (cli::symbol$tick,
                                       " Converted stop times to seconds "))
        message (cli::symbol$play,
                 cli::col_green (" Converting transfer times to seconds"),
                 appendLF = FALSE)
    }

    if (!missing_transfers)
    {
        transfer <- stop_times [, stop_id] %in% transfers [, from_stop_id]
        #stop_times <-
        #stop_times [, transfer := transfer] [order (departure_time)]
        stop_times <- stop_times [, transfer := transfer]

        index <- which (transfers [, from_stop_id] %in% stop_times [, stop_id] &
                        transfers [, to_stop_id] %in% stop_times [, stop_id])
        transfers <- transfers [index, ]
        transfers [, min_transfer_time :=
                   replace (min_transfer_time, is.na (min_transfer_time), 0)]
    }
    if (!quiet)
        message ("\r", cli::col_green (cli::symbol$tick,
                                       " Converted transfer times to seconds "))

    trips <- trips [, trip_id := paste0 (trip_id)]

    objs <- gsub (".txt", "", basename (flist))
    # Note: **NOT** lapply (objs, get)!!
    # https://stackoverflow.com/questions/18064602/why-do-i-need-to-wrap-get-in-a-dummy-function-within-a-j-lapply-call #nolint
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

    if (!any (grepl (type, flist)))
    {
        msg <- paste ("This feed contains no", type)
        if (type == "transfers.txt")
            msg <- paste (msg,
                          "\n  A transfers.txt table may be constructed",
                          "with the 'gtfs_transfer_table' function")
        warning (msg, call. = FALSE)
        ret <- TRUE
    }

    return (ret)
}
