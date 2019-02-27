context("route-stops")

test_all <- (identical (Sys.getenv ("MPADGE_LOCAL"), "true") |
             identical (Sys.getenv ("TRAVIS"), "true"))
is_appveyor <- Sys.getenv ("APPVEYOR") != "" # appevyor sets this envvar


test_that("route-stops", {
              berlin_gtfs_to_zip ()
              f <- file.path (tempdir (), "vbb.zip")
              expect_true (file.exists (f))
              expect_silent (g <- extract_gtfs (f))
              route_id <- "10141_109"
              r <- gtfs_route_stops (g, route_id)
              expect_is (r, "list")
              expect_true (length (r) > 1)
              rall <- do.call (rbind, r)
              expect_is (rall, "data.frame")
              expect_equal (ncol (rall), 2)
              expect_identical (names (rall), c ("stop_id", "stop_name"))
             })
