# gtfs_transfer_table

Construct a transfer table for a GTFS feed.

## Usage

``` r
gtfs_transfer_table(
  gtfs,
  d_limit = 200,
  min_transfer_time = 120,
  network = NULL,
  network_times = FALSE,
  quiet = FALSE
)
```

## Arguments

- gtfs:

  A GTFS feed obtained from the
  [extract_gtfs](https://UrbanAnalyst.github.io/gtfsrouter/reference/extract_gtfs.md)
  function.

- d_limit:

  Upper straight-line distance limit in metres for transfers.

- min_transfer_time:

  Minimum time in seconds for transfers; all values below this will be
  replaced with this value, particularly all those defining in-place
  transfers where stop longitudes and latitudes remain identical.

- network:

  Optional Open Street Map representation of the street network
  encompassed by the GTFS feed (see Examples).

- network_times:

  If `TRUE`, transfer times are calculated by routing throughout the
  underlying street network. If this is not provided as the `net`
  parameter, it will be automatically downloaded. If a network, is
  provided, this parameter is automatically set to `TRUE`.

- quiet:

  Set to `TRUE` to suppress screen messages

## Value

Modified version of the `gtfs` input with additional transfers table.

## See also

Other augment:
[`frequencies_to_stop_times()`](https://UrbanAnalyst.github.io/gtfsrouter/reference/frequencies_to_stop_times.md)

## Examples

``` r
# Examples must be run on single thread only:
nthr <- data.table::setDTthreads (1)

berlin_gtfs_to_zip ()
#> /tmp/RtmpqDMjhP/vbb.zip
f <- file.path (tempdir (), "vbb.zip")
g <- extract_gtfs (f, quiet = TRUE)
g <- gtfs_transfer_table (g, d_limit = 200)
# g$transfers then has fewer rows than original, because original transfer
# table contains duplicated rows.

data.table::setDTthreads (nthr)
```
