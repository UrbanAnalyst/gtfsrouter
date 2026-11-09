# extract_gtfs

Extract data from a GTFS `zip` archive.

## Usage

``` r
extract_gtfs(filename = NULL, quiet = FALSE, stn_suffixes = NULL)
```

## Arguments

- filename:

  Name of GTFS archive

- quiet:

  If `FALSE`, display progress information on screen

- stn_suffixes:

  Any values provided will be removed from terminal characters of
  station IDs. Useful for feeds like NYC for which some stations are
  appended with values of "N" and "S" to indicate directions. Specifying
  `stn_suffixes = c ("N", "S")` will automatically remove these
  suffixes.

## Value

List of several data.table objects corresponding to the tables present
in the nominated GTFS data set.

## Note

Column types in each table of the returned object conform to GTFS
standards (<https://developers.google.com/transit/gtfs/reference>),
except that "Time" fields in the "stop_times" table are converted to
integer values, rather than as character or "Time" objects ("HH:MM:SS").
These can be converted back to comply with GTFS standards by applying
the [`hms::hms()`](https://hms.tidyverse.org/reference/hms.html)
function to the two time columns of the "stop_times" table.

## See also

Other extract:
[`berlin_gtfs_to_zip()`](https://UrbanAnalyst.github.io/gtfsrouter/reference/berlin_gtfs_to_zip.md),
[`gtfs_timetable()`](https://UrbanAnalyst.github.io/gtfsrouter/reference/gtfs_timetable.md)

## Examples

``` r
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
```
