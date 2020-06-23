#' go_home
#'
#' Use local environmental variables specifying home and work stations and
#' locations of locally-stored GTFS data to route from work to home locationn
#' with next available service.
#'
#' @param wait An integer specifying the n-th next service. That is, `wait = n`
#' will return the n-th available service after the next immediate service.
#' @param start_time If given, search for connections after specified time; if
#' not given, search for connections from current time.
#'
#' @details This function, and the complementary function \link{go_to_work},
#' requires three local environmental variables specifying the names of home and
#' work stations, and the location on local storage of the GTFS data set to be
#' used for routing. These are respectively called `gtfs_home`, `gtfs_work`, and
#' `gtfs_data`. This data set must also be pre-processed using the
#' \link{process_gtfs_local} function.
#'
#' See \link{Startup} for details on how to set environmental variables.
#' Briefly, this can be done in two main ways: By setting them at the start of
#' each session, in which case the variables may be set with:
#' `Sys.setenv ("gtfs_home" = "<my home station>")`
#' `Sys.setenv ("gtfs_work" = "<my work station>")`
#' `Sys.setenv ("gtfs_data" = "/full/path/to/gtfs.zip")`
#' Alternatively, to set these automatically for each session, paste those lines
#' into the file `~/.Renviron` - that is, a file named ".Renviron" in the user's
#' home directory.
#'
#' The \link{process_gtfs_local} function reduces the GTFS data set to the
#' minimal possible size necessary for local routing.  GTFS data are
#' nevertheless typically quite large, and both the \link{go_home} and
#' \link{go_to_work} functions may take some time to execute. Most of this time
#' is devoted to loading the data in to the current workspace and as such is
#' largely unavoidable.
#'
#' @return A `data.frame` specifying the next available route from work to home.
#' @examples
#' \dontrun{
#' # For general use, please set these three variables:
#' Sys.setenv ("gtfs_home" = "<my home station>")
#' Sys.setenv ("gtfs_work" = "<my work station>")
#' Sys.setenv ("gtfs_data" = "/full/path/to/gtfs.zip")
#' }
#' # The following illustrate use with sample data bundled with package
#' Sys.setenv ("gtfs_home" = "Tempelhof")
#' Sys.setenv ("gtfs_work" = "Alexanderplatz")
#' Sys.setenv ("gtfs_data" = file.path (tempdir (), "vbb.zip"))
#' process_gtfs_local () # If not already done
#' go_home (start_time = "12:00") # next available service after 12:00
#' go_home (3, start_time = "12:00") # Wait until third service after that
#' # Generally, `start_time` will not be specified, in which case `go_home` will
#' # return next available service from current system time, so calls will
#' # generally be as simple as:
#' \dontrun{
#' go_home ()
#' go_home (3)
#' }
#' @export
go_home <- function (wait = 0, start_time)
{
    go_home_work (home = TRUE, wait = wait, start_time)
}

#' go_to_work
#'
#' Use local environmental variables specifying home and work stations and
#' locations of locally-stored GTFS data to route from home to work location
#' with next available service.
#'
#' @inherit go_home return params
#' @inherit go_home return details
#'
#' @return A `data.frame` specifying the next available route from work to home.
#' @examples
#' \dontrun{
#' # For general use, please set these three variables:
#' Sys.setenv ("gtfs_home" = "<my home station>")
#' Sys.setenv ("gtfs_work" = "<my work station>")
#' Sys.setenv ("gtfs_data" = "/full/path/to/gtfs.zip")
#' }
#' # The following illustrate use with sample data bundled with package
#' Sys.setenv ("gtfs_home" = "Tempelhof")
#' Sys.setenv ("gtfs_work" = "Alexanderplatz")
#' Sys.setenv ("gtfs_data" = file.path (tempdir (), "vbb.zip"))
#' process_gtfs_local () # If not already done
#' go_to_work (start_time = "12:00") # next available service after 12:00
#' go_to_work (3, start_time = "12:00") # Wait until third service after that
#' # Generally, `start_time` will not be specified, in which case `go_to_work`
#' # will return next available service from current system time, so calls will
#' # generally be as simple as:
#' \dontrun{
#' go_to_work ()
#' go_to_work (3)
#' }
#' @export
go_to_work <- function (wait = 0, start_time)
{
    go_home_work (home = FALSE, wait = wait, start_time)
}

go_home_work <- function (home = TRUE, wait, start_time)
{
    vars <- get_envvars ()
    fname <- get_rds_name (vars$file)
    if (!file.exists (fname))
        stop ("This function requires the GTFS data to be pre-processed ",
              "with 'process_gtfs_local'.")

    gtfs <- readRDS (fname)
    suppressMessages (gtfs <- gtfs_timetable (gtfs))
    if (home)
    {
        from <- vars$work
        to <- vars$home
    } else
    {
        from <- vars$home
        to <- vars$work
    }
    if (missing (start_time))
        start_time <- NULL # nocov
    res <- gtfs_route (gtfs, from = from, to = to, start_time = start_time)
    if (wait > 0)
    {
        for (i in seq (wait))
        {
            depart <- convert_time (res$departure_time [1]) + 1
            res <- gtfs_route (gtfs, from = from, to = to, start_time = depart)
        }
    }
    return (res)
}

get_envvars <- function ()
{
    if (Sys.getenv ("gtfs_home") == "" |
        Sys.getenv ("gtfs_work") == "" |
        Sys.getenv ("gtfs_data") == "")
        stop ("This function requires environmental variables gtfs_home, ",
              "gtfs_work, and gtfs_data; see ?go_home for details.")

    f <- (Sys.getenv ("gtfs_data"))
    if (!file.exists (f))
        stop ("File ", f, " specified by environmental variable ",
              "'gtfs_data' does not exist")

    list (home = Sys.getenv ("gtfs_home"),
          work = Sys.getenv ("gtfs_work"),
          file = Sys.getenv ("gtfs_data"))
}

get_rds_name <- function (f)
{
    paste0 (tools::file_path_sans_ext (f), ".Rds")
}

#' process_gtfs_local
#'
#' Process a local GTFS data set with environmental variables described in
#' \link{go_home} into a condensed version for use in \link{go_home} and
#' `go_to_work` functions.
#'
#' @param expand The data set is reduced to the bounding box defined by the
#' home and work stations, expanded by this multiple. If the function appears to
#' behave strangely, try re-running this function with a higher value of this
#' parameter.
#'
#' @export
process_gtfs_local <- function (expand = 2)
{
    vars <- get_envvars ()

    gtfs <- extract_gtfs (vars$file, quiet = TRUE)
    gtfs$agency <- NULL
    gtfs$calendar_dates <- NULL
    gtfs$shapes <- NULL

    gtfs <- reduce_to_local_stops (gtfs, expand = expand)

    gtfs$routes <- gtfs$routes [, c ("route_id", "route_short_name")]
    gtfs$stops <- gtfs$stops [, c ("stop_id", "stop_name")]
    gtfs$transfers <- gtfs$transfers [, c ("from_stop_id", "to_stop_id",
                                           "min_transfer_time")]
    gtfs$trips <- gtfs$trips [, c ("route_id", "service_id", "trip_id",
                                   "trip_headsign")]

    fname <- get_rds_name (vars$file)
    saveRDS (gtfs, fname)
}

reduce_to_local_stops <- function (gtfs, expand = 2)
{
    # remove no visible binding notes:
    stop_name <- stop_lon <- stop_lat <- from_stop_id <- to_stop_id <-
        stop_id <- trip_id <- NULL

    vars <- get_envvars ()
    xy <- rbind (gtfs$stops [grep (vars$home, gtfs$stops [, stop_name]),
                             c ("stop_lon", "stop_lat")],
                 gtfs$stops [grep (vars$work, gtfs$stops [, stop_name]),
                             c ("stop_lon", "stop_lat")])
    bb <- apply (xy, 2, range)
    bb <- apply (bb, 2, function (i) mean (i) + c (-expand, expand) * diff (i))
    xlim <- bb [, 1]
    ylim <- bb [, 2]

    index <- which (gtfs$stops [, stop_lon] > xlim [1] &
                    gtfs$stops [, stop_lon] < xlim [2] &
                    gtfs$stops [, stop_lat] > ylim [1] &
                    gtfs$stops [, stop_lat] < ylim [2])
    stop_ids <- gtfs$stops [index, stop_id]

    # reduce stops
    gtfs$stops <- gtfs$stops [index, ]

    # reduce stop_times
    index <- which (gtfs$stop_times [, stop_id] %in% stop_ids)
    gtfs$stop_times <- gtfs$stop_times [index, ]

    # reduce transfers
    index <- which (gtfs$transfers [, from_stop_id] %in% stop_ids |
                    gtfs$transfers [, to_stop_id] %in% stop_ids)
    gtfs$transfers <- gtfs$transfers [index, ]

    # get reduced trip_ids from stop_times
    trip_ids <- unique (gtfs$stop_times [, trip_id])
    gtfs$trips <- gtfs$trips [which (gtfs$trips [, trip_id] %in% trip_ids), ]

    return (gtfs)
}
