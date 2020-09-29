# v 0.0.4

Major changes:

- New function, `gtfs_route_headway` to calculate headways for entire routes
  between any nominated points (see #43)
- Important bug fix that prevents routes including stops that are not part of
  actual route


# v 0.0.3

Major changes:

- New function `frequencies_to_stop_times` thanks to new co-author @stmarcin,
  and new contributor @AlexandraKapp
- Data without `transfers.txt` now load rather than error
- New function `gtfs_transfer_table` makes transfer table for feeds which
  contain no such table; see #14
- Main `gtfs_route()` function now accepts multiple `from` and `to` values, and
  returns a list of routes (see #28).

Minor changes:

- `extract_gtfs` has new parameter, `stn_suffixes`, to enable specification of
  any suffixes to be optionally removed from station IDs (#37; thanks to
  AlexandraKapp).
- Bug fix in station name matches in `gtfs_route` fn (see #26)
- `gtfs_route` accepts `stop_id` values as well as `stop_name` (see #26)
- `gtfs_isochrone` accepts equivalent `stop_id` values via `from_is_id` parameter.
- both `gtfs_route` and `gtfs_isochrone` accept (lon, lat) values for from and
  to stations.
- `gtfs_isochrone` returns `stop_id` as well as `stop_name` values (#29).
- `gtfs_isochrone` returns `arrival_time` for all mid-points (#30, #36; thanks to @AlexandraKapp)
- Former errors in reading of `zip` archives on Windows OS fixed
