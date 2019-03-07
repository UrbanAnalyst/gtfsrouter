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

test_that ("median isochrones", {
               f <- file.path (tempdir (), "vbb.zip")
               expect_error (timetable <- gtfs_median_timetable (f),
                             "Object must be of class gtfs")
               g <- extract_gtfs (f)
               expect_error (timetable <- gtfs_median_timetable (g),
                             "Object must have a timetable added by gtfs_timetable")
               g <- gtfs_timetable (g, day = 1:7)

               st <- system.time (timetable <- gtfs_median_timetable (g))
               expect_is (timetable, "data.frame")
               expect_equal (ncol (timetable), 8)
               expect_identical (names (timetable),
                                 c ("departure_station", "arrival_station",
                                    "duration_min", "duration_median",
                                    "duration_max", "interval_min",
                                    "interval_median", "interval_max"))

               # Second call uses cached version, so should be faster:
               st2 <- system.time (timetable <- gtfs_median_timetable (g))
               expect_true (st2 [3] < st [3])

               expect_silent (graph <- gtfs_median_graph (timetable, g))
               expect_is (graph, "data.frame")
               expect_equal (ncol (graph), 3)
               expect_identical (names (graph), 
                                 c ("departure_station", "arrival_station",
                                    "duration"))

               expect_silent (d <- gtfs_median_isochrones (graph, station = 100))
               expect_is (d, "integer")
               n <- max (c (graph$departure_station, graph$arrival_station))
               expect_equal (length (d), n)
             })
