# GTFS Router

Find quickest routes with GTFS feed. Among the additional aims of this repo are
to quantify the dynamic stability of a GTFS network in time and space, and to
identify "weakest nodes" as those where a temporal disruption propogates out to
have the greatest effect throughout the broader network.

Test data will be the VBB (Verkehrsverbund Berlin-Brandenburg) GTFS feed
available [here](https://daten.berlin.de/datensaetze/vbb-fahrplandaten-gtfs),
with the results providing useful input data for
[`flux.fail`](https://flux.fail).
