#' berlin_gtfs_to_zip
#'
#' Write a zip archive of the internal package data, \link{berlin_gtfs} to
#' a file named "vbb.zip" to `tempdir()`.
#'
#' @return Nothing
#' @export
berlin_gtfs_to_zip <- function ()
{
    flist <- c ("calendar.txt", "routes.txt", "trips.txt",
                "stop_times.txt", "stops.txt", "transfers.txt")
    f <- gtfsrouter::berlin_gtfs
    chk <- sapply (flist, function (i)
                   data.table::fwrite (f [[strsplit (i, ".txt") [[1]] ]],
                                       file.path (tempdir (), i), quote = TRUE)
    )
    flist <- file.path (tempdir (), flist)
    utils::zip (file.path (tempdir (), "vbb.zip"), files = flist, flags = "-q")
    invisible (file.remove (flist))
}

convert_time <- function (my_time)
{
    if (methods::is (my_time, "difftime") || methods::is (my_time, "Period"))
    {
        my_time <- rcpp_convert_time (paste0 (my_time))
    } else if (is.character (my_time))
    {
        my_time <- rcpp_convert_time (my_time)
    } else if (is.numeric (my_time))
    {
        if (length (my_time) == 1)
        {
            # do nothing; presume to be seconds, not hours
        } else if (length (my_time) == 2)
            my_time <- 3600 * my_time [1] + 60 * my_time [2]
        else if (length (my_time) == 3)
            my_time <- 3600 * my_time [1] + 60 * my_time [2] + my_time [3]
        else
            stop ("Don't know how to parse time vectors of length ",
                  length (my_time))
    } else
        stop ("Time is of unknown class") # nocov - TODO: Cover that

    return (my_time)
}

# convert timevec in seconds into hh:mm:ss - functionality of hms::hms without
# dependency
format_time <- function (timevec)
{
    hh <- floor (timevec / 3600)
    timevec <- timevec - hh * 3600
    mm <- floor (timevec / 60)
    ss <- round (timevec - mm * 60)

    paste0 (zero_pad (hh), ":", zero_pad (mm), ":", zero_pad (ss))
}

zero_pad <- function (x)
{
    x <- paste0 (x)
    x [nchar (x) < 2] <- paste0 (0, x [nchar (x) < 2])
    return (x)
}

force_char <- function (x)
{
    if (!is.character (x))
        x <- paste0 (x) # nocov - not in test data
    return (x)
}
