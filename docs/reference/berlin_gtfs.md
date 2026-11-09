# berlin_gtfs

Sample GTFS data from Verkehrsverbund Berlin-Brandenburg street, reduced
to U and S Bahn only (underground and overground trains), and between
the hours of 12:00-13:00. Only those components of the GTFS data
necessary for routing have been retained. Note that non-ASCII characters
have been removed from these data, so umlauts are simply removed and
eszetts become "ss". The package will nevertheless work with full GTFS
feeds and non-ASCII (UTF-8) characters.

## Format

A list of five data.table items necessary for routing:

- calendar

- routes

- trips

- stop_times

- stops

- transfers

## Value

For single (from, to) values, a `data.frame` describing the route, with
each row representing one stop. For multiple (from, to) values, a list
of `data.frames`, each of which describes one route between the i'th
start and end stations (`from` and `to` values). Origin and destination
stations for which no route is possible return `NULL`.

## Note

Can be re-created with the script in
<https://github.com/UrbanAnalyst/gtfsrouter/blob/master/data-raw/data-script.Rmd>.

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
