# gtfs_traveltimes

Travel times from a nominated station departing at a nominated time to
every other reachable station in a system.

## Usage

``` r
gtfs_traveltimes(
  gtfs,
  from,
  start_time_limits,
  day = NULL,
  from_is_id = FALSE,
  grep_fixed = TRUE,
  route_pattern = NULL,
  minimise_transfers = FALSE,
  max_traveltime = 60 * 60,
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

  Name, ID, or approximate (lon, lat) coordinates of start station (as
  `stop_name` or `stop_id` entry in the `stops` table, or a vector of
  two numeric values).

- start_time_limits:

  A vector of two integer values denoting the earliest and latest
  departure times in seconds for the traveltime values.

- day:

  Day of the week on which to calculate route, either as an unambiguous
  string (so "tu" and "th" for Tuesday and Thursday), or a number
  between 1 = Sunday and 7 = Saturday. If not given, the current day
  will be used. (Not used if `gtfs` has already been prepared with
  [gtfs_timetable](https://UrbanAnalyst.github.io/gtfsrouter/reference/gtfs_timetable.md).)

- from_is_id:

  Set to `TRUE` to enable `from` parameter to specify entry in `stop_id`
  rather than `stop_name` column of the `stops` table (same as
  `from_to_are_ids` parameter of
  [gtfs_route](https://UrbanAnalyst.github.io/gtfsrouter/reference/gtfs_route.md)).

- grep_fixed:

  If `FALSE`, match station names (when passed as character string) with
  `grep(..., fixed = FALSE)`, to allow use of `grep` expressions. This
  is useful to refine matches in cases where desired stations may match
  multiple entries.

- route_pattern:

  Using only those routes matching given pattern, for example, "^U" for
  routes starting with "U" (as commonly used for underground or subway
  routes. To negate the `route_pattern` – that is, to include all routes
  except those matching the pattern – prepend the value with "!"; for
  example "!^U" will include all services except those starting with
  "U". (This parameter is not used at all if `gtfs` has already been
  prepared with
  [gtfs_timetable](https://UrbanAnalyst.github.io/gtfsrouter/reference/gtfs_timetable.md).)

- minimise_transfers:

  If `TRUE`, isochrones are calculated with minimal-transfer connections
  to each end point, even if those connections are slower than
  alternative connections with transfers.

- max_traveltime:

  The maximal traveltime to search for, specified in seconds (with
  default of 1 hour). See note for details.

- quiet:

  Set to `TRUE` to suppress screen messages (currently just regarding
  timetable construction).

## Value

A `data.frame` of travel times and required numbers of transfers to all
stations reachable from the given `from` station. Additional columns
include "start_time" of connection, and information on destination stops
including "id" numbers, names, and geographical coordinates.

## Note

Higher values of `max_traveltime` will return traveltimes for greater
numbers of stations, but may lead to considerably longer calculation
times. For repeated usage, it is recommended to first establish a value
sufficient to reach all or most stations desired for a particular query,
rather than set `max_traveltime` to an arbitrarily high value.

## See also

Other main:
[`gtfs_route()`](https://UrbanAnalyst.github.io/gtfsrouter/reference/gtfs_route.md),
[`gtfs_route_headway()`](https://UrbanAnalyst.github.io/gtfsrouter/reference/gtfs_route_headway.md)

## Examples

``` r
# Examples must be run on single thread only:
nthr <- data.table::setDTthreads (1)

berlin_gtfs_to_zip ()
#> /tmp/RtmpqDMjhP/vbb.zip
f <- file.path (tempdir (), "vbb.zip")
g <- extract_gtfs (f)
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
g <- gtfs_timetable (g)
#> Day not specified; extracting timetable for monday
from <- "Alexanderplatz"
start_times <- 12 * 3600 + c (0, 60) * 60 # 8:00-9:00
res <- gtfs_traveltimes (g, from, start_times)

data.table::setDTthreads (nthr)
```
