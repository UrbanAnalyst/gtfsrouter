% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/go_home_work.R
\name{process_gtfs_local}
\alias{process_gtfs_local}
\title{process_gtfs_local}
\usage{
process_gtfs_local(expand = 2)
}
\arguments{
\item{expand}{The data set is reduced to the bounding box defined by the
home and work stations, expanded by this multiple. If the function appears to
behave strangely, try re-running this function with a higher value of this
parameter.}
}
\value{
No return value. The function saves processed data to a local cache.
}
\description{
Process a local GTFS data set with environmental variables described in
\link{go_home} into a condensed version for use in \link{go_home} and
\code{go_to_work} functions.
}
\seealso{
Other additional: 
\code{\link{go_home}()},
\code{\link{go_to_work}()},
\code{\link{summary.gtfs}()}
}
\concept{additional}
