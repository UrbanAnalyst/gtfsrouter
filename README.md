[![Build
Status](https://travis-ci.org/ATFutures/gtfs-router.svg)](https://travis-ci.org/ATFutures/gtfs-router)
[![AppVeyor Build
Status](https://ci.appveyor.com/api/projects/status/github/ATFutures/gtfs-router?branch=master&svg=true)](https://ci.appveyor.com/project/ATFutures/gtfs-router)
[![codecov](https://codecov.io/gh/ATFutures/gtfs-router/branch/master/graph/badge.svg)](https://codecov.io/gh/ATFutures/gtfs-router)
[![Project Status:
WIP](https://www.repostatus.org/badges/latest/wip.svg)](https://www.repostatus.org/#wip)

# GTFS Router

**R** package for routing with [GTFS (General Transit Feed
Specification)](https://developers.google.com/transit/gtfs/) data. Among
the additional aims of this repo are to quantify the dynamic stability
of a GTFS network in time and space, and to identify “weakest nodes” as
those where a temporal disruption propogates out to have the greatest
effect throughout the broader network.

Test data will be the VBB (Verkehrsverbund Berlin-Brandenburg) GTFS feed
available
[here](https://daten.berlin.de/datensaetze/vbb-fahrplandaten-gtfs), with
the results providing useful input data for
[`flux.fail`](https://flux.fail).

## Example

Download the VBB data from the above link in a local directory, load the
package:

``` r
library (gtfsrouter)
```

Then:

``` r
gtfs <- extract_gtfs (list.files () [grep ("VBB", list.files ())])
gtfs <- gtfs_timetable (gtfs) # A pre-processing step to speed up queries
st <- system.time (
             r <- gtfs_route (gtfs,
                              from = "Schönlein",
                              to = "Berlin Hauptbahnhof",
                              start_time = 14 * 3600) # 14:00 in seconds
)
st
```

    ##    user  system elapsed 
    ##   1.431   0.016   0.252

``` r
knitr::kable (r)
```

| route | stop                            | departure\_time | arrival\_time |
| :---- | :------------------------------ | :-------------- | :------------ |
| U8    | U Schönleinstr. (Berlin)        | 14:04:00        | 14:04:00      |
| U8    | U Kottbusser Tor (Berlin)       | 14:06:00        | 14:06:00      |
| U8    | U Moritzplatz (Berlin)          | 14:08:00        | 14:08:00      |
| U8    | U Heinrich-Heine-Str. (Berlin)  | 14:09:30        | 14:09:30      |
| U8    | S+U Jannowitzbrücke (Berlin)    | 14:10:30        | 14:10:30      |
| S5    | S+U Jannowitzbrücke (Berlin)    | 14:15:54        | 14:15:24      |
| S5    | S+U Alexanderplatz Bhf (Berlin) | 14:18:12        | 14:17:24      |
| S5    | S Hackescher Markt (Berlin)     | 14:19:54        | 14:19:24      |
| S5    | S+U Friedrichstr. Bhf (Berlin)  | 14:22:12        | 14:21:24      |
| S5    | S+U Berlin Hauptbahnhof         | 14:24:42        | 14:24:06      |

And a routing query on a very large network (the GTFS data are 64 MB)
takes only 0.25 seconds.

## GTFS Structure

For background information, see [`gtfs.org`](http://gtfs.org), and
particularly their [GTFS
Examples](https://docs.google.com/document/d/16inL5BVcM1aU-_DcFJay_tC6Ni0wPa0nvQEstueG5k4/edit).
The VBB is strictly schedule-only, so has no `"frequencies.txt"` file
(this file defines “service periods”, and overrides any schedule
information during the specified times).
