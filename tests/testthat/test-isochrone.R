context("isochrone")

test_all <- (identical (Sys.getenv ("MPADGE_LOCAL"), "true") |
             identical (Sys.getenv ("TRAVIS"), "true"))
is_appveyor <- Sys.getenv ("APPVEYOR") != "" # appevyor sets this envvar


test_that("gtfs_isochrone", {
              berlin_gtfs_to_zip ()
              f <- file.path (tempdir (), "vbb.zip")
              expect_true (file.exists (f))
              expect_silent (g <- extract_gtfs (f))
              expect_silent (g <- gtfs_timetable (g))
              ic <- gtfs_isochrone (g,
                                    from = "Schonlein",
                                    start_time = 12 * 3600 + 600,
                                    end_time = 12 * 3600 + 1800)
              expect_is (ic, "data.frame")
              expect_equal (ncol (ic), 4)
              expect_identical (names (ic), c ("stop_name", "stop_lon",
                                               "stop_lat", "in_isochrone"))
              expect_is (ic$in_isochrone, "logical")
             })

test_that("isochrone-internal", {
              f <- file.path (tempdir (), "vbb.zip")
              expect_true (file.exists (f))
              expect_silent (g <- extract_gtfs (f))
              expect_silent (g <- gtfs_timetable (g))
              x <- gtfs_isochrone (g,
                                   from = "Schonlein",
                                   start_time = 12 * 3600 + 600,
                                   end_time = 12 * 3600 + 1800)
              x_out <- x [which (!x$in_isochrone), ]
              expect_true (nrow (x_out) < nrow (x))
              x <- x [which (x$in_isochrone), ]
              expect_true (nrow (x) < nrow (x_out))
             })
