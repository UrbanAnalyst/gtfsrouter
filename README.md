[![Build
Status](https://travis-ci.org/ATFutures/gtfs-router.svg)](https://travis-ci.org/ATFutures/gtfs-router)
[![AppVeyor Build
Status](https://ci.appveyor.com/api/projects/status/github/ATFutures/gtfs-router?branch=master&svg=true)](https://ci.appveyor.com/project/ATFutures/gtfs-router)
[![codecov](https://codecov.io/gh/ATFutures/gtfs-router/branch/master/graph/badge.svg)](https://codecov.io/gh/ATFutures/gtfs-router)
[![Project Status:
WIP](https://www.repostatus.org/badges/latest/wip.svg)](https://www.repostatus.org/#wip)

# GTFS Router

**R** package for routing and analysis with [GTFS (General Transit Feed
Specification)](https://developers.google.com/transit/gtfs/) data. See
[the website](https://atfutures.github.io/gtfs-router/) for full
details.

## Installation

To install:

``` r
remotes::install_github("atfutures/gtfs-router")
```

    ##   
    ─  installing *source* package ‘gtfsrouter’ ...
    ## 
      
       ** libs
    ## 
      
       make[1]: Entering directory '/data/mega/code/repos/atfutures/gtfs-router/src'
    ## 
      
       make[1]: Leaving directory '/data/mega/code/repos/atfutures/gtfs-router/src'
    ## 
      
       make[1]: Entering directory '/data/mega/code/repos/atfutures/gtfs-router/src'
    ##    ccache clang++ -std=gnu++11 -I"/usr/include/R/" -DNDEBUG  -I"/usr/lib/R/library/Rcpp/include" -D_FORTIFY_SOURCE=2   -fpic  -O -Wall -pedantic -c RcppExports.cpp -o RcppExports.o
    ## 
      
       ccache clang++ -std=gnu++11 -I"/usr/include/R/" -DNDEBUG  -I"/usr/lib/R/library/Rcpp/include" -D_FORTIFY_SOURCE=2   -fpic  -O -Wall -pedantic -c convert-time.cpp -o convert-time.o
    ## 
      
       ccache clang++ -std=gnu++11 -I"/usr/include/R/" -DNDEBUG  -I"/usr/lib/R/library/Rcpp/include" -D_FORTIFY_SOURCE=2   -fpic  -O -Wall -pedantic -c csa-isochrone.cpp -o csa-isochrone.o
    ## 
      
       ccache clang++ -std=gnu++11 -I"/usr/include/R/" -DNDEBUG  -I"/usr/lib/R/library/Rcpp/include" -D_FORTIFY_SOURCE=2   -fpic  -O -Wall -pedantic -c csa-median-timetable.cpp -o csa-median-timetable.o
    ## 
      
       ccache clang++ -std=gnu++11 -I"/usr/include/R/" -DNDEBUG  -I"/usr/lib/R/library/Rcpp/include" -D_FORTIFY_SOURCE=2   -fpic  -O -Wall -pedantic -c csa-timetable.cpp -o csa-timetable.o
    ## 
      
       ccache clang++ -std=gnu++11 -I"/usr/include/R/" -DNDEBUG  -I"/usr/lib/R/library/Rcpp/include" -D_FORTIFY_SOURCE=2   -fpic  -O -Wall -pedantic -c csa.cpp -o csa.o
    ## 
      
       ccache clang++ -std=gnu++11 -I"/usr/include/R/" -DNDEBUG  -I"/usr/lib/R/library/Rcpp/include" -D_FORTIFY_SOURCE=2   -fpic  -O -Wall -pedantic -c dijkstra.cpp -o dijkstra.o
    ## 
      
       ccache clang++ -std=gnu++11 -I"/usr/include/R/" -DNDEBUG  -I"/usr/lib/R/library/Rcpp/include" -D_FORTIFY_SOURCE=2   -fpic  -O -Wall -pedantic -c graph.cpp -o graph.o
    ## 
      
       ccache clang++ -std=gnu++11 -shared -L/usr/lib64/R/lib -Wl,-O1,--sort-common,--as-needed,-z,relro,-z,now -o gtfsrouter.so RcppExports.o convert-time.o csa-isochrone.o csa-median-timetable.o csa-timetable.o csa.o dijkstra.o graph.o -L/usr/lib64/R/lib -lR
    ## 
      
       make[1]: Leaving directory '/data/mega/code/repos/atfutures/gtfs-router/src'
    ## 
      
       installing to /tmp/RtmphAgm8o/devtools_install_7feb157a603d/gtfsrouter/libs
    ## 
      
    ─  DONE (gtfsrouter)
    ## 

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

    ## [1] "/tmp/RtmphAgm8o/vbb.zip"

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

| route\_name | trip\_name       | stop\_name                      | departure\_time | arrival\_time |
| :---------- | :--------------- | :------------------------------ | :-------------- | :------------ |
| U8          | U Paracelsus-Bad | U Schonleinstr. (Berlin)        | 12:04:00        | 12:04:00      |
| U8          | U Paracelsus-Bad | U Kottbusser Tor (Berlin)       | 12:06:00        | 12:06:00      |
| U8          | U Paracelsus-Bad | U Moritzplatz (Berlin)          | 12:08:00        | 12:08:00      |
| U8          | U Paracelsus-Bad | U Heinrich-Heine-Str. (Berlin)  | 12:09:30        | 12:09:30      |
| U8          | U Paracelsus-Bad | S+U Jannowitzbrucke (Berlin)    | 12:10:30        | 12:10:30      |
| S5          | S Westkreuz      | S+U Jannowitzbrucke (Berlin)    | 12:15:54        | 12:15:24      |
| S5          | S Westkreuz      | S+U Alexanderplatz Bhf (Berlin) | 12:18:12        | 12:17:24      |
| S5          | S Westkreuz      | S Hackescher Markt (Berlin)     | 12:19:54        | 12:19:24      |
| S5          | S Westkreuz      | S+U Friedrichstr. Bhf (Berlin)  | 12:22:12        | 12:21:24      |
| S5          | S Westkreuz      | S+U Berlin Hauptbahnhof         | 12:24:42        | 12:24:06      |

### gtfs\_isochrone

Isochrones from a nominated station - lines delineating the range
reachable within a given time - can be extracted with the
`gtfs_isochrone()` function, which returns a list of all stations
reachable within the specified time period from the nominated station
station.

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

![](./fig/isochrone.png)

The isochrone hull also quantifies its total area and width-to-length
ratio.

## GTFS Structure

For background information, see [`gtfs.org`](http://gtfs.org), and
particularly their [GTFS
Examples](https://docs.google.com/document/d/16inL5BVcM1aU-_DcFJay_tC6Ni0wPa0nvQEstueG5k4/edit).
The VBB is strictly schedule-only, so has no `"frequencies.txt"` file
(this file defines “service periods”, and overrides any schedule
information during the specified times).
