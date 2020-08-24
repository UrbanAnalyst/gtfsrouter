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
              #if (test_all)
              #    expect_error (g <- extract_gtfs (f))

              berlin_gtfs_to_zip ()
              f <- file.path (tempdir (), "vbb.zip")
              expect_true (file.exists (f))
              expect_silent (g <- extract_gtfs (f, quiet = TRUE))
              expect_is (g, c ("gtfs", "list"))
              expect_true (all (sapply (g, function (i)
                                        is (i, "data.table"))))
              nms <-  c ("calendar", "routes", "trips",
                         "stop_times", "stops", "transfers")
              expect_equal (names (g), nms)

              files <- file.path (tempdir (), paste0 (nms, ".txt"))
              #files <- files [-1]
              for (f in files)
                  writeLines ("a", f)
              f2 <- file.path (tempdir (), "vbb2.zip")
              zip (f2, files)
              if (test_all)
                  expect_error (g <- extract_gtfs (f2, quiet = TRUE),
                                paste0 (f2, " does not appear to be a GTFS file"))
})

test_that ("timetable", {
              f <- file.path (tempdir (), "vbb.zip")
              expect_true (file.exists (f))
              expect_silent (g <- extract_gtfs (f, quiet = TRUE))
              expect_silent (gt <- gtfs_timetable (g, day = 3, quiet = TRUE))
              expect_false (identical (g, gt))
              expect_silent (gt2 <- gtfs_timetable (gt, day = 3))
              expect_identical (gt, gt2)
              expect_true (length (gt) > length (g))

              expect_true (nrow (gt$stop_times) < nrow (g$stop_times))
              expect_identical (g$stops, gt$stops)
              # stations in transfers are changed to integer indices:
              expect_true (!identical (g$transfers, gt$transfers))
              expect_true (nrow (gt$trips) < nrow (g$trips))
              expect_identical (g$routes, gt$routes)

              if (test_all) { # this fails on appveyor, so switch off on CRAN too just to be safe
                  expect_equal (names (gt), c ("calendar", "routes", "trips",
                                               "stop_times", "stops", "transfers",
                                               "timetable", "stop_ids", "trip_ids"))
              }
              expect_equal (gt$n_stations, nrow (gt$stations))
              expect_equal (gt$n_trips, nrow (gt$trip_numbers))
})

test_that("route", {
              f <- file.path (tempdir (), "vbb.zip")
              expect_true (file.exists (f))
              expect_silent (g <- extract_gtfs (f, quiet = TRUE))
              expect_silent (gt <- gtfs_timetable (g, day = 3, quiet = TRUE))
              from <- "Schonlein"
              to <- "Berlin Hauptbahnhof"
              start_time <- 12 * 3600 + 1200 # 12:20
              expect_silent (route <- gtfs_route (gt, from = from, to = to,
                                                  start_time = start_time))
              expect_is (route, "data.frame")
              expect_equal (ncol (route), 5)
              expect_equal (names (route), c ("route_name", "trip_name",
                                              "stop_name",
                                              "arrival_time", "departure_time"))
              dep_t <- hms::parse_hms (route$departure_time)
              expect_true (all (diff (dep_t) > 0))
              arr_t <- hms::parse_hms (route$arrival_time)
              expect_true (all (diff (arr_t) > 0))

              expect_silent (route2 <- gtfs_route (gt, from = from, to = to,
                                                   start_time = start_time,
                                                   include_ids = TRUE))
              expect_true (!identical (route, route2))
              expect_is (route2, "data.frame")
              expect_equal (ncol (route2), 8)
              expect_equal (names (route2), c ("route_id", "route_name",
                                               "trip_id", "trip_name",
                                               "stop_id", "stop_name",
                                               "arrival_time", "departure_time"))

              # test data only go until 13:00, so:
              expect_error (route <- gtfs_route (gt, from = from, to = to,
                                                 start_time = 14 * 3600),
                            "There are no scheduled services after that time")
})

test_that("route without timetable", {
              f <- file.path (tempdir (), "vbb.zip")
              expect_true (file.exists (f))
              expect_silent (g <- extract_gtfs (f, quiet = TRUE))
              expect_silent (gt <- gtfs_timetable (g, day = 3, quiet = TRUE))
              from <- "Schonlein"
              to <- "Berlin Hauptbahnhof"
              start_time <- 12 * 3600 + 120 # 12:02
              expect_silent (route <- gtfs_route (gt, from = from, to = to,
                                                  start_time = start_time,
                                                  quiet = TRUE))
              expect_silent (route2 <- gtfs_route (g, from = from, to = to,
                                                  start_time = start_time,
                                                  day = 3,
                                                  quiet = TRUE))
              expect_identical (route, route2)
})

test_that ("route_pattern", {
               f <- file.path (tempdir (), "vbb.zip")
               expect_true (file.exists (f))
               expect_silent (g <- extract_gtfs (f, quiet = TRUE))
               expect_silent (gt <- gtfs_timetable (g, day = 3,
                                                    route_pattern = "^S",
                                                    quiet = TRUE))
               from <- "Schonlein" # U-bahn station, not "S"
               to <- "Berlin Hauptbahnhof"
               start_time <- 12 * 3600 + 120 # 12:02
               expect_error (route <- gtfs_route (gt, from = from, to = to,
                                                  start_time = start_time),
                             "Schonlein does not match any stations")

               expect_silent (gt <- gtfs_timetable (g, day = 3,
                                                    route_pattern = "^U",
                                                    quiet = TRUE))
               expect_null (gtfs_route (gt, from = from, to = to,
                                      start_time = start_time))
               # There is no U-bahn connection all the way to Hbf
})

test_that ("earliest_arrival", {
               f <- file.path (tempdir (), "vbb.zip")
               expect_silent (g <- extract_gtfs (f, quiet = TRUE))
               from <- "Schonlein" # U-bahn station, not "S"
               to <- "Berlin Hauptbahnhof"
               start_time <- 12 * 3600 + 120 # 12:02
               expect_silent (route <- gtfs_route (g, from = from, to = to,
                                                   start_time = start_time,
                                                   day = 3))
               expect_silent (route2 <- gtfs_route (g, from = from, to = to,
                                                    start_time = start_time,
                                                    day = 3,
                                                    earliest_arrival = FALSE))
               # These 2 are identical because the earliest departure is the
               # earliest arrival in this case:
               expect_identical (route, route2)
})

test_that ("max_transfers", {
               f <- file.path (tempdir (), "vbb.zip")
               expect_silent (g <- extract_gtfs (f, quiet = TRUE))
               from <- "Innsbrucker Platz" # U-bahn station, not "S"
               to <- "Alexanderplatz"
               start_time <- 12 * 3600 + 120 # 12:02
               expect_silent (route <- gtfs_route (g, from = from, to = to,
                                                    start_time = start_time,
                                                    day = 3,
                                                    max_transfers = 2))
               expect_null (route <- gtfs_route (g, from = from, to = to,
                                     start_time = start_time,
                                     day = 3,
                                     max_transfers = 1)) # no route found
})

test_that ("multiple routes", {
               f <- file.path (tempdir (), "vbb.zip")
               expect_silent (g <- extract_gtfs (f, quiet = TRUE))
               from <- c ("Schonlein",  "Innsbrucker Platz")
               to <- c ("Berlin Hauptbahnhof", "Alexanderplatz")
               start_time <- 12 * 3600 + 120 # 12:02
               expect_silent (route <- gtfs_route (g, from = from, to = to,
                                                    start_time = start_time,
                                                    day = 3))
               expect_is (route, "list")
               expect_length (route, 2)
               expect_true (all (vapply (route, function (i) is.data.frame (i), logical (1))))

               # convert (from, to) to matrices of lon-lat:
               from <- vapply (from, function (i) grep (i, g$stops$stop_name) [1], integer (1))
               to <- vapply (to, function (i) grep (i, g$stops$stop_name) [1], integer (1))
               from <- g$stops [from, c ("stop_lon", "stop_lat")]
               to <- g$stops [to, c ("stop_lon", "stop_lat")]
               expect_silent (route2 <- gtfs_route (g, from = from, to = to,
                                                    start_time = start_time,
                                                    day = 3))

               # these are not identical, because the first only greps
               # "Alexanderplatz" and so returns all U+S lines, while the 2nd
               # gets `grep (...)[1]`, and so only matches one of these, which
               # happens to be the S Bhf. 
               #expect_identical (unname (route), unname (route2))
})
