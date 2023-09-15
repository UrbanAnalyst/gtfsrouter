#' summary.gtfs
#'
#' @name summary.gtfs
#' @param object A `gtfs` object to be summarised
#' @param ... ignored here
#' @return Nothing; this function only prints a summary to the console.
#'
#' @family additional
#' @examples
#' # Examples must be run on single thread only:
#' nthr <- data.table::setDTthreads (1)
#'
#' berlin_gtfs_to_zip ()
#' f <- file.path (tempdir (), "vbb.zip")
#' g <- extract_gtfs (f)
#' summary (g)
#' g <- gtfs_timetable (g)
#' summary (g) # also summarizes additional timetable information
#'
#' data.table::setDTthreads (nthr)
#' @export
summary.gtfs <- function (object, ...) {
    msg <- "A gtfs "
    if (attr (object, "filtered")) {
        msg <- paste0 (msg, "timetable ")
    }
    message (
        msg, "object with the following tables and ",
        "respective numbers of entries in each:"
    )
    print (vapply (object, nrow, numeric (1)))
    if (!"transfers" %in% names (object)) {
        message ("Note: This feed contains no transfers.txt table")
    }
    if (!"calendar" %in% names (object)) {
        message ("Note: This feed contains no calendar.txt table")
    }
}
