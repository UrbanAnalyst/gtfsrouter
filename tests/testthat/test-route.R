context("route")

test_all <- (identical (Sys.getenv ("MPADGE_LOCAL"), "true") |
             identical (Sys.getenv ("TRAVIS"), "true"))


test_that("extract", {
              expect_error (g <- extract_gtfs (),
                            "filename must be given")
              expect_error (g <- extract_gtfs ("non-existent-file.zip"),
                            "filename non-existent-file.zip does not exist")
              f <- file.path (tempdir (), "junk")
              cat ("junk", file = f)
              # The following test fails on appveyor with this message:
              # Expected match: "zip file 'C:/Users/appveyor/AppData/Local/Temp/1\\Rtmp8aCxU2/junk' cannot be opened"
              # Actual message: "zip file 'C:/Users/appveyor/AppData/Local/Temp/1\\Rtmp8aCxU2/junk' cannot be opened"
              # --- and yes, those two are in fact identical! Therefore:
              if (Sys.getenv ("APPVEYOR") == "") # appevyor sets this envvar
                  expect_error (g <- extract_gtfs (f),
                                paste0 ("zip file '", f, "' cannot be opened"))

              berlin_gtfs_to_zip ()
              f <- file.path (tempdir (), "vbb.zip")
              expect_true (file.exists (f))
              expect_silent (g <- extract_gtfs (f))
              expect_is (g, "list")
              expect_true (all (sapply (g, function (i)
                                        is (i, "data.table"))))
              expect_equal (names (g), c ("stop_times", "stops", "transfers",
                                          "trip_table", "routes"))
})

test_that ("timetable", {
              f <- file.path (tempdir (), "vbb.zip")
              expect_true (file.exists (f))
              expect_silent (g <- extract_gtfs (f))
              expect_silent (gt <- gtfs_timetable (g))
              expect_false (identical (g, gt))
              expect_silent (gt2 <- gtfs_timetable (gt))
              expect_identical (gt, gt2)
              expect_true (length (gt) > length (g))

              expect_identical (g$stop_times, gt$stop_times)
              expect_identical (g$stops, gt$stops)
              expect_identical (g$stop_times, gt$stop_times)
              # stations in transfers are changed to integer indices:
              expect_true (!identical (g$transfers, gt$transfers))
              expect_identical (g$trip_table, gt$trip_table)
              expect_identical (g$routes, gt$routes)

              expect_equal (names (gt), c ("stop_times", "stops", "transfers",
                                          "trip_table", "routes", "timetable",
                                          "stations", "trips", "stop_ids",
                                          "n_stations", "n_trips"))
              expect_equal (gt$n_stations, 871)
              expect_equal (gt$n_trips, 1933)
})

test_that("route", {
              f <- file.path (tempdir (), "vbb.zip")
              expect_true (file.exists (f))
              expect_silent (g <- extract_gtfs (f))
              expect_silent (gt <- gtfs_timetable (g))
              from <- "Schonlein"
              to <- "Berlin Hauptbahnhof"
              start_time <- 12 * 3600 + 120 # 12:02
              expect_silent (route <- gtfs_route (gt, from = from, to = to,
                                                  start_time = start_time))
              expect_is (route, "data.frame")
              expect_equal (names (route), c ("route", "stop", "departure_time",
                                              "arrival_time"))
              dep_t <- hms::parse_hms (route$departure_time)
              expect_true (all (diff (dep_t) > 0))
              arr_t <- hms::parse_hms (route$arrival_time)
              expect_true (all (diff (arr_t) > 0))

              # test data only go until 13:00, so:
              expect_error (route <- gtfs_route (gt, from = from, to = to,
                                                 start_time = 14 * 3600),
                            "There are no scheduled services after that time")
})

test_that("route without timetable", {
              f <- file.path (tempdir (), "vbb.zip")
              expect_true (file.exists (f))
              expect_silent (g <- extract_gtfs (f))
              expect_silent (gt <- gtfs_timetable (g))
              from <- "Schonlein"
              to <- "Berlin Hauptbahnhof"
              start_time <- 12 * 3600 + 120 # 12:02
              expect_silent (route <- gtfs_route (gt, from = from, to = to,
                                                  start_time = start_time))
              expect_silent (route2 <- gtfs_route (g, from = from, to = to,
                                                  start_time = start_time))
              expect_identical (route, route2)
})
