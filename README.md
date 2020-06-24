[![R build
status](https://github.com/atfutures/gtfs-router/workflows/R-CMD-check/badge.svg)](https://github.com/atfutures/gtfs-router/actions?query=workflow%3AR-CMD-check)
[![Build
Status](https://travis-ci.org/ATFutures/gtfs-router.svg)](https://travis-ci.org/ATFutures/gtfs-router)
[![codecov](https://codecov.io/gh/ATFutures/gtfs-router/branch/master/graph/badge.svg)](https://codecov.io/gh/ATFutures/gtfs-router)
[![Project Status:
Active](http://www.repostatus.org/badges/latest/active.svg)](http://www.repostatus.org/#active)
[![CRAN\_Status\_Badge](http://www.r-pkg.org/badges/version/gtfsrouter)](https://cran.r-project.org/package=gtfsrouter)
[![CRAN
Downloads](http://cranlogs.r-pkg.org/badges/grand-total/gtfsrouter?color=orange)](https://cran.r-project.org/package=gtfsrouter)

# GTFS Router

**R** package for routing with [GTFS (General Transit Feed
Specification)](https://developers.google.com/transit/gtfs/) data. See
[the website](https://atfutures.github.io/gtfs-router/) for full
details.

## Installation

To install:

``` r
remotes::install_github("atfutures/gtfs-router")
```

To load the package and check the version:

``` r
library(gtfsrouter)
packageVersion("gtfsrouter")
```

    ## [1] '0.0.1.3'

## Main functions

The main functions can be demonstrated with sample data included with
the package from Berlin (the Verkehrverbund Berlin Brandenburg, or VBB).
GTFS data are always stored as `.zip` files, and these sample data can
be written to local storage with the function `berlin_gtfs_to_zip()`.

``` r
berlin_gtfs_to_zip()
tempfiles <- list.files (tempdir (), full.names = TRUE)
filename <- tempfiles [grep ("vbb.zip", tempfiles)]
filename
```

    ## [1] "/tmp/RtmpDvCd60/vbb.zip"

For normal package use, `filename` will specify the name of the local
GTFS data stored as a single `.zip` file.

### gtfs\_route

Given the name of a GTFS `.zip` file, `filename`, routing is as simple
as the following code:

``` r
gtfs <- extract_gtfs (filename)
gtfs <- gtfs_timetable (gtfs) # A pre-processing step to speed up queries
gtfs_route (gtfs,
            from = "Schonlein",
            to = "Berlin Hauptbahnhof",
            start_time = 12 * 3600 + 120) # 12:02 in seconds
```

| route\_name | trip\_name       | stop\_name                      | arrival\_time | departure\_time |
| :---------- | :--------------- | :------------------------------ | :------------ | :-------------- |
| U8          | U Paracelsus-Bad | U Schonleinstr. (Berlin)        | 12:04:00      | 12:04:00        |
| U8          | U Paracelsus-Bad | U Kottbusser Tor (Berlin)       | 12:06:00      | 12:06:00        |
| U8          | U Paracelsus-Bad | U Moritzplatz (Berlin)          | 12:08:00      | 12:08:00        |
| U8          | U Paracelsus-Bad | U Heinrich-Heine-Str. (Berlin)  | 12:09:30      | 12:09:30        |
| U8          | U Paracelsus-Bad | S+U Jannowitzbrucke (Berlin)    | 12:10:30      | 12:10:30        |
| S5          | S Westkreuz      | S+U Jannowitzbrucke (Berlin)    | 12:15:24      | 12:15:54        |
| S5          | S Westkreuz      | S+U Alexanderplatz Bhf (Berlin) | 12:17:24      | 12:18:12        |
| S5          | S Westkreuz      | S Hackescher Markt (Berlin)     | 12:19:24      | 12:19:54        |
| S5          | S Westkreuz      | S+U Friedrichstr. Bhf (Berlin)  | 12:21:24      | 12:22:12        |
| S5          | S Westkreuz      | S+U Berlin Hauptbahnhof         | 12:24:06      | 12:24:42        |

### gtfs\_isochrone

Isochrones from a nominated station - lines delineating the range
reachable within a given time - can be extracted with the
`gtfs_isochrone()` function, which returns a list of all stations
reachable within the specified time period from the nominated station.

``` r
gtfs <- extract_gtfs (filename)
gtfs <- gtfs_timetable (gtfs) # A pre-processing step to speed up queries
x <- gtfs_isochrone (gtfs,
                     from = "Schonlein",
                     start_time = 12 * 3600 + 120,
                     end_time = 12 * 3600 + 720) # 10 minutes later
```

The function returns an object of class `gtfs_isochrone` containing
[`sf`](https://github.com/r-spatial/sf)-formatted sets of start and end
points, along with all intermediate (“mid”) points, and routes. An
additional item contains the non-convex (alpha) hull enclosing the
routed points. This requires the packages
[`geodist`](https://github.com/hypertidy/geodist),
[`sf`](https://cran.r-project.org/package=sf),
[`alphahull`](https://cran.r-project.org/package=alphahull), and
[`mapview`](https://cran.r-project.org/package=mapview) to be installed.
Isochrone objects have their own plot method:

``` r
plot (x)
```

![](./vignettes/isochrone.png)

The isochrone hull also quantifies its total area and width-to-length
ratio.

## Additional Functionality

There are many ways to construct GTFS feeds. For background information,
see [`gtfs.org`](http://gtfs.org), and particularly their [GTFS
Examples](https://docs.google.com/document/d/16inL5BVcM1aU-_DcFJay_tC6Ni0wPa0nvQEstueG5k4/edit).

Feeds may include a “frequencies.txt” table which defines “service
periods”, and overrides any schedule information during the specified
times. The `gtfsrouter` package includes a function,
[`frequencies_to_stop_times()`](https://atfutures.github.io/gtfs-router/reference/frequencies_to_stop_times.html),
to convert “frequencies.txt” tables to equivalent “stop\_times.txt”
entries, to enable the feed to be used for routine.

Feeds may also omit a “transfers.txt” table which otherwise defines
transfer abilities and times between different services. Feeds without
this table can generally not be used for routing, and they exclude the
possibility of transferring between multiple services. The `gtfsrouter`
package also includes a function,
[`gtfs_transfer_table()`](https://atfutures.github.io/gtfs-router/reference/gtfs_transfer_table.html),
which can calculate a transfer table for a given feed, with transfer
times calculated either using straight-line distances (the default), or
using more realistic times routed through the underlying street network.
