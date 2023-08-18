
# v 0.1.1.00x (dev version)

---

# v 0.1.1

Major changes:

- Repository moved from "ATFutures/gtfs-router" to "UrbanAnalyst/gtfsrouter"
- `gtfs_transfer_table()` function now much faster due to re-coding in C++
- Removed previously deprecated `gtfs_isochrone()` function; now entirely
  replaced by `gtfs_traveltimes()`.

Minor changes:

- `gtfs_timetable()` modified to work on feeds which do not have "calendar.txt"
- Fix `transfer_times` function with updated dodgr `match_pts_to_verts` fn
- Improve estimation of pedestrian transfer times
- Fix transfer times when GTFS feed extends beyond bounds of provided network
- Bug fix in `gtfs_route_headway()` function (#94; thanks to @zamirD123)
- Bug fix in `gtfs_traveltimes()` to remove trips ending at start (#99; thanks to @viajerus)


---

# v 0.0.5

Major changes:

- Add new `gtfs_traveltimes` function and deprecate `gtfs_isochrone`

Minor changes:

- All main functions now use a `grep_fixed` parameter to enable finer control
  over station name matching; thanks to @polettif via #66 for the idea.
- That also includes a check to ensure matched stations are sufficiently close,
  which in turn requires `geodist` to be moved from `Suggests` to `Imports`.
- `route_pattern` arguments (to `gtfs_route/isochrone/timetable()` functions)
  can now be used to exclude specified patterns by prefixing them with "!" (see
  #53)
- The `berlin_gtfs_to_zip()` function now returns the path to the GTFS zip file
  it creates.
- Fix bug with `max_transfers` parameter of `gtfs_route()` function (see #47)
- Fix bug when column names do not exactly match expected values (#70; thanks
  to @AlexandraKapp)

---

# v 0.0.4

Major changes:

- New function, `gtfs_route_headway` to calculate headways for entire routes
  between any nominated points (see #43)
- Important bug fix that prevents routes including stops that are not part of
  actual route


---

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
