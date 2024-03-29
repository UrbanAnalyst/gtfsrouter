% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/methods.R
\name{summary.gtfs}
\alias{summary.gtfs}
\title{summary.gtfs}
\usage{
\method{summary}{gtfs}(object, ...)
}
\arguments{
\item{object}{A \code{gtfs} object to be summarised}

\item{...}{ignored here}
}
\value{
Nothing; this function only prints a summary to the console.
}
\description{
summary.gtfs
}
\examples{
# Examples must be run on single thread only:
nthr <- data.table::setDTthreads (1)

berlin_gtfs_to_zip ()
f <- file.path (tempdir (), "vbb.zip")
g <- extract_gtfs (f)
summary (g)
g <- gtfs_timetable (g)
summary (g) # also summarizes additional timetable information

data.table::setDTthreads (nthr)
}
\seealso{
Other additional: 
\code{\link{go_home}()},
\code{\link{go_to_work}()},
\code{\link{process_gtfs_local}()}
}
\concept{additional}
