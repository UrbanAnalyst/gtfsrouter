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

              hull <- gtfsrouter:::get_ahull (x)
              expect_is (hull, "data.frame")
              expect_equal (ncol (hull), 3)
              expect_identical (names (hull), c ("ind", "x","y"))
              bdry <- sf::st_polygon (list (as.matrix (hull [, 2:3])))
              bdry <- sf::st_sf (sf::st_sfc (bdry, crs = 4326))

              x_sf <- gtfsrouter:::pts_to_sf (x)
              expect_equal (nrow (x_sf), nrow (x))
              expect_equal (ncol (x_sf), 2)
              expect_identical (names (x_sf), c ("stop_name", "geometry"))
              x_out_sf <- gtfsrouter:::pts_to_sf (x_out)
              expect_equal (nrow (x_out_sf), nrow (x_out))
              expect_equal (ncol (x_out_sf), 2)
              expect_identical (names (x_out_sf), c ("stop_name", "geometry"))
             })
