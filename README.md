# gtfsrouter <a href='https://atfutures.github.io/gtfs-router/'><img src='man/figures/gtfsrouter.png' align="right" height=210 width=182/></a>

[![R build
status](https://github.com/atfutures/gtfs-router/workflows/R-CMD-check/badge.svg)](https://github.com/atfutures/gtfs-router/actions?query=workflow%3AR-CMD-check)
[![codecov](https://codecov.io/gh/ATFutures/gtfs-router/branch/master/graph/badge.svg)](https://codecov.io/gh/ATFutures/gtfs-router)
[![Project Status:
Active](https://www.repostatus.org/badges/latest/active.svg)](https://www.repostatus.org/#active)
[![CRAN\_Status\_Badge](http://www.r-pkg.org/badges/version/gtfsrouter)](https://cran.r-project.org/package=gtfsrouter)
[![CRAN
Downloads](http://cranlogs.r-pkg.org/badges/grand-total/gtfsrouter?color=orange)](https://cran.r-project.org/package=gtfsrouter)

**R** package for public transport routing with [GTFS (General Transit
Feed Specification)](https://developers.google.com/transit/gtfs/) data.

## Installation

You can install latest stable version of `gtfsrouter` from CRAN with:

``` r
install.packages("gtfsrouter")
```

Alternatively, the current development version can be installed using
any of the following options:

``` r
# install.packages("remotes")
remotes::install_git("https://git.sr.ht/~mpadge/gtfsrouter")
remotes::install_bitbucket("atfutures/gtfsrouter")
remotes::install_gitlab("atfutures1/gtfsrouter")
remotes::install_github("ATFutures/gtfsrouter")
```

To load the package and check the version:

``` r
library(gtfsrouter)
packageVersion("gtfsrouter")
```

    ## [1] '0.0.5.29'

## Main functions

The main functions can be demonstrated with sample data included with
the package from Berlin (the “Verkehrverbund Berlin Brandenburg”, or
VBB). GTFS data are always stored as `.zip` files, and these sample data
can be written to the temporary directory (`tempdir()`) of the current R
session with the function `berlin_gtfs_to_zip()`.

``` r
filename <- berlin_gtfs_to_zip()
print (filename)
```

    ## [1] "/tmp/RtmpkOdkEf/vbb.zip"

For normal package use, `filename` will specify the name of a local GTFS
`.zip` file.

### gtfs\_route

Given the name of a GTFS `.zip` file, `filename`, routing is as simple
as the following code:

``` r
gtfs <- extract_gtfs (filename)
gtfs <- gtfs_timetable (gtfs, day = "Wed") # A pre-processing step to speed up queries
gtfs_route (gtfs,
            from = "Tegel",
            to = "Berlin Hauptbahnhof",
            start_time = 12 * 3600 + 120) # 12:02 in seconds
```

| route\_name | trip\_name       | stop\_name                      | arrival\_time | departure\_time |
|:------------|:-----------------|:--------------------------------|:--------------|:----------------|
| U8          | U Paracelsus-Bad | U Schonleinstr. (Berlin)        | 12:04:00      | 12:04:00        |
| U8          | U Paracelsus-Bad | U Kottbusser Tor (Berlin)       | 12:06:00      | 12:06:00        |
| U8          | U Paracelsus-Bad | U Moritzplatz (Berlin)          | 12:08:00      | 12:08:00        |
| U8          | U Paracelsus-Bad | U Heinrich-Heine-Str. (Berlin)  | 12:09:30      | 12:09:30        |
| U8          | U Paracelsus-Bad | S+U Jannowitzbrucke (Berlin)    | 12:10:30      | 12:10:30        |
| S5          | S Westkreuz      | S+U Jannowitzbrucke (Berlin)    | 12:15:24      | 12:15:54        |
| S5          | S Westkreuz      | S+U Alexanderplatz Bhf (Berlin) | 12:17:24      | 12:18:12        |
| S5          | S Westkreuz      | S Hackescher Markt (Berlin)     | 12:19:24      | 12:19:54        |
| S5          | S Westkreuz      | S+U Friedrichstr. Bhf (Berlin)  | 12:21:24      | 12:22:12        |
| S5          | S Westkreuz      | S+U Berlin Hauptbahnhof         | 12:24:06      | 12:24:42        |

### gtfs\_traveltimes

The [`gtfs_traveltimes()`
function\`](https://atfutures.github.io/gtfs-router/reference/gtfs_traveltimes.html)
calculates minimal travel times from any nominated stop to all other
stops within a feed. It requires the two parameters of start station,
and a vector of two values specifying earliest and latest desired start
times. The following code returns the fastest travel times to all
stations within the feed for services which leave the nominated station
(“Alexanderplatz”) between 12:00 and 13:00 on a Monday:

``` r
gtfs <- extract_gtfs (filename)
gtfs <- gtfs_timetable (gtfs, day = "Monday")
x <- gtfs_traveltimes (gtfs,
                       from = "Alexanderplatz",
                       start_time_limits = c (12, 13) * 3600)
```

The function returns a simple table detailing all stations reachable
with services departing from the nominated station and start times:

``` r
head (x)
```

| start\_time | duration | ntransfers | stop\_id     | stop\_name              | stop\_lon | stop\_lat |
|:------------|:---------|-----------:|:-------------|:------------------------|----------:|----------:|
| 12:03:42    | 00:14:12 |          1 | 060003102223 | S Bellevue (Berlin)     |  13.34710 |  52.51995 |
| 12:00:42    | 00:08:36 |          0 | 060003102224 | S Bellevue (Berlin)     |  13.34710 |  52.51995 |
| 12:00:42    | 00:15:06 |          1 | 060003103233 | S Tiergarten (Berlin)   |  13.33624 |  52.51396 |
| 12:00:42    | 00:10:42 |          0 | 060003103234 | S Tiergarten (Berlin)   |  13.33624 |  52.51396 |
| 12:03:42    | 00:11:18 |          1 | 060003201213 | S+U Berlin Hauptbahnhof |  13.36892 |  52.52585 |
| 12:00:42    | 00:05:54 |          0 | 060003201214 | S+U Berlin Hauptbahnhof |  13.36892 |  52.52585 |

Further details are provided in a [separate
vignette](https://atfutures.github.io/gtfs-router/articles/traveltimes.html).

### gtfs\_transfer\_table

Feeds should include a “transfers.txt” table detailing all possible
transfers between nearby stations, yet many feeds omit these tables,
rendering them unusable for routing because transfers between services
can not be calculated. The `gtfsrouter` package also includes a
function,
[`gtfs_transfer_table()`](https://atfutures.github.io/gtfs-router/reference/gtfs_transfer_table.html),
which can calculate a transfer table for a given feed, with transfer
times calculated either using straight-line distances (the default), or
using more realistic pedestrian times routed through the underlying
street network.

This function can also be used to enable routing through multiple
adjacent or overlapping GTFS feeds. The feeds need simply be merged
through binding the rows of all tables, and the resultant aggregate feed
submitted to the
[`gtfs_transfer_table()`](https://atfutures.github.io/gtfs-router/reference/gtfs_transfer_table.html)
function. This transfer table will retain all transfers specified in the
original feeds, yet be augmented by all possible transfers between the
multiple systems up to a user-specified maximal distance. Further
details of this function are also provided in another [separate
vignette](https://atfutures.github.io/gtfs-router/articles/transfers.html).

## Additional Functionality

There are many ways to construct GTFS feeds. For background information,
see [`gtfs.org`](http://gtfs.org), and particularly their [GTFS
Examples](https://docs.google.com/document/d/16inL5BVcM1aU-_DcFJay_tC6Ni0wPa0nvQEstueG5k4/edit).
Feeds may include a “frequencies.txt” table which defines “service
periods”, and overrides any schedule information during the specified
times. The `gtfsrouter` package includes a function,
[`frequencies_to_stop_times()`](https://atfutures.github.io/gtfs-router/reference/frequencies_to_stop_times.html),
to convert “frequencies.txt” tables to equivalent “stop\_times.txt”
entries, to enable the feed to be used for routing.

## Contributors

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->

All contributions to this project are gratefully acknowledged using the
[`allcontributors`
package](https://github.com/ropenscilabs/allcontributors) following the
[all-contributors](https://allcontributors.org) specification.
Contributions of any kind are welcome!

### Code

<table>
<tr>
<td align="center">
<a href="https://github.com/mpadge">
<img src="https://avatars.githubusercontent.com/u/6697851?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ATFutures/gtfs-router/commits?author=mpadge">mpadge</a>
</td>
<td align="center">
<a href="https://github.com/AlexandraKapp">
<img src="https://avatars.githubusercontent.com/u/18367515?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ATFutures/gtfs-router/commits?author=AlexandraKapp">AlexandraKapp</a>
</td>
<td align="center">
<a href="https://github.com/stmarcin">
<img src="https://avatars.githubusercontent.com/u/11378350?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ATFutures/gtfs-router/commits?author=stmarcin">stmarcin</a>
</td>
<td align="center">
<a href="https://github.com/polettif">
<img src="https://avatars.githubusercontent.com/u/17431069?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ATFutures/gtfs-router/commits?author=polettif">polettif</a>
</td>
</tr>
</table>

### Issues

<table>
<tr>
<td align="center">
<a href="https://github.com/tbuckl">
<img src="https://avatars.githubusercontent.com/u/98956?u=9580c2ee3c03cbbe44ac8180b0f6a6725b0415f0&v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ATFutures/gtfs-router/issues?q=is%3Aissue+author%3Atbuckl">tbuckl</a>
</td>
<td align="center">
<a href="https://github.com/sridharraman">
<img src="https://avatars.githubusercontent.com/u/570692?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ATFutures/gtfs-router/issues?q=is%3Aissue+author%3Asridharraman">sridharraman</a>
</td>
<td align="center">
<a href="https://github.com/tuesd4y">
<img src="https://avatars.githubusercontent.com/u/13107179?u=cfcc7852d1bed6e2b17fa3f985cebf743c43b299&v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ATFutures/gtfs-router/issues?q=is%3Aissue+author%3Atuesd4y">tuesd4y</a>
</td>
<td align="center">
<a href="https://github.com/luukvdmeer">
<img src="https://avatars.githubusercontent.com/u/26540305?u=c576e87314499815cbf698b7781ee58fd1d773e2&v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ATFutures/gtfs-router/issues?q=is%3Aissue+author%3Aluukvdmeer">luukvdmeer</a>
</td>
<td align="center">
<a href="https://github.com/Robinlovelace">
<img src="https://avatars.githubusercontent.com/u/1825120?u=461318c239e721dc40668e4b0ce6cc47731328ac&v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ATFutures/gtfs-router/issues?q=is%3Aissue+author%3ARobinlovelace">Robinlovelace</a>
</td>
<td align="center">
<a href="https://github.com/orlandoandradeb">
<img src="https://avatars.githubusercontent.com/u/48104481?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ATFutures/gtfs-router/issues?q=is%3Aissue+author%3Aorlandoandradeb">orlandoandradeb</a>
</td>
<td align="center">
<a href="https://github.com/Maxime2506">
<img src="https://avatars.githubusercontent.com/u/54989587?u=6d2c848ee0c7d8a2841d47791c30eec1cab35470&v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ATFutures/gtfs-router/issues?q=is%3Aissue+author%3AMaxime2506">Maxime2506</a>
</td>
</tr>
<tr>
<td align="center">
<a href="https://github.com/chinhqho">
<img src="https://avatars.githubusercontent.com/u/47441312?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ATFutures/gtfs-router/issues?q=is%3Aissue+author%3Achinhqho">chinhqho</a>
</td>
<td align="center">
<a href="https://github.com/federicotallis">
<img src="https://avatars.githubusercontent.com/u/25511806?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ATFutures/gtfs-router/issues?q=is%3Aissue+author%3Afedericotallis">federicotallis</a>
</td>
<td align="center">
<a href="https://github.com/rafapereirabr">
<img src="https://avatars.githubusercontent.com/u/7448421?u=9a760f26e72cd66150784babc5da6862e7775542&v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ATFutures/gtfs-router/issues?q=is%3Aissue+author%3Arafapereirabr">rafapereirabr</a>
</td>
<td align="center">
<a href="https://github.com/loanho23">
<img src="https://avatars.githubusercontent.com/u/48426365?u=36727e1ed27b3b6206fb922c47544ef249fad83d&v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ATFutures/gtfs-router/issues?q=is%3Aissue+author%3Aloanho23">loanho23</a>
</td>
<td align="center">
<a href="https://github.com/dcooley">
<img src="https://avatars.githubusercontent.com/u/8093396?u=2c8d9162f246d90d433034d212b29a19e0f245c1&v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ATFutures/gtfs-router/issues?q=is%3Aissue+author%3Adcooley">dcooley</a>
</td>
<td align="center">
<a href="https://github.com/dhersz">
<img src="https://avatars.githubusercontent.com/u/1557047?v=4" width="100px;" alt=""/>
</a><br>
<a href="https://github.com/ATFutures/gtfs-router/issues?q=is%3Aissue+author%3Adhersz">dhersz</a>
</td>
</tr>
</table>
<!-- markdownlint-enable -->
<!-- prettier-ignore-end -->
<!-- ALL-CONTRIBUTORS-LIST:END -->
