# frequencies_to_stop_times

Convert a GTFS 'frequencies' table to equivalent 'stop_times' that can
be used for routing.

## Usage

``` r
frequencies_to_stop_times(gtfs)
```

## Arguments

- gtfs:

  A set of GTFS data returned from
  [extract_gtfs](https://UrbanAnalyst.github.io/gtfsrouter/reference/extract_gtfs.md).

## Value

The input GTFS data with data from the 'frequencies' table converted to
equivalent 'arrival_time' and 'departure_time' values in `stop_times`.

## See also

Other augment:
[`gtfs_transfer_table()`](https://UrbanAnalyst.github.io/gtfsrouter/reference/gtfs_transfer_table.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Presume an input feed has been created and includes a "frequencies" table:
gtfs2 <- frequencies_to_stop_times (gtfs)
# "gtfs2" will then have an expanded "stop_times" table, with all
# "frequencies" entries converted to equivalent absolute stop times.
} # }
```
