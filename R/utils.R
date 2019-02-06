#' berlin_gtfs_to_zip
#'
#' Write a zip archive of the internal package data, \link{berlin_gtfs} to
#' a file named "vbb.zip" to `tempdir()`.
#'
#' @return Nothing
#' @export
berlin_gtfs_to_zip <- function ()
{
    flist <- c ("routes.txt", "trips.txt", "stop_times.txt",
                "stops.txt", "transfers.txt")
    f <- gtfsrouter::berlin_gtfs
    chk <- sapply (flist, function (i)
                   data.table::fwrite (f [[strsplit (i, ".txt") [[1]] ]],
                                       file.path (tempdir (), i), quote = TRUE)
    )
    flist <- file.path (tempdir (), flist)
    utils::zip (file.path (tempdir (), "vbb.zip"), files = flist)
    invisible (file.remove (flist))
}
