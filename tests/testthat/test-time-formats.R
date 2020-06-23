context("time formats")

test_all <- (identical (Sys.getenv ("MPADGE_LOCAL"), "true") |
             identical (Sys.getenv ("TRAVIS"), "true"))


test_that("convert-time", {
              berlin_gtfs_to_zip ()
              f <- file.path (tempdir (), "vbb.zip")
              expect_true (file.exists (f))
              expect_silent (g <- extract_gtfs (f, quiet = TRUE))
              expect_silent (gt <- gtfs_timetable (g, quiet = TRUE))
              day <- strftime (Sys.time (), "%A")
              msg <- paste0 ("Day not specified; extracting timetable for ",
                             day)
              expect_message (gt <- gtfs_timetable (g, quiet = FALSE), msg)
              from <- "Schonlein"
              to <- "Berlin Hauptbahnhof"
              start_time <- 12 * 3600 + 120 # 12:02 in seconds
              expect_silent (route1 <- gtfs_route (gt, from = from, to = to,
                                                  start_time = start_time,
                                                  quiet = TRUE))
              start_time <- hms::hms (0, 2, 12)
              expect_silent (route2 <- gtfs_route (gt, from = from, to = to,
                                                  start_time = start_time,
                                                  quiet = TRUE))
              expect_identical (route1, route2)

              start_time <- lubridate::hms ("12:2:0")
              expect_silent (route3 <- gtfs_route (gt, from = from, to = to,
                                                  start_time = start_time,
                                                  quiet = TRUE))
              expect_identical (route1, route3)

              start_time <- c (12, 2)
              expect_silent (route4 <- gtfs_route (gt, from = from, to = to,
                                                  start_time = start_time,
                                                  quiet = TRUE))
              expect_identical (route1, route4)

              start_time <- c (12, 2, 0)
              expect_silent (route5 <- gtfs_route (gt, from = from, to = to,
                                                  start_time = start_time,
                                                  quiet = TRUE))
              expect_identical (route1, route5)

              expect_silent (route6 <- gtfs_route (gt, from = from, to = to,
                                                  start_time = "12:02:00",
                                                  quiet = TRUE))
              expect_identical (route1, route6)

              expect_silent (route7 <- gtfs_route (gt, from = from, to = to,
                                                  start_time = "12:02",
                                                  quiet = TRUE))
              expect_identical (route1, route7)

              # ------- errors
              start_time <- c (12, 2, 0, 0)
              expect_error (route6 <- gtfs_route (gt, from = from, to = to,
                                                  start_time = start_time,
                                                  quiet = TRUE),
                            "Don't know how to parse time vectors of length 4")

              expect_error (route6 <- gtfs_route (gt, from = from, to = to,
                                                  start_time = "blah",
                                                  quiet = TRUE),
                            "Unrecognized time format")
             })

test_that ("day param", {
              berlin_gtfs_to_zip ()
              f <- file.path (tempdir (), "vbb.zip")
              expect_true (file.exists (f))
              expect_silent (g <- extract_gtfs (f, quiet = TRUE))
              expect_silent (gt <- gtfs_timetable (g, quiet = TRUE))
              expect_silent (gt <- gtfs_timetable (g, 1, quiet = FALSE))
              expect_error (gt <- gtfs_timetable (g, day = 1.1),
                            "day must be an integer value")
              #expect_error (gt <- gtfs_timetable (g, day = 10),
              #              "numeric days must be between 1 (Sun) and 7 (Sat)")
              expect_error (gt <- gtfs_timetable (g, day = NA),
                            "day must be a day of the week")
             })
