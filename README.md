[![Build
Status](https://travis-ci.org/ATFutures/gtfs-router.svg)](https://travis-ci.org/ATFutures/gtfs-router)
[![AppVeyor Build
Status](https://ci.appveyor.com/api/projects/status/github/ATFutures/gtfs-router?branch=master&svg=true)](https://ci.appveyor.com/project/ATFutures/gtfs-router)
[![codecov](https://codecov.io/gh/ATFutures/gtfs-router/branch/master/graph/badge.svg)](https://codecov.io/gh/ATFutures/gtfs-router)
[![Project Status:
WIP](https://www.repostatus.org/badges/latest/wip.svg)](https://www.repostatus.org/#wip)

# GTFS Router

**R** package for routing with [GTFS (General Transit Feed
Specification)](https://developers.google.com/transit/gtfs/) data.

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

    ## [1] '0.0.1'

## Main functions

The main functions can be demonstrated with sample data from Berlin (the
Verkehrverbund Berlin Brandenburg, or VBB), included with the package.
GTFS data are always stored as `.zip` files, and these sample data can
be written to local storage with the function `berlin_gtfs_to_zip()`.

``` r
berlin_gtfs_to_zip()
tempfiles <- list.files (tempdir (), full.names = TRUE)
filename <- tempfiles [grep ("vbb.zip", tempfiles)]
filename
```

    ## [1] "/tmp/Rtmp7UDP4d/vbb.zip"

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

| route | stop                            | departure\_time | arrival\_time |
| :---- | :------------------------------ | :-------------- | :------------ |
| U8    | U Schonleinstr. (Berlin)        | 12:04:00        | 12:04:00      |
| U8    | U Kottbusser Tor (Berlin)       | 12:06:00        | 12:06:00      |
| U8    | U Moritzplatz (Berlin)          | 12:08:00        | 12:08:00      |
| U8    | U Heinrich-Heine-Str. (Berlin)  | 12:09:30        | 12:09:30      |
| U8    | S+U Jannowitzbrucke (Berlin)    | 12:10:30        | 12:10:30      |
| S5    | S+U Jannowitzbrucke (Berlin)    | 12:15:54        | 12:15:24      |
| S5    | S+U Alexanderplatz Bhf (Berlin) | 12:18:12        | 12:17:24      |
| S5    | S Hackescher Markt (Berlin)     | 12:19:54        | 12:19:24      |
| S5    | S+U Friedrichstr. Bhf (Berlin)  | 12:22:12        | 12:21:24      |
| S5    | S+U Berlin Hauptbahnhof         | 12:24:42        | 12:24:06      |

A routing query on a very large network (the GTFS data are MB) takes
only around 0.05 seconds.

### gtfs\_isochrone

Isochrones from a nominated station can be extracted with the
`gtfs_isochrone()` function, returning a list of all stations reachable
within a specified time period from that station.

``` r
gtfs <- extract_gtfs (filename)
gtfs <- gtfs_timetable (gtfs) # A pre-processing step to speed up queries
x <- gtfs_isochrone (gtfs,
                     from = "Schonlein",
                     start_time = 12 * 3600 + 120,
                     end_time = 12 * 3600 + 720) # 10 minutes later
head(x)
```

|   | stop\_name                     | stop\_lon | stop\_lat | in\_isochrone |
| - | :----------------------------- | --------: | --------: | :------------ |
| 1 | U Rathaus Neukolln (Berlin)    |  13.43481 |  52.48115 | TRUE          |
| 2 | U Kottbusser Tor (Berlin)      |  13.41775 |  52.49905 | TRUE          |
| 3 | U Gorlitzer Bahnhof (Berlin)   |  13.42847 |  52.49903 | TRUE          |
| 5 | U Lipschitzallee (Berlin)      |  13.46311 |  52.42464 | TRUE          |
| 6 | U Franz-Neumann-Platz (Berlin) |  13.36428 |  52.56385 | TRUE          |
| 7 | U Leinestr. (Berlin)           |  13.42840 |  52.47287 | TRUE          |

The function returns a `data.frame` of all stations, with `in_isochrone
= TRUE` for those reachable from the nominated station within the
nominated time. The results of `gtfs_isochrone` can also be plotted as
an interactive web map, simply by `plot(x)`. This requires the packages
[`sf`](https:cran.r-project.org/package=sf),
[`alphahull`](https:cran.r-project.org/package=alphahull), and
[`mapview`](https:cran.r-project.org/package=mapview) to be installed.

## GTFS Structure

For background information, see [`gtfs.org`](http://gtfs.org), and
particularly their [GTFS
Examples](https://docs.google.com/document/d/16inL5BVcM1aU-_DcFJay_tC6Ni0wPa0nvQEstueG5k4/edit).
The VBB is strictly schedule-only, so has no `"frequencies.txt"` file
(this file defines “service periods”, and overrides any schedule
information during the specified times).
