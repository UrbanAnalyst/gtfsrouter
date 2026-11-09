# Route headway

Calculate a vector of headway values – that is, time intervals between
consecutive services – for all routes between two specified stations.

## Usage

``` r
gtfs_route_headway(
  gtfs,
  from,
  to,
  from_to_are_ids = FALSE,
  grep_fixed = TRUE,
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

- from_to_are_ids:

  Set to `TRUE` to enable `from` and `to` parameter to specify entries
  in `stop_id` rather than `stop_name` column of the `stops` table.

- grep_fixed:

  If `FALSE`, match station names (when passed as character string) with
  `grep(..., fixed = FALSE)`, to allow use of `grep` expressions. This
  is useful to refine matches in cases where desired stations may match
  multiple entries.

- quiet:

  If `TRUE`, display a progress bar

## Value

A single vector of integer values containing headways between all
services across a single 24-hour period

## See also

Other main:
[`gtfs_route()`](https://UrbanAnalyst.github.io/gtfsrouter/reference/gtfs_route.md),
[`gtfs_traveltimes()`](https://UrbanAnalyst.github.io/gtfsrouter/reference/gtfs_traveltimes.md)

## Examples

``` r
if (FALSE) { # \dontrun{
path <- berlin_gtfs_to_zip ()
gtfs <- extract_gtfs (path)
gtfs_route_headway (gtfs, from = "Tegel", to = "Berlin Hauptbahnhof")
} # }
```
