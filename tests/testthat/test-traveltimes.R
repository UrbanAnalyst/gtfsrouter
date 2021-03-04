context("traveltimes")

test_all <- (identical (Sys.getenv ("MPADGE_LOCAL"), "true") |
             identical (Sys.getenv ("GITHUB_WORKFLOW"), "test-coverage"))

test_that("gtfs_traveltimes", {
              berlin_gtfs_to_zip ()
              f <- file.path (tempdir (), "vbb.zip")
              expect_silent (g <- extract_gtfs (f, quiet = TRUE))
              expect_silent (g2 <- gtfs_timetable (g, day = 3, quiet = TRUE))

              from <- "Alexanderplatz"
              start_times <- 8 * 3600 + c (0, 60) * 60 # 8:00-9:00
              res <- gtfs_traveltimes (g2, from, start_times)
              expect_is (res, "data.frame")
              expect_equal (ncol (res), 7)

              expect_identical (names (res), c ("start_time",
                                                "duration",
                                                "ntransfers",
                                                "stop_id",
                                                "stop_name",
                                                "stop_lon",
                                                "stop_lat"))
             })
