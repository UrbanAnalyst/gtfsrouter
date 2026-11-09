# go_to_work

Use local environmental variables specifying home and work stations and
locations of locally-stored GTFS data to route from home to work
location with next available service.

## Usage

``` r
go_to_work(wait = 0, start_time)
```

## Arguments

- wait:

  An integer specifying the n-th next service. That is, `wait = n` will
  return the n-th available service after the next immediate service.

- start_time:

  If given, search for connections after specified time; if not given,
  search for connections from current time.

## Value

A `data.frame` specifying the next available route from work to home.

## Details

This function, and the complementary function go_to_work, requires three
local environmental variables specifying the names of home and work
stations, and the location on local storage of the GTFS data set to be
used for routing. These are respectively called `gtfs_home`,
`gtfs_work`, and `gtfs_data`. This data set must also be pre-processed
using the
[process_gtfs_local](https://UrbanAnalyst.github.io/gtfsrouter/reference/process_gtfs_local.md)
function.

See [Startup](https://rdrr.io/r/base/Startup.html) for details on how to
set environmental variables. Briefly, this can be done in two main ways:
By setting them at the start of each session, in which case the
variables may be set with:
`Sys.setenv ("gtfs_home" = "<my home station>")`
`Sys.setenv ("gtfs_work" = "<my work station>")`
`Sys.setenv ("gtfs_data" = "/full/path/to/gtfs.zip")` Alternatively, to
set these automatically for each session, paste those lines into the
file `~/.Renviron` - that is, a file named ".Renviron" in the user's
home directory.

The
[process_gtfs_local](https://UrbanAnalyst.github.io/gtfsrouter/reference/process_gtfs_local.md)
function reduces the GTFS data set to the minimal possible size
necessary for local routing. GTFS data are nevertheless typically quite
large, and both the
[go_home](https://UrbanAnalyst.github.io/gtfsrouter/reference/go_home.md)
and go_to_work functions may take some time to execute. Most of this
time is devoted to loading the data in to the current workspace and as
such is largely unavoidable.

## See also

Other additional:
[`go_home()`](https://UrbanAnalyst.github.io/gtfsrouter/reference/go_home.md),
[`process_gtfs_local()`](https://UrbanAnalyst.github.io/gtfsrouter/reference/process_gtfs_local.md),
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
process_gtfs_local () # If not already done
go_to_work (start_time = "12:00") # next available service after 12:00
go_to_work (3, start_time = "12:00") # Wait until third service after that

# Generally, `start_time` will not be specified, in which case `go_to_work`
# will return next available service from current system time, so calls will
# generally be as simple as:
go_to_work ()
go_to_work (3)
} # }
```
