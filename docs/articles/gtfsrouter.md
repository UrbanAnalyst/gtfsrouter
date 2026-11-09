# gtfsrouter

## 1 Background: GTFS and other R packages

GTFS - General Transit Feed Specification - began life in 2005 as the
“Google Transit Feed Specification,” and was renamed to “General” in
2009. It provides a standardised scheme for representing data on public
transport services, routes, frequencies, and timetables. A GTFS data set
consists of several comma-delimited (`.csv`) files detailing routes,
stops, trips, transfers, and other aspects, all bundled in a single
`.zip`-compressed archive file. For full details, see the relevant
[google developer site](https://developers.google.com/transit/gtfs/).

There are currently two other **R** packages which handle GTFS data:

1.  [`gtfsr`](https://github.com/ropensci-archive/gtfsr), hosted by
    [rOpenSci](https://ropensci.org), developed by [Danton
    Noriega](https://github.com/dantonnoriega), but no longer under
    active development.
2.  [`tidytransit`](https://github.com/r-transit/tidytransit), which
    began as a fork of
    [`gtfsr`](https://github.com/ropensci-archive/gtfsr), and currently
    represents its successor. This package can be used to, “map transit
    stops and routes, calculate transit frequencies, and validate
    transit feeds \[as well as to read\] the General Transit Feed
    Specification into tidyverse and simple features dataframes.”

The one thing neither of these packages enable is the use of GTFS data
for transit routing. The `gtfsrouter` package enables both one-to-one
and one-to-many routing. Functionality is demonstrated here through the
sample data set included with the package, provided by the
“Verkehrsverbund Berlin-Brandenburg” (VBB; or Transport Network
Berlin-Brandenburg). The `berlin_gtfs` data represents a reduced version
of the full GTFS data, containing only six tables, and a timetable
reduced to the single hour between 12:00-13:00. Like all GTFS software
including [`tidytransit`](https://github.com/r-transit/tidytransit),
this package is designed to work directly with GTFS data in
`.zip`-archived format, and so includes a helper function,
[`berlin_gtfs_to_zip()`](https://UrbanAnalyst.github.io/gtfsrouter/reference/berlin_gtfs_to_zip.md),
which exports the internal data set to a locally-stored `.zip` archive
in the [`tempdir()`](https://rdrr.io/r/base/tempfile.html) of the
current **R** session. These data can be exported and re-imported with:

``` r

berlin_gtfs_to_zip ()
```

    ## /tmp/RtmpqyKEmk/vbb.zip

``` r

f <- file.path (tempdir (), "vbb.zip")
file.exists (f)
```

    ## [1] TRUE

``` r

gtfs <- extract_gtfs (f)
```

    ## ▶ Unzipping GTFS archive✔ Unzipped GTFS archive  
    ## ▶ Extracting GTFS feed✔ Extracted GTFS feed 
    ## ▶ Converting stop times to seconds✔ Converted stop times to seconds 
    ## ▶ Converting transfer times to seconds✔ Converted transfer times to seconds 

That simply re-creates the original package data, `berlin_gtfs`
(although the extracted data differ through having a couple of
additional attributes defining it as a `gtfs` object).

## 2. Routing

The primary routing function is
[`gtfs_route()`](https://UrbanAnalyst.github.io/gtfsrouter/reference/gtfs_route.md),
the example of which uses the `gtfs` data for the VBB created as
described above. In simplest form, routing requires a start and end
point, defaulting to the current time as desired start time, and routing
for the current day of the week.

``` r

from <- "Innsbrucker Platz"
to <- "Alexanderplatz"
gtfs_route (
    gtfs,
    from = from,
    to = to
)
```

    ## Day not specified; extracting timetable for monday

| route_name | trip_name | stop_name | arrival_time | departure_time |
|:---|:---|:---|:---|:---|
| S42 | S Sudkreuz Bhf | S+U Innsbrucker Platz (Berlin) | 12:06:42 | 12:07:12 |
| S42 | S Sudkreuz Bhf | S Schoneberg (Berlin) | 12:08:18 | 12:08:48 |
| S42 | S Sudkreuz Bhf | S Sudkreuz Bhf (Berlin) | 12:10:12 | 12:10:12 |
| S2 | S Buch | S Sudkreuz Bhf (Berlin) | 12:16:18 | 12:16:54 |
| S2 | S Buch | S+U Yorckstr. S2 S25 S26 U7 (Berlin) | 12:19:00 | 12:19:30 |
| S2 | S Buch | S Anhalter Bahnhof (Berlin) | 12:21:42 | 12:22:12 |
| S2 | S Buch | S+U Potsdamer Platz Bhf (Berlin) | 12:23:48 | 12:24:18 |
| S2 | S Buch | S+U Brandenburger Tor (Berlin) | 12:25:54 | 12:26:24 |
| S2 | S Buch | S+U Friedrichstr. Bhf (Berlin) | 12:27:36 | 12:28:24 |
| S5 | S Hoppegarten | S+U Friedrichstr. Bhf (Berlin) | 12:33:06 | 12:33:54 |
| S5 | S Hoppegarten | S Hackescher Markt (Berlin) | 12:35:24 | 12:35:54 |
| S5 | S Hoppegarten | S+U Alexanderplatz Bhf (Berlin) | 12:37:06 | 12:37:54 |

Both the start time and day of the week can be explicitly specified:

``` r

route <- gtfs_route (
    gtfs,
    from = from,
    to = to,
    start_time = "12:00:00",
    day = "Sunday"
)
```

### 2.1 GTFS Timetables

The `gtfsrouter` package uses the [Connection Scan
Algorithm](https://arxiv.org/abs/1703.05997), which requires converting
the “stop_times” table to a column-wise timetable. The “stop_times”
table has row-wise entries for each distinct “trip_id”, with consecutive
rows for a given value of “trip_id” holding sequential values for stops
and associated times (and potentially additional variables). In
contrast, the timetables processed by this package have separate columns
for departure and arrival stations and times. All routing queries
pre-process the original GTFS data with the
[`gtfs_timetable()`](https://UrbanAnalyst.github.io/gtfsrouter/reference/gtfs_timetable.md)
function, which appends this timetable data, along with two
single-column tables of stop and trip ID values. (The timetable itself
contains strictly integer values for stops and trips, which are indices
into these latter tables.)

The only important point of that from a user’s perspective is that
routing queries will be faster if this pre-processing step is explicitly
implemented with
[`gtfs_timetable()`](https://UrbanAnalyst.github.io/gtfsrouter/reference/gtfs_timetable.md)
prior to calling
[`gtfs_route()`](https://UrbanAnalyst.github.io/gtfsrouter/reference/gtfs_route.md).
This is easy to demonstrate using the sample data:

``` r

gtfs <- extract_gtfs (f)
```

    ## ▶ Unzipping GTFS archive✔ Unzipped GTFS archive  
    ## ▶ Extracting GTFS feed✔ Extracted GTFS feed 
    ## ▶ Converting stop times to seconds✔ Converted stop times to seconds 
    ## ▶ Converting transfer times to seconds✔ Converted transfer times to seconds 

``` r

from <- "Innsbrucker Platz"
to <- "Alexanderplatz"
system.time (
    gtfs_route (
        gtfs,
        from = from,
        to = to,
        start_time = "12:00:00",
        day = "Sunday"
    )
)
```

    ##    user  system elapsed 
    ##   0.032   0.000   0.031

``` r

names (gtfs)
```

    ## [1] "calendar"   "routes"     "trips"      "stop_times" "stops"     
    ## [6] "transfers"

``` r

# explicit pre-processing to extract timetable for Sunday
gtfs <- gtfs_timetable (gtfs,
    day = "Sunday"
)
names (gtfs)
```

    ## [1] "calendar"   "routes"     "trips"      "stop_times" "stops"     
    ## [6] "transfers"  "timetable"  "stop_ids"   "trip_ids"

``` r

system.time (gtfs_route (
    gtfs,
    from = from,
    to = to,
    start_time = "12:00:00"
))
```

    ##    user  system elapsed 
    ##   0.024   0.000   0.024

Note that the `day` parameter is used to extract the timetable, after
which it is no longer required in the actual call to
[`gtfs_route()`](https://UrbanAnalyst.github.io/gtfsrouter/reference/gtfs_route.md).

### 2.2. Routing by mode of transport

It is also possible to filter by desired mode of transport. This is done
by matching the pattern to those given in the `route_short_name` column
of the `gtfs$route` table:

``` r

head (gtfs$route)
```

| route_id | agency_id | route_short_name | route_long_name | route_type | route_color | route_text_color | route_desc |
|:---|:---|:---|:---|---:|:---|:---|:---|
| 10141_109 | 1 | S1 |  | 109 | E64DFF | FFFFFF |  |
| 10142_109 | 1 | S1 |  | 109 | E64DFF | FFFFFF |  |
| 10143_109 | 1 | S2 |  | 109 | 00B300 | FFFFFF |  |
| 10144_109 | 1 | S2 |  | 109 | 00B300 | FFFFFF |  |
| 10145_109 | 1 | S25 |  | 109 |  |  |  |
| 10148_109 | 1 | S3 |  | 109 |  |  |  |

These short names will differ for each GTFS, with the two primary train
systems in Berlin being the underground trains denoted “U” (although not
always travelling underground), and street-level trains denoted “S”. The
default route from Innsbrucker Platz to Alexanderplatz above was via two
“U” services. We can also specify that we’d prefer to travel by “S”
services, noting that the `route_pattern = "S"` specifies a
`route_short_name` that *starts with* (`"^"`) “S”:

``` r

gtfs_route (
    gtfs,
    from = from,
    to = to,
    start_time = "12:00:00",
    day = "Sunday",
    route_pattern = "^S"
)
```

| route_name | trip_name | stop_name | arrival_time | departure_time |
|:---|:---|:---|:---|:---|
| S42 | S Sudkreuz Bhf | S+U Innsbrucker Platz (Berlin) | 12:06:42 | 12:07:12 |
| S42 | S Sudkreuz Bhf | S Schoneberg (Berlin) | 12:08:18 | 12:08:48 |
| S42 | S Sudkreuz Bhf | S Sudkreuz Bhf (Berlin) | 12:10:54 | 12:10:54 |
| S42 | S Sudkreuz Bhf | S+U Tempelhof (Berlin) | 12:12:54 | 12:13:24 |
| S42 | S Sudkreuz Bhf | S+U Hermannstr. (Berlin) | 12:16:42 | 12:17:12 |
| S42 | S Sudkreuz Bhf | S+U Neukolln (Berlin) | 12:18:24 | 12:18:54 |
| S42 | S Sudkreuz Bhf | S Sonnenallee (Berlin) | 12:20:12 | 12:20:36 |
| S42 | S Sudkreuz Bhf | S Treptower Park (Berlin) | 12:23:18 | 12:23:48 |
| S42 | S Sudkreuz Bhf | S Ostkreuz Bhf (Berlin) | 12:25:30 | 12:26:12 |
| S7 | S Potsdam Hauptbahnhof | S Ostkreuz Bhf (Berlin) | 12:30:36 | 12:31:24 |
| S7 | S Potsdam Hauptbahnhof | S+U Warschauer Str. (Berlin) | 12:33:06 | 12:33:42 |
| S7 | S Potsdam Hauptbahnhof | S Ostbahnhof (Berlin) | 12:35:24 | 12:36:12 |
| S7 | S Potsdam Hauptbahnhof | S+U Jannowitzbrucke (Berlin) | 12:37:54 | 12:38:24 |
| S7 | S Potsdam Hauptbahnhof | S+U Alexanderplatz Bhf (Berlin) | 12:39:54 | 12:40:42 |

### 2.3. Routing for earliest arrivals or earliest departures

The above route with the “S” services leaves one minute later, and
arrives two minutes later. Importantly,
[`gtfs_route()`](https://UrbanAnalyst.github.io/gtfsrouter/reference/gtfs_route.md)
searches by default for the service which arrives at the nominated
destination station at the earliest time. This may not always be the
first available service departing from the nominated start station.
Routing with the earliest *departing* service, instead of the earliest
*arriving* service, can be specified with the binary `earliest_arrival`
parameter:

``` r

from <- "Alexanderplatz"
to <- "Pankow"
gtfs_route (
    gtfs,
    from = from,
    to = to,
    start_time = "12:00:00",
    day = "Sunday",
    earliest_arrival = FALSE
)
```

| route_name | trip_name | stop_name | arrival_time | departure_time |
|:---|:---|:---|:---|:---|
| U2 | S+U Pankow | S+U Alexanderplatz (Berlin) \[U2\] | 12:09:00 | 12:09:00 |
| U2 | S+U Pankow | U Rosa-Luxemburg-Platz (Berlin) | 12:11:00 | 12:11:00 |
| U2 | S+U Pankow | U Senefelderplatz (Berlin) | 12:12:30 | 12:12:30 |
| U2 | S+U Pankow | U Eberswalder Str. (Berlin) | 12:14:30 | 12:14:30 |
| U2 | S+U Pankow | S+U Schonhauser Allee (Berlin) | 12:16:30 | 12:16:30 |
| U2 | S+U Pankow | U Vinetastr. (Berlin) | 12:19:00 | 12:19:00 |
| U2 | S+U Pankow | S+U Pankow (Berlin) | 12:20:30 | 12:20:30 |

And the earliest-departing route arrives at Pankow at 12:20:30,
departing Alexanderplatz at 12:09:00. In contrast, the earliest-arriving
service is:

``` r

gtfs_route (
    gtfs,
    from = from,
    to = to,
    start_time = "12:00:00",
    day = "Sunday",
    earliest_arrival = TRUE
)
```

| route_name | trip_name | stop_name | arrival_time | departure_time |
|:---|:---|:---|:---|:---|
| U2 | S+U Pankow | S+U Alexanderplatz (Berlin) \[U2\] | 12:09:00 | 12:09:00 |
| U2 | S+U Pankow | U Rosa-Luxemburg-Platz (Berlin) | 12:11:00 | 12:11:00 |
| U2 | S+U Pankow | U Senefelderplatz (Berlin) | 12:12:30 | 12:12:30 |
| U2 | S+U Pankow | U Eberswalder Str. (Berlin) | 12:14:30 | 12:14:30 |
| U2 | S+U Pankow | S+U Schonhauser Allee (Berlin) | 12:16:30 | 12:16:30 |
| U2 | S+U Pankow | U Vinetastr. (Berlin) | 12:19:00 | 12:19:00 |
| U2 | S+U Pankow | S+U Pankow (Berlin) | 12:20:30 | 12:20:30 |

This service departs 0min, 0s later at 12:09:00, and arrives 0 seconds
earlier at 12:20:30. The earliest-arriving service thus entails 0min, 0s
less travel time than the earliest departing service. It is nevertheless
important to note that queries for earliest-arriving services require
two full routing runs, whereas earliest-departing services can be
executed in a single run. This, bulk queries for analytic purposes will
generally be up to twice as first with `earliest_arrival = FALSE`.

## 3. Convenience Functions: `go_home()` and `go_to_work()`

The `gtfsrouter` package is intended both to enable statistical analyses
of GTFS data sets, as well as for personal, pragmatic purposes. In the
latter regard, the package provides two “convenience” functions to allow
single-call queries for next available services to “home” and “work”
stations. These functions require some initial set-up through specifying
environmental variables, but once done can be executed as single calls
from any **R** session to return the next available service.

``` r

go_home ()
```

    ##    route_name              trip_name                            stop_name
    ## 1          S7 S Potsdam Hauptbahnhof      S+U Alexanderplatz Bhf (Berlin)
    ## 2          S7 S Potsdam Hauptbahnhof          S Hackescher Markt (Berlin)
    ## 3          S7 S Potsdam Hauptbahnhof       S+U Friedrichstr. Bhf (Berlin)
    ## 4          S2          S Lichtenrade       S+U Friedrichstr. Bhf (Berlin)
    ## 5          S2          S Lichtenrade       S+U Brandenburger Tor (Berlin)
    ## 6          S2          S Lichtenrade     S+U Potsdamer Platz Bhf (Berlin)
    ## 7          S2          S Lichtenrade          S Anhalter Bahnhof (Berlin)
    ## 8          S2          S Lichtenrade S+U Yorckstr. S2 S25 S26 U7 (Berlin)
    ## 9          S2          S Lichtenrade              S Sudkreuz Bhf (Berlin)
    ## 10        S41         S Sudkreuz Bhf              S Sudkreuz Bhf (Berlin)
    ## 11        S41         S Sudkreuz Bhf                S Schoneberg (Berlin)
    ## 12        S41         S Sudkreuz Bhf       S+U Innsbrucker Platz (Berlin)
    ##    arrival_time departure_time
    ## 1      12:19:54       12:20:42
    ## 2      12:21:54       12:22:24
    ## 3      12:23:54       12:24:42
    ## 4      12:28:00       12:28:42
    ## 5      12:29:54       12:30:24
    ## 6      12:31:54       12:32:24
    ## 7      12:34:00       12:34:30
    ## 8      12:36:42       12:37:12
    ## 9      12:39:18       12:39:54
    ## 10     12:46:12       12:46:12
    ## 11     12:47:42       12:48:12
    ## 12     12:49:24       12:49:54

The complementary function,
[`go_to_work()`](https://UrbanAnalyst.github.io/gtfsrouter/reference/go_to_work.md)
routes in the reverse direction. These functions are intended to allow
real-time queries of public transport schedules from within the comfort
of an **R** session, and will generally be much quicker – and hopefully
easier – than the arguably burdensome necessity of switching attention
from productive **R** programming to the usual app or website otherwise
needed to answer the simple question of when I ought to leave today?

Successfully calling that function requires setting three environmental
variables:

``` r

Sys.setenv ("gtfs_home" = "<my home station>")
Sys.setenv ("gtfs_work" = "<my work station>")
Sys.setenv ("gtfs_data" = "/full/path/to/gtfs.zip")
```

along with execution of the single command:

``` r

process_gtfs_local ()
```

This command attempts to reduce the size of the locally-stored GTFS data
to the minimum required for local routing, and saves the result as an
internal `.Rds` object in the same location as the `gtfs_data`
environmental variable. Having done that,
[`go_home()`](https://UrbanAnalyst.github.io/gtfsrouter/reference/go_home.md)
will search for the next available service from the nominated work
station to the nominated home station, while
[`go_to_work()`](https://UrbanAnalyst.github.io/gtfsrouter/reference/go_to_work.md)
will search for connections in the other direction.

An even easier way to use these functions is to automatically load those
environmental variables at the start of each **R** session, which can be
achieved simply by creating a file named `.Renviron` in the user’s root
directory (or opening if it already exists), and pasting or appending
the definitions to that file - in this case, without the **R**-specific
[`Sys.setenv()`](https://rdrr.io/r/base/Sys.setenv.html) calls:

``` bash
gtfs_home = "<my home station>"
gtfs_work = "<my work station>"
gtfs_data = "/full/path/to/gtfs.zip"
```

Of course, this function will only route using locally-stored data, so
it is up to the user to ensure their local copy of `gtfs.zip` is kept up
to date.

The functions include one additional feature. Having found the next
service with
[`go_home()`](https://UrbanAnalyst.github.io/gtfsrouter/reference/go_home.md),
I may suspect that I can keep working until the following service. The
simple parameter `wait` enables searching for that following service:

``` r

go_home (wait = 1)
```

    ##    route_name         trip_name                       stop_name arrival_time
    ## 1          S5 S Strausberg Nord S+U Alexanderplatz Bhf (Berlin)     12:27:06
    ## 2          S5 S Strausberg Nord    S+U Jannowitzbrucke (Berlin)     12:29:24
    ## 3          S5 S Strausberg Nord           S Ostbahnhof (Berlin)     12:31:36
    ## 4          S5 S Strausberg Nord    S+U Warschauer Str. (Berlin)     12:34:06
    ## 5          S5 S Strausberg Nord         S Ostkreuz Bhf (Berlin)     12:36:24
    ## 6         S41    S Sudkreuz Bhf         S Ostkreuz Bhf (Berlin)     12:40:24
    ## 7         S41    S Sudkreuz Bhf       S Treptower Park (Berlin)     12:42:42
    ## 8         S41    S Sudkreuz Bhf          S Sonnenallee (Berlin)     12:45:54
    ## 9         S41    S Sudkreuz Bhf           S+U Neukolln (Berlin)     12:47:42
    ## 10        S41    S Sudkreuz Bhf        S+U Hermannstr. (Berlin)     12:49:24
    ## 11        S41    S Sudkreuz Bhf          S+U Tempelhof (Berlin)     12:53:12
    ## 12        S41    S Sudkreuz Bhf         S Sudkreuz Bhf (Berlin)     12:56:12
    ## 13        S41    S Sudkreuz Bhf           S Schoneberg (Berlin)     12:57:42
    ## 14        S41    S Sudkreuz Bhf  S+U Innsbrucker Platz (Berlin)     12:59:24
    ##    departure_time
    ## 1        12:27:54
    ## 2        12:29:54
    ## 3        12:32:24
    ## 4        12:34:42
    ## 5        12:37:12
    ## 6        12:41:12
    ## 7        12:43:12
    ## 8        12:46:18
    ## 9        12:48:12
    ## 10       12:49:54
    ## 11       12:53:42
    ## 12       12:56:12
    ## 13       12:58:12
    ## 14       12:59:54

The service after that can be retrieved with `go_home (wait = 2)`, and
so on.
