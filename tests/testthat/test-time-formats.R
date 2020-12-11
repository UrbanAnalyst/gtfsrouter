context("time formats")

test_all <- (identical (Sys.getenv ("MPADGE_LOCAL"), "true") |
             identical (Sys.getenv ("TRAVIS"), "true"))


test_that("convert-time", {
              berlin_gtfs_to_zip ()
              f <- file.path (tempdir (), "vbb.zip")
              expect_true (file.exists (f))
              expect_silent (g <- extract_gtfs (f, quiet = TRUE))
              expect_silent (gt <- gtfs_timetable (g, quiet = TRUE))
              days <- c ("monday", "tuesday", "wednesday", "thursday",
                         "friday", "saturday", "sunday")
              day <- days [as.integer (strftime (Sys.time (), "%u"))]
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

test_that ("date param", {
  berlin_gtfs_to_zip ()
  f <- file.path (tempdir (), "vbb.zip")
  expect_true (file.exists (f))
  expect_silent (g <- extract_gtfs (f, quiet = TRUE))

  # date not in feed
  expect_error (gt <- gtfs_timetable (g, date = 20180128),
                "date does not match any values in the provided GTFS data")

  # wrong date format
  expect_error (gt <- gtfs_timetable (g, date = 1234),
                "Date is not provided in the proper format of yyyymmdd")
  expect_error (gt <- gtfs_timetable (g, date = "abc"),
                "Date is not provided in the proper format of yyyymmdd")

  gt_day <- gtfs_timetable (g, day = "Monday", quiet = TRUE)
  g$calendar_dates <- data.table::data.table (service_id = "1",
                                              date = 20190128,
                                              exception_type = 1)
  g$calendar <- g$calendar[service_id != 1]
  expect_silent (gt <- gtfs_timetable (g, date = 20190128, quiet = TRUE))
  expect_identical(gt_day$timetable, gt$timetable)

  # sunday added to calendar_dates
  g$calendar_dates <- data.table::data.table (service_id = "1",
                                              date = 2019017,
                                              exception_type = 1)
  expect_silent (gt <- gtfs_timetable (g, date = 20190127, quiet = TRUE))
  expect_false(identical(gt_day$timetable, gt$timetable))
})
