context("isochrone")

test_all <- (identical (Sys.getenv ("MPADGE_LOCAL"), "true") |
             identical (Sys.getenv ("TRAVIS"), "true"))
is_appveyor <- Sys.getenv ("APPVEYOR") != "" # appevyor sets this envvar


test_that("gtfs_isochrone", {
              berlin_gtfs_to_zip ()
              f <- file.path (tempdir (), "vbb.zip")
              expect_true (file.exists (f))
              expect_silent (g <- extract_gtfs (f))
              expect_silent (g2 <- gtfs_timetable (g, day = 3, quiet = TRUE))
              start_time <- 12 * 3600 + 1200
              end_time <- start_time + 1200
              ic <- gtfs_isochrone (g2,
                                    from = "Schonlein",
                                    start_time = start_time,
                                    end_time = end_time)
              expect_is (ic, c ("gtfs_isochrone", "list"))
              expect_true (ic$start_time > start_time)
              expect_true (ic$end_time > end_time)

              expect_identical (names (ic), c ("start_point",
                                               "mid_points",
                                               "end_points",
                                               "routes",
                                               "hull",
                                               "start_time",
                                               "end_time"))
              classes <- sapply (ic, function (i) class (i) [1])
              expect_identical (as.character (classes),
                                c ("sf", "sf", "sf", "sfc_LINESTRING", "sf",
                                   "numeric", "numeric"))

              ic2 <- gtfs_isochrone (g,
                                    from = "Schonlein",
                                    start_time = 12 * 3600 + 1200,
                                    end_time = 12 * 3600 + 2400,
                                    day = 3)
              expect_identical (ic, ic2)
             })

test_that("isochrone errors", {
              berlin_gtfs_to_zip ()
              f <- file.path (tempdir (), "vbb.zip")
              expect_true (file.exists (f))
              expect_silent (g <- extract_gtfs (f))
              expect_silent (g <- gtfs_timetable (g, quiet = TRUE))
              expect_error (
              ic <- gtfs_isochrone (g,
                                    from = "Schonlein",
                                    start_time = 14 * 3600 + 1200,
                                    end_time = 14 * 3600 + 2400),
                            "There are no scheduled services after that time")
             })

test_that ("isochrones", {
               f <- file.path (tempdir (), "vbb.zip")
               g <- extract_gtfs (f)
               g <- gtfs_timetable (g)
               from <- "Schonlein"
               expect_silent (all_routes <- 
                   gtfs_isochrones (g, from, time_incr = 600, quiet = TRUE))
               expect_is (all_routes, "list")
             })
