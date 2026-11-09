# gtfs_route

Calculate single route between a start and end station departing at or
after a specified time.

## Usage

``` r
gtfs_route(
  gtfs,
  from,
  to,
  start_time = NULL,
  day = NULL,
  route_pattern = NULL,
  earliest_arrival = TRUE,
  include_ids = FALSE,
  grep_fixed = TRUE,
  max_transfers = NA,
  from_to_are_ids = FALSE,
  quiet = FALSE
)
```

## Arguments

- gtfs:

  A set of GTFS data returned from
  [extract_gtfs](https://UrbanAnalyst.github.io/gtfsrouter/reference/extract_gtfs.md)
  or, for more efficient queries, pre-processed with
  [gtfs_timetable](https://UrbanAnalyst.github.io/gtfsrouter/reference/gtfs_timetable.md).

- from:

  Names, IDs, or approximate (lon, lat) coordinates of start stations
  (as `stop_name` or `stop_id` entry in the `stops` table, or a vector
  of two numeric values). See Note.

- to:

  Corresponding Names, IDs, or coordinates of end station.

- start_time:

  Desired departure time at `from` station, either in seconds after
  midnight, a vector of two or three integers (hours, minutes) or
  (hours, minutes, seconds), an object of class
  [difftime](https://rdrr.io/r/base/difftime.html), hms, or lubridate.
  If not provided, current time is used.

- day:

  Day of the week on which to calculate route, either as an unambiguous
  string (so "tu" and "th" for Tuesday and Thursday), or a number
  between 1 = Sunday and 7 = Saturday. If not given, the current day
  will be used. (Not used if `gtfs` has already been prepared with
  [gtfs_timetable](https://UrbanAnalyst.github.io/gtfsrouter/reference/gtfs_timetable.md).)

- route_pattern:

  Using only those routes matching given pattern, for example, "^U" for
  routes starting with "U" (as commonly used for underground or subway
  routes. To negate the `route_pattern` – that is, to include all routes
  except those matching the pattern – prepend the value with "!"; for
  example "!^U" will include all services except those starting with
  "U". (This parameter is not used at all if `gtfs` has already been
  prepared with
  [gtfs_timetable](https://UrbanAnalyst.github.io/gtfsrouter/reference/gtfs_timetable.md).)

- earliest_arrival:

  If `FALSE`, routing will be with the first-departing service, which
  may not provide the earliest arrival at the `to` station. This may
  nevertheless be useful for bulk queries, as earliest arrival searches
  require two routing queries, while earliest departure searches require
  just one, and so will be generally twice as fast.

- include_ids:

  If `TRUE`, result will include columns containing GTFS-specific
  identifiers for routes, trips, and stops.

- grep_fixed:

  If `FALSE`, match station names (when passed as character string) with
  `grep(..., fixed = FALSE)`, to allow use of `grep` expressions. This
  is useful to refine matches in cases where desired stations may match
  multiple entries.

- max_transfers:

  If not `NA`, specify a desired maximum number of transfers for the
  route (including but not exceeding this number). This parameter may be
  used to generate alternative routes with fewer transfers, although
  actual numbers of transfers may still exceed this number if the value
  specified is less than the minimal feasible number of transfers.

- from_to_are_ids:

  Set to `TRUE` to enable `from` and `to` parameter to specify entries
  in `stop_id` rather than `stop_name` column of the `stops` table.

- quiet:

  Set to `TRUE` to suppress screen messages (currently just regarding
  timetable construction).

## Value

For single (from, to) values, a `data.frame` describing the route, with
each row representing one stop. For multiple (from, to) values, a list
of `data.frames`, each of which describes one route between the i'th
start and end stations (`from` and `to` values). Origin and destination
stations for which no route is possible return `NULL`.

## Note

This function will by default calculate the route that arrives earliest
at the specified destination, although this may depart later than the
earliest departing service. Routes which depart at the earliest possible
time can be calculated by setting `earliest_arrival = FALSE`.

## See also

Other main:
[`gtfs_route_headway()`](https://UrbanAnalyst.github.io/gtfsrouter/reference/gtfs_route_headway.md),
[`gtfs_traveltimes()`](https://UrbanAnalyst.github.io/gtfsrouter/reference/gtfs_traveltimes.md)

## Examples

``` r
# Examples must be run on single thread only:
nthr_dt <- data.table::setDTthreads (1)
nthr_omp <- Sys.getenv ("OMP_THREAD_LIMIT")
Sys.setenv ("OMP_THREAD_LIMIT" = 1L)

berlin_gtfs_to_zip () # Write sample feed from Berlin, Germany to tempdir
#> /tmp/RtmpqDMjhP/vbb.zip
f <- file.path (tempdir (), "vbb.zip") # name of feed
gtfs <- extract_gtfs (f)
#> ▶ Unzipping GTFS archive
#> 
✔ Unzipped GTFS archive  
#> ▶ Extracting GTFS feed
#> 
✔ Extracted GTFS feed 
#> ▶ Converting stop times to seconds
#> 
✔ Converted stop times to seconds 
#> ▶ Converting transfer times to seconds
#> 
✔ Converted transfer times to seconds 
from <- "Innsbrucker Platz" # U-bahn station, not "S"
to <- "Alexanderplatz"
start_time <- 12 * 3600 + 120 # 12:02

route <- gtfs_route (gtfs, from = from, to = to, start_time = start_time)
#> Day not specified; extracting timetable for monday

# Specify day of week
route <- gtfs_route (
    gtfs,
    from = from,
    to = to,
    start_time = start_time,
    day = "Sunday"
)

# specify travel by "U" = underground only
route <- gtfs_route (
    gtfs,
    from = from,
    to = to,
    start_time = start_time,
    day = "Sunday",
    route_pattern = "^U"
)
# specify travel by "S" = street-level only (not underground)
route <- gtfs_route (
    gtfs,
    from = from,
    to = to,
    start_time = start_time,
    day = "Sunday",
    route_pattern = "^S"
)

# Route queries are generally faster if the GTFS data are pre-processed with
# `gtfs_timetable()`:
gt <- gtfs_timetable (gtfs, day = "Sunday", route_pattern = "^S")
route <- gtfs_route (gt, from = from, to = to, start_time = start_time)

data.table::setDTthreads (nthr_dt)
Sys.setenv ("OMP_THREAD_LIMIT" = nthr_omp)
```
