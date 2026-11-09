# summary.gtfs

summary.gtfs

## Usage

``` r
# S3 method for class 'gtfs'
summary(object, ...)
```

## Arguments

- object:

  A `gtfs` object to be summarised

- ...:

  ignored here

## Value

Nothing; this function only prints a summary to the console.

## See also

Other additional:
[`go_home()`](https://UrbanAnalyst.github.io/gtfsrouter/reference/go_home.md),
[`go_to_work()`](https://UrbanAnalyst.github.io/gtfsrouter/reference/go_to_work.md),
[`process_gtfs_local()`](https://UrbanAnalyst.github.io/gtfsrouter/reference/process_gtfs_local.md)

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
summary (g)
#> A gtfs object with the following tables and respective numbers of entries in each:
#>   calendar     routes      trips stop_times      stops  transfers 
#>       2395         52      28590      22666        957       9833 
g <- gtfs_timetable (g)
#> Day not specified; extracting timetable for monday
summary (g) # also summarizes additional timetable information
#> A gtfs timetable object with the following tables and respective numbers of entries in each:
#>   calendar     routes      trips stop_times      stops  transfers  timetable 
#>       2395         52       7475       7626        957       9833       7052 
#>   stop_ids   trip_ids 
#>        957        574 

data.table::setDTthreads (nthr)
```
