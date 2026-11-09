# gtfs_timetable

Convert GTFS data into format able to be used to calculate routes.

## Usage

``` r
gtfs_timetable(
  gtfs,
  day = NULL,
  date = NULL,
  route_pattern = NULL,
  quiet = FALSE
)
```

## Arguments

- gtfs:

  A set of GTFS data returned from
  [extract_gtfs](https://UrbanAnalyst.github.io/gtfsrouter/reference/extract_gtfs.md).

- day:

  Day of the week on which to calculate route, either as an unambiguous
  string (so "tu" and "th" for Tuesday and Thursday), or a number
  between 1 = Sunday and 7 = Saturday. If not given, the current day
  will be used - unless the following 'date' parameter is give.

- date:

  Some systems do not specify days of the week within their 'calendar'
  table; rather they provide full timetables for specified calendar
  dates via a 'calendar_date' table. Providing a date here as a single
  8-digit number representing 'yyyymmdd' will filter the data to the
  specified date. Also the 'calendar' is scanned for services that
  operate on the selected date. Therefore also a merge of feeds that
  combine 'calendar' and 'calendar_dates' options is covered.

- route_pattern:

  Using only those routes matching given pattern, for example, "^U" for
  routes starting with "U" (as commonly used for underground or subway
  routes. To negative the `route_pattern` – that is, to include all
  routes except those matching the patter – prepend the value with "!";
  for example "!^U" with include all services except those starting with
  "U".

- quiet:

  Set to `TRUE` to suppress screen messages (currently just regarding
  timetable construction).

## Value

The input data with an addition items, `timetable`, `stations`, and
`trips`, containing data formatted for more efficient use with
[gtfs_route](https://UrbanAnalyst.github.io/gtfsrouter/reference/gtfs_route.md)
(see Note).

## Note

This function is merely provided to speed up calls to the primary
function,
[gtfs_route](https://UrbanAnalyst.github.io/gtfsrouter/reference/gtfs_route.md).
If the input data to that function do not include a formatted
`timetable`, it will be calculated anyway, but queries in that case will
generally take longer.

## See also

Other extract:
[`berlin_gtfs_to_zip()`](https://UrbanAnalyst.github.io/gtfsrouter/reference/berlin_gtfs_to_zip.md),
[`extract_gtfs()`](https://UrbanAnalyst.github.io/gtfsrouter/reference/extract_gtfs.md)

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
