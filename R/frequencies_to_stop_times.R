#' frequencies_to_stop_times
#'
#' Convert a GTFS 'frequencies' table to equivalent 'stop_times' that can be
#' used for routing.
#'
#' @param gtfs A set of GTFS data returned from \link{extract_gtfs}.
#'
#' @return The input GTFS data with data from the 'frequencies' table converted
#' to equivalent 'arrival_time' and 'departure_time' values in `stop_times`.
#'
#' @importFrom data.table shift
#'
#' @family augment
#' @export
frequencies_to_stop_times <- function (gtfs) {

    # check if gtfs is a gtfs class of object
    if (class (gtfs) [1] != "gtfs") {
        stop ("selected object does not appear to be a GTFS file")
    }

    # test if gtfs contains no empty `frequencies`
    if (!("frequencies" %in% names (gtfs))) {
        stop ("selected gtfs does not contain frequencies")
    }
    if (nrow (gtfs$frequencies) == 0) {
        stop ("frequencies table is empty")
    }

    # frequencies must contain required columns:
    # "trip_id" ,"start_time","end_time","headway_secs"
    need_these_columns <- c (
        "trip_id",
        "start_time",
        "end_time",
        "headway_secs"
    )
    checks <- vapply (need_these_columns, function (i) {
        any (grepl (i, names (gtfs$frequencies)))
    }, logical (1))

    if (!all (checks)) {
        stop (
            "frequencies must contain all required columns:\n  ",
            paste (need_these_columns, collapse = ", ")
        )
    }


    # IMPORTANT: data.table works entirely by reference, so all operations
    # change original values unless first copied! This function thus returns a
    # copy even when it does nothing else, so always entails some cost.
    gtfs_cp <- data.table::copy (gtfs)

    gtfs_cp$frequencies [, start_time := rcpp_time_to_seconds (start_time)]
    gtfs_cp$frequencies [, end_time := rcpp_time_to_seconds (end_time)]

    gtfs_cp$stop_times$timepoint <- 1L
    freq_trips <- unique (gtfs_cp$frequencies$trip_id)
    gtfs_cp$stop_times$timepoint [which (gtfs_cp$stop_times$trip_id %in% freq_trips)] <- 0L

    f_stop_times <- gtfs_cp$stop_times [gtfs_cp$stop_times$timepoint == 0L, ]
    gtfs_cp$stop_times <- gtfs_cp$stop_times [gtfs_cp$stop_times$timepoint == 1L, ]

    freqs <- gtfs_cp$frequencies
    if (any (duplicated (freqs$trip_id))) {
        stop ("frequencies table has duplicated 'trip_id' values", call. = FALSE)
    }

    # convert f_stop_times to list:
    f_stop_times <- split (f_stop_times, f = as.factor (f_stop_times$trip_id))
    index <- match (freqs$trip_id, names (f_stop_times))
    f_stop_times <- f_stop_times [index]

    # then get final number of trips to be made:
    n <- ceiling ((freqs$end_time - freqs$start_time) / freqs$headway_secs)
    n <- sum (n)

    res <- rcpp_freq_to_stop_times (freqs, f_stop_times, n)
    res <- do.call (rbind, res)

    # The Rcpp fn only returns a subset of the main columns; any additional ones
    # in original stop_times table are then removed:
    index <- which (names (gtfs_cp$stop_times) %in% names (res))
    gtfs_cp$stop_times <- rbind (gtfs_cp$stop_times [, ..index], res)

    return (gtfs_cp)
}
