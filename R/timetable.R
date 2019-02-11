#' gtfs_timetable
#'
#' Convert GTFS data into format able to be used to calculate routes.
#'
#' @param gtfs A set of GTFS data returned from \link{extract_gtfs}.
#' @return The input data with an addition items, `timetable`, `stations`, and
#' `trips`, containing data formatted for more efficient use with
#' \link{gtfs_route} (see Note).
#'
#' @note This function is merely provided to speed up calls to the primary
#' function, \link{gtfs_route}. If the input data to that function do not
#' include a formatted `timetable`, it will be calculated anyway, but queries in
#' that case will generally take longer.
#'
#' @export
gtfs_timetable <- function (gtfs)
{
    # no visible binding notes
    from_stop_id <- to_stop_id <- stop_id <- NULL

    # IMPORTANT: data.table works entirely by reference, so all operations
    # change original values unless first copied! This function thus returns a
    # copy even when it does nothing else, so always entails some cost.
    gtfs_cp <- data.table::copy (gtfs)
    if (!"timetable" %in% names (gtfs))
    {
        tt <- rcpp_make_timetable (gtfs_cp$stop_times)
        # tt$timetable has [departure/arrival_station, departure/arrival_time,
        # trip_id], where the station and trip values are 0-based indices into the
        # vectors of tt$stop_ids and tt$trips.

        # translate transfer stations into indices, converting back to 0-based to
        # match the indices of tt$timetable
        index <- match (gtfs_cp$transfers [, from_stop_id], tt$stations) - 1
        gtfs_cp$transfers <- gtfs_cp$transfers [, from_stop_id := index]
        index <- match (gtfs_cp$transfers [, to_stop_id], tt$stations) - 1
        gtfs_cp$transfers <- gtfs_cp$transfers [, to_stop_id := index]

        # Then convert all output to data.table just for print formatting:
        gtfs_cp$timetable <- data.table::data.table (tt$timetable)
        gtfs_cp$stations <- data.table::data.table (stations = tt$stations)
        gtfs_cp$trips <- data.table::data.table (trips = tt$trips)
        # add a couple of extra pre-processing items, with 1 added to numbers here
        # because indices are 0-based:
        gtfs_cp$stop_ids <- data.table::data.table (
                                stop_id = unique (gtfs_cp$stop_times [, stop_id]))
        gtfs_cp$n_stations <- max (unique (c (gtfs_cp$timetable$departure_station,
                                           gtfs_cp$timetable$arrival_station))) + 1
        gtfs_cp$n_trips <- max (gtfs_cp$timetable$trip_id) + 1

        # And order the timetable by departure_time
        gtfs_cp$timetable <- gtfs_cp$timetable [order (gtfs_cp$timetable$departure_time), ]
    }

    return (gtfs_cp)
}

