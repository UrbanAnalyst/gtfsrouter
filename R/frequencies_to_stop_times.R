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
#' @importFrom data.table shift .SD
#'
#' @family augment
#' @export
#'
#' @examples
#' \dontrun{
#' # Presume an input feed has been created and includes a "frequencies" table:
#' gtfs2 <- frequencies_to_stop_times (gtfs)
#' # "gtfs2" will then have an expanded "stop_times" table, with all
#' # "frequencies" entries converted to equivalent absolute stop times.
#' }
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

    # Suppress no visible binding notes:
    start_time <- end_time <- NULL
    gtfs_cp$frequencies [, start_time := rcpp_time_to_seconds (start_time)]
    gtfs_cp$frequencies [, end_time := rcpp_time_to_seconds (end_time)]

    gtfs_cp$stop_times$timepoint <- 1L
    freq_trips <- unique (gtfs_cp$frequencies$trip_id)
    index <- which (gtfs_cp$stop_times$trip_id %in% freq_trips)
    gtfs_cp$stop_times$timepoint [index] <- 0L

    f_stop_times <- gtfs_cp$stop_times [gtfs_cp$stop_times$timepoint == 0L, ]
    gtfs_cp$stop_times <-
        gtfs_cp$stop_times [gtfs_cp$stop_times$timepoint == 1L, ]

    freqs <- gtfs_cp$frequencies
    sfx <- trip_id_suffix (freqs)

    freqs <- calc_num_new_timetables (freqs)

    # plus total numbers of timetable entries:
    trip_id_table <- table (f_stop_times$trip_id)
    index <- match (freqs$trip_id, names (trip_id_table))
    freqs$num_tt_entries <- trip_id_table [index]

    num_tt_entries_exp <- sum (freqs$num_tt_entries * freqs$nseq)

    res <- rcpp_freq_to_stop_times (
        freqs,
        f_stop_times,
        num_tt_entries_exp,
        sfx
    )

    # The Rcpp fn only returns a subset of the main columns; any additional ones
    # in original stop_times table are then removed:
    index <- which (names (gtfs_cp$stop_times) %in% names (res))

    # '.SD' = data.table's "Subset of Data.table" syntax
    # https://rdatatable.gitlab.io/data.table/articles/datatable-faq.html
    # under "how-can-i-avoid-writing-a-really-long-j-expression"
    gtfs_cp$stop_times <- rbind (gtfs_cp$stop_times [, .SD, .SDcols = index], res)

    gtfs_cp <- update_trips_table_with_freqs (gtfs_cp, sfx)

    attr (gtfs_cp, "freq_sfx") <- sfx

    return (gtfs_cp)
}

#' Get unambiguous 'trip_id' suffix
#'
#' Original 'trip_id' values can then be easily recovered by removing these
#' suffixes.
#' @param freqs frequencies table including 'trip_id' column
#' @noRd
trip_id_suffix <- function (freqs) {

    sfx <- "\\_f[0-9]+$"
    while (any (grepl (sfx, freqs$trip_id))) {
        sfx <- gsub ("\\_f", "\\_ff", sfx)
    }
    nf <- length (gregexpr ("f", sfx) [[1]])
    sfx <- paste0 ("_", paste0 (rep ("f", nf), collapse = ""))

    return (sfx)
}

#' Get final number of new timetables and actual timetable entries to be
#' constructed.
#' @param freqs frequencies table
#' @noRd
calc_num_new_timetables <- function (freqs) {

    index_non <- which (!duplicated (freqs$trip_id))
    freqs$nseq <- NA_integer_
    freqs$nseq [index_non] <- ceiling ((freqs$end_time - freqs$start_time) /
        freqs$headway_secs) [index_non]
    index_dupl <- which (duplicated (freqs$trip_id))
    if (length (index_dupl) > 0L) {
        # same trip_ids, different headway values. construct sequences of trips
        # spanning headway changes
        index_dupl <- which (freqs$trip_id %in% freqs$trip_id [index_dupl])
        freqs_dupl <- split (
            freqs [index_dupl, ],
            f = as.factor (freqs$trip_id [index_dupl])
        )
        n_seqs <- lapply (freqs_dupl, function (i) {
            nseq <- (i$end_time - i$start_time) / i$headway_secs
            out <- data.frame (
                trip_id = i$trip_id,
                start_time = i$start_time,
                end_time = i$end_time,
                headway_secs = i$headway_secs,
                nseq,
                end_time_actual = i$start_time + nseq * i$headway_secs
            )
            index <- which (out$end_time_actual > out$end_time)
            out$nseq [index] <- out$nseq [index] - 1
            out$end_time_actual [index] <- out$end_time_actual [index] -
                out$headway_secs [index]

            return (out)
        })
        freqs_dupl <- do.call (rbind, n_seqs)
        freqs$nseq [index_dupl] <-
            ceiling ((freqs_dupl$end_time - freqs_dupl$start_time) /
                freqs_dupl$headway_secs)
    }

    return (freqs)
}

#' Expand each row of "trips" table to corresponding number of new trips with
#' frequency table extensions of `sfx` + increasing numbers.
#' @noRd
update_trips_table_with_freqs <- function (gtfs, sfx) {

    trip_ids <- unique (gtfs$stop_times$trip_id)
    trip_ids_with_sfx <- grep (paste0 (sfx, "[0-9]*$"), trip_ids, value = TRUE)

    # Current ids in freqs table:
    freqs_trips <- gsub (paste0 (sfx, "[0-9]*$"), "", trip_ids_with_sfx)
    freqs_trips_tab <- table (freqs_trips)
    freqs_trips <- names (freqs_trips_tab)
    # `freqs_trips` are then the names of the original `trips$trip_id` trips,
    # with `freqs_trips_tab` tallying how many times each are repeated in
    # translating the frequencies table.

    index <- which (gtfs$trips$trip_id %in% freqs_trips)
    if (length (index) == 0) {
        return (gtfs)
    }

    trips_no_freqs <- gtfs$trips [seq_len (nrow (gtfs$trips)) [-index], ]
    trips_freqs <- gtfs$trips [index, ]

    freqs_trips <- freqs_trips [which (freqs_trips %in% trips_freqs$trip_id)]
    index <- which (names (freqs_trips_tab) %in% trips_freqs$trip_id)
    freqs_trips_tab <- freqs_trips_tab [index]

    # The `trips_freqs` table then has one row for each original trip, with
    # `trip_id` not containing the `sfx` version for frequency table entries.
    # Each row needs to be expanded to the corresponding number of
    # frequency-table trips.
    freqs_trips_tab <-
        freqs_trips_tab [match (trips_freqs$trip_id, freqs_trips)]
    index <- rep (seq_len (nrow (trips_freqs)), times = freqs_trips_tab)
    trips_freqs_exp <- trips_freqs [index, ]
    trips_freqs_exp$trip_id <- trip_ids_with_sfx

    gtfs$trips <- rbind (trips_no_freqs, trips_freqs_exp)

    return (gtfs)
}
