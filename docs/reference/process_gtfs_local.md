# process_gtfs_local

Process a local GTFS data set with environmental variables described in
[go_home](https://UrbanAnalyst.github.io/gtfsrouter/reference/go_home.md)
into a condensed version for use in
[go_home](https://UrbanAnalyst.github.io/gtfsrouter/reference/go_home.md)
and `go_to_work` functions.

## Usage

``` r
process_gtfs_local(expand = 2)
```

## Arguments

- expand:

  The data set is reduced to the bounding box defined by the home and
  work stations, expanded by this multiple. If the function appears to
  behave strangely, try re-running this function with a higher value of
  this parameter.

## Value

No return value. The function saves processed data to a local cache.

## See also

Other additional:
[`go_home()`](https://UrbanAnalyst.github.io/gtfsrouter/reference/go_home.md),
[`go_to_work()`](https://UrbanAnalyst.github.io/gtfsrouter/reference/go_to_work.md),
[`summary.gtfs()`](https://UrbanAnalyst.github.io/gtfsrouter/reference/summary.gtfs.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# For general use, please set these three variables:
Sys.setenv ("gtfs_home" = "<my home station>")
Sys.setenv ("gtfs_work" = "<my work station>")
Sys.setenv ("gtfs_data" = "/full/path/to/gtfs.zip")

# The following illustrate use with sample data bundled with package
Sys.setenv ("gtfs_home" = "Tempelhof")
Sys.setenv ("gtfs_work" = "Alexanderplatz")
Sys.setenv ("gtfs_data" = file.path (tempdir (), "vbb.zip"))
process_gtfs_local ()
# next available service from current system time:
go_home ()
} # }
```
