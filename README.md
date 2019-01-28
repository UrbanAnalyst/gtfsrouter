[![Build
Status](https://travis-ci.org/ATFutures/gtfs-router.svg)](https://travis-ci.org/ATFutures/gtfs-router)
[![AppVeyor Build
Status](https://ci.appveyor.com/api/projects/status/github/ATFutures/gtfs-router?branch=master&svg=true)](https://ci.appveyor.com/project/ATFutures/gtfs-router)
[![codecov](https://codecov.io/gh/ATFutures/gtfs-router/branch/master/graph/badge.svg)](https://codecov.io/gh/ATFutures/gtfs-router)
[![Project Status:
Concept](https://www.repostatus.org/badges/latest/concept.svg)](https://www.repostatus.org/#concept)

# GTFS Router

Find quickest routes with [GTFS
feed](https://developers.google.com/transit/gtfs/). Among the additional
aims of this repo are to quantify the dynamic stability of a GTFS
network in time and space, and to identify “weakest nodes” as those
where a temporal disruption propogates out to have the greatest effect
throughout the broader network.

Test data will be the VBB (Verkehrsverbund Berlin-Brandenburg) GTFS feed
available
[here](https://daten.berlin.de/datensaetze/vbb-fahrplandaten-gtfs), with
the results providing useful input data for
[`flux.fail`](https://flux.fail).

## GTFS Structure

For background information, see [`gtfs.org`](http://gtfs.org), and
particularly their [GTFS
Examples](https://docs.google.com/document/d/16inL5BVcM1aU-_DcFJay_tC6Ni0wPa0nvQEstueG5k4/edit).
The VBB is strictly schedule-only, so has no `"frequencies.txt"` file
(this file defines “service periods”, and overrides any schedule
information during the specified times).
