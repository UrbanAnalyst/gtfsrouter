context("time formats")

test_all <- (identical (Sys.getenv ("MPADGE_LOCAL"), "true") |
             identical (Sys.getenv ("TRAVIS"), "true"))


test_that("route", {
              berlin_gtfs_to_zip ()
              f <- file.path (tempdir (), "vbb.zip")
              expect_true (file.exists (f))
              expect_silent (g <- extract_gtfs (f))
              expect_silent (gt <- gtfs_timetable (g))
              from <- "Schonlein"
              to <- "Berlin Hauptbahnhof"
              start_time <- 12 * 3600 + 120 # 12:02 in seconds
              expect_silent (route1 <- gtfs_route (gt, from = from, to = to,
                                                  start_time = start_time))
              start_time <- hms::hms (0, 2, 12)
              expect_silent (route2 <- gtfs_route (gt, from = from, to = to,
                                                  start_time = start_time))
              expect_identical (route1, route2)

              start_time <- lubridate::hms ("12:2:0")
              expect_silent (route3 <- gtfs_route (gt, from = from, to = to,
                                                  start_time = start_time))
              expect_identical (route1, route3)

              start_time <- c (12, 2)
              expect_silent (route4 <- gtfs_route (gt, from = from, to = to,
                                                  start_time = start_time))
              expect_identical (route1, route4)

              start_time <- c (12, 2, 0)
              expect_silent (route5 <- gtfs_route (gt, from = from, to = to,
                                                  start_time = start_time))
              expect_identical (route1, route5)

              start_time <- c (12, 2, 0, 0)
              expect_error (route6 <- gtfs_route (gt, from = from, to = to,
                                                  start_time = start_time),
                            "Don't know how to parse time vectors of length 4")

              expect_error (route6 <- gtfs_route (gt, from = from, to = to,
                                                  start_time = "blah"),
                            "Time is of unknown class")
              expect_error (route6 <- gtfs_route (gt, from = from, to = to,
                                                  start_time = NULL),
                            "Time is of unknown class")
             })
