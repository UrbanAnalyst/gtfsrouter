#' summary.gtfs
#'
#' @name summary.gtfs
#' @param object A `gtfs` object to be summarised
#' @param ... ignored here
#'
#' @examples
#' berlin_gtfs_to_zip ()
#' f <- file.path (tempdir (), "vbb.zip")
#' g <- extract_gtfs (f)
#' summary (g)
#' g <- gtfs_timetable (g)
#' summary (g) # also summarizes additional timetable information
#' @export
summary.gtfs <- function (object, ...)
{
    msg <- "A gtfs "
    if (attr (object, "filtered"))
        msg <- paste0 (msg, "timetable ")
    message (msg, "object with the following tables and ",
             "respective numbers of entries in each:")
    print (vapply (object, nrow, numeric (1)))
    if (!"transfers" %in% names (object))
        message ("Note: This feed contains no transfers.txt table")
    if (!"calendar" %in% names (object))
        message ("Note: This feed contains no calendar.txt table")
}

#' plot.gtfs_isochrone
#'
#' @name plot.gtfs_ischrone
#' @param x object to be plotted
#' @param ... ignored here
#' @export
plot.gtfs_isochrone <- function (x, ...)
{
    requireNamespace ("sf")
    requireNamespace ("alphahull")
    requireNamespace ("mapview")

    allpts <- rbind (x$start_pt, x$mid_points, x$end_points)

    m <- mapview::mapview (allpts, color = "grey", cex = 3, legend = FALSE)
    m <- leafem::addFeatures (m, x$hull, color = "orange", alpha.regions = 0.2)
    m <- leafem::addFeatures (m, x$routes, colour = "blue")
    m <- leafem::addFeatures (m, x$start_point, radius = 5, color = "green")
    m <- leafem::addFeatures (m, x$end_points, radius = 4, color = "red",
                               fill = TRUE, fillOpacity = 0.8,
                               fillColor = "red")

    print (m)
    invisible (m)
}
