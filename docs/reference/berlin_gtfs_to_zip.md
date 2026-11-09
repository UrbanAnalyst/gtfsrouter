# berlin_gtfs_to_zip

Write a zip archive of the internal package data,
[berlin_gtfs](https://UrbanAnalyst.github.io/gtfsrouter/reference/berlin_gtfs.md)
to a file named "vbb.zip" to
[`tempdir()`](https://rdrr.io/r/base/tempfile.html).

## Usage

``` r
berlin_gtfs_to_zip()
```

## Value

Path to newly created zip file

## See also

Other extract:
[`extract_gtfs()`](https://UrbanAnalyst.github.io/gtfsrouter/reference/extract_gtfs.md),
[`gtfs_timetable()`](https://UrbanAnalyst.github.io/gtfsrouter/reference/gtfs_timetable.md)

## Examples

``` r
path <- berlin_gtfs_to_zip ()
gtfs <- extract_gtfs (path)
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
gtfs <- gtfs_timetable (gtfs, day = "Wed") # A pre-processing step to speed up queries
gtfs_route (gtfs, from = "Tegel", to = "Berlin Hauptbahnhof", start_time = 12 * 3600)
#>    route_name              trip_name                        stop_name
#> 1          U6       U Alt-Mariendorf             U Alt-Tegel (Berlin)
#> 2          U6       U Alt-Mariendorf           U Borsigwerke (Berlin)
#> 3          U6       U Alt-Mariendorf       U Holzhauser Str. (Berlin)
#> 4          U6       U Alt-Mariendorf              U Otisstr. (Berlin)
#> 5          U6       U Alt-Mariendorf       U Scharnweberstr. (Berlin)
#> 6          U6       U Alt-Mariendorf U Kurt-Schumacher-Platz (Berlin)
#> 7          U6       U Alt-Mariendorf     U Afrikanische Str. (Berlin)
#> 8          U6       U Alt-Mariendorf              U Rehberge (Berlin)
#> 9          U6       U Alt-Mariendorf               U Seestr. (Berlin)
#> 10         U6       U Alt-Mariendorf          U Leopoldplatz (Berlin)
#> 11         U6       U Alt-Mariendorf             S+U Wedding (Berlin)
#> 12         U6       U Alt-Mariendorf  U Reinickendorfer Str. (Berlin)
#> 13         U6       U Alt-Mariendorf     U Schwartzkopffstr. (Berlin)
#> 14         U6       U Alt-Mariendorf      U Naturkundemuseum (Berlin)
#> 15         U6       U Alt-Mariendorf     U Oranienburger Tor (Berlin)
#> 16         U6       U Alt-Mariendorf   S+U Friedrichstr. Bhf (Berlin)
#> 17         S7 S Potsdam Hauptbahnhof   S+U Friedrichstr. Bhf (Berlin)
#> 18         S7 S Potsdam Hauptbahnhof          S+U Berlin Hauptbahnhof
#>    arrival_time departure_time
#> 1      12:02:00       12:02:00
#> 2      12:03:30       12:03:30
#> 3      12:05:00       12:05:00
#> 4      12:06:00       12:06:00
#> 5      12:07:30       12:07:30
#> 6      12:09:00       12:09:00
#> 7      12:10:30       12:10:30
#> 8      12:11:30       12:11:30
#> 9      12:13:30       12:13:30
#> 10     12:15:00       12:15:00
#> 11     12:16:00       12:16:00
#> 12     12:17:00       12:17:00
#> 13     12:18:30       12:18:30
#> 14     12:19:30       12:19:30
#> 15     12:21:00       12:21:00
#> 16     12:22:30       12:22:30
#> 17     12:33:54       12:34:42
#> 18     12:36:36       12:37:12
```
