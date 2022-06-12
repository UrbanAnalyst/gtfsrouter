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
#' @note Column types in each table of the returned object conform to GTFS
#' standards (\url{https://developers.google.com/transit/gtfs/reference}),
#' except that "Time" fields in the "stop_times" table are converted to integer
#' values, rather than as character or "Time" objects ("HH:MM:SS"). These can be
#' converted back to comply with GTFS standards by applying the `hms::hms()`
#' function to the two time columns of the "stop_times" table.
#'
#' @examples
#' berlin_gtfs_to_zip () # Write sample feed from Berlin, Germany to tempdir
#' f <- file.path (tempdir (), "vbb.zip") # name of feed
#' gtfs <- extract_gtfs (f)
#'
#' @family extract
#' @export
extract_gtfs <- function (filename = NULL, quiet = FALSE, stn_suffixes = NULL) {

    check_extract_pars (filename, stn_suffixes)

    # suppress no visible binding for global variables notes:
    trip_id <- min_transfer_time <- NULL

    flist <- unzip_gtfs (filename, quiet = quiet)

    # GTFS **must** contain "agency", "stops", "routes", "trips", and
    # "stop_times", but "agency" is not used here, so
    need_these_files <- c ("routes", "stops", "stop_times", "trips")
    all_files_exist (filename, flist, need_these_files)

    missing_transfers <- type_missing (flist, "transfers")

    e <- extract_objs_into_env (flist, quiet = quiet)

    if (nrow (e$routes) == 0 | nrow (e$stops) == 0 |
        nrow (e$stop_times) == 0 | nrow (e$trips) == 0) {
        stop (
            filename, " does not appear to be a GTFS file; ",
            "it must minimally contain\n  ",
            paste (need_these_files, collapse = ", ")
        )
    }

    e$stops <- convert_stops (e$stops, stn_suffixes)

    e$stop_times <- convert_stop_times (e$stop_times, stn_suffixes, quiet)

    if (!missing_transfers) {
        e$transfers <- convert_transfers (
            e$transfers, e$stop_times,
            min_transfer_time, quiet
        )
    }

    e$trips <- e$trips [, trip_id := paste0 (trip_id)]

    objs <- gsub (".txt", "", basename (flist))

    res <- lapply (objs, function (i) get (i, envir = e))
    names (res) <- objs
    attr (res, "filtered") <- FALSE

    class (res) <- c ("gtfs", class (res))

    return (res)
}

unzip_gtfs <- function (filename, quiet = FALSE) {

    # flist <- utils::unzip (filename, list = TRUE)
    # the fread(cmd = paste0 ("unzip -p ..")) stuff is not portable, and has
    # issues on windows, so unzip all into tempdir and work from there

    if (!quiet) {
        message (cli::symbol$play, cli::col_green (" Unzipping GTFS archive"),
            appendLF = FALSE
        )
    }

    flist <- utils::unzip (filename, exdir = tempdir ())

    if (!quiet) {
        message ("\r", cli::col_green (
            cli::symbol$tick,
            " Unzipped GTFS archive  "
        ))
    }

    return (flist)
}

check_extract_pars <- function (filename, stn_suffixes) {

    if (is.null (filename)) {
        stop ("filename must be given")
    }
    if (!file.exists (filename)) {
        stop ("filename ", filename, " does not exist")
    }
    if (!(is.null (stn_suffixes) | is.character (stn_suffixes))) {
        stop ("stn_suffixes must be a character vector")
    }

}

all_files_exist <- function (filename, flist, need_these_files) {

    checks <- vapply (need_these_files, function (i) {
        any (grepl (paste0 (i, ".txt"), flist))
    }, logical (1))

    if (!all (checks)) {
        stop (
            filename, " does not appear to be a GTFS file; ",
            "it must minimally contain\n  ",
            paste (need_these_files, collapse = ", ")
        )
    }
}

type_missing <- function (flist, type) {
    ret <- FALSE
    type <- paste0 (type, ".txt")

    if (!any (grepl (type, flist))) {
        msg <- paste ("This feed contains no", type)
        if (type == "transfers.txt") {
            msg <- paste (
                msg,
                "\n  A transfers.txt table may be constructed",
                "with the 'gtfs_transfer_table' function"
            )
        }
        warning (msg, call. = FALSE)
        ret <- TRUE
    }

    return (ret)
}

extract_objs_into_env <- function (flist, quiet = FALSE) {

    if (!quiet) {
        message (cli::symbol$play, cli::col_green (" Extracting GTFS feed"),
            appendLF = FALSE
        )
    }

    # Get types of all fields according to standards, via fns defined in
    # gtfs-reference-fields.R (see #74)
    fields <- gtfs_reference_fields ()
    types <- gtfs_reference_types ()
    fields <- lapply (fields, function (i) {
        n <- names (i)
        these_types <- do.call (rbind, i) [, 1]
        ret <- types [match (these_types, names (types))]
        names (ret) <- n
        return (ret)  })

    e <- new.env ()
    for (f in seq (flist)) {

        # Get the column types for that file:
        fname <- tools::file_path_sans_ext (basename (flist [f]))
        these_fields <- fields [[fname]]
        fhdr <- data.table::fread (flist [f],
            integer64 = "character",
            nrows = 1
        )
        classes <- these_fields [which (names (these_fields) %in% names (fhdr))]

        fout <- data.table::fread (flist [f],
            integer64 = "character",
            showProgress = FALSE,
            colClasses = classes
        )

        assign (gsub (".txt", "", basename (flist [f])),
            value = fout,
            envir = e
        )
        chk <- file.remove (flist [f]) # nolint
    }

    if (!quiet) {
        message ("\r", cli::col_green (
            cli::symbol$tick,
            " Extracted GTFS feed "
        ))
    }

    return (e)
}

# NYC stop_id values have a base ID along with two repeated versions with
# either "N" or "S" appended. These latter are redundant. First reduce the
# "stops" table:
remove_terminal_sn <- function (stop_ids, stn_suffixes) {
    if (!is.null (stn_suffixes)) {
        for (i in stn_suffixes) {
            index <- grep (paste0 (i, "$"), stop_ids)
            if (length (index) > 0) {
                stop_ids [index] <-
                    gsub (paste0 (i, "$"), "", stop_ids [index])
            }
        }
    }
    # nocov end
    return (stop_ids)
}

#' rectify_col_names
#'
#' Some column names have stray characters (like the Stuttgart feed via #70), so
#' can not be retrieved using `data.table` syntax, because, for example,
#' names (stop_times) [grep ("trip_id", names (stop_times))] == "trip_id"
#' is FALSE. This function rectifies all column names submitted to data.table
#' operations to expected values.
#' @noRd
rectify_col_names <- function (tab, col_name) {
    names (tab) [grep (col_name, names (tab))] <- col_name
    return (tab)
}

convert_stops <- function (stops, stn_suffixes) {
    # suppress no visible binding notes:
    stop_id <- NULL

    stops <- rectify_col_names (stops, "stop_id")

    if (storage.mode (stops$stop_id) != "character") {
        stops$stop_id <- as.character (stops$stop_id)
    }

    stops [, stop_id := remove_terminal_sn (stops [, stop_id], stn_suffixes)]

    index <- which (!duplicated (stops [, stop_id]))
    stops <- stops [index, ]

    return (stops)
}

convert_stop_times <- function (stop_times, stn_suffixes, quiet) {

    # suppress no visible binding notes:
    arrival_time <- departure_time <- trip_id <- stop_id <- NULL

    stop_times <- rectify_col_names (stop_times, "stop_id")
    stop_times <- rectify_col_names (stop_times, "arrival_time")
    stop_times <- rectify_col_names (stop_times, "departure_time")
    stop_times <- rectify_col_names (stop_times, "trip_id")

    stop_times [, stop_id := remove_terminal_sn (
        stop_times [, stop_id],
        stn_suffixes
    )]

    if (!quiet) {
        message (cli::symbol$play,
            cli::col_green (" Converting stop times to seconds"),
            appendLF = FALSE
        )
    }

    stop_times [, arrival_time := rcpp_time_to_seconds (arrival_time)]
    stop_times [, departure_time := rcpp_time_to_seconds (departure_time)]
    stop_times [, trip_id := paste0 (trip_id)]

    if (!quiet) {
        message ("\r", cli::col_green (
            cli::symbol$tick,
            " Converted stop times to seconds "
        ))
    }

    return (stop_times)
}

convert_transfers <- function (transfers,
                               stop_times,
                               min_transfer_time,
                               quiet) {

    # suppress no visible binding notes:
    stop_id <- from_stop_id <- to_stop_id <- NULL

    if (!quiet) {
        message (cli::symbol$play,
            cli::col_green (" Converting transfer times to seconds"),
            appendLF = FALSE
        )
    }

    transfer <- stop_times [, stop_id] %in% transfers [, from_stop_id]
    # stop_times <-
    # stop_times [, transfer := transfer] [order (departure_time)]
    stop_times <- stop_times [, transfer := transfer]

    index <- which (transfers [, from_stop_id] %in% stop_times [, stop_id] &
        transfers [, to_stop_id] %in% stop_times [, stop_id])
    transfers <- transfers [index, ]
    transfers [, min_transfer_time :=
        replace (min_transfer_time, is.na (min_transfer_time), 0)]

    if (!quiet) {
        message ("\r", cli::col_green (
            cli::symbol$tick,
            " Converted transfer times to seconds "
        ))
    }

    return (transfers)
}
