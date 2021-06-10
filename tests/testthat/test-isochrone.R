context("isochrone")

test_all <- (identical (Sys.getenv ("MPADGE_LOCAL"), "true") |
             identical (Sys.getenv ("GITHUB_WORKFLOW"), "test-coverage"))

is_test_workflow <- identical (Sys.getenv ("GITHUB_WORKFLOW"), "test-coverage")

if (!is_test_workflow) {

test_that("gtfs_isochrone", {
              berlin_gtfs_to_zip ()
              f <- file.path (tempdir (), "vbb.zip")
              expect_true (file.exists (f))
              expect_silent (g <- extract_gtfs (f, quiet = TRUE))
              expect_silent (g2 <- gtfs_timetable (g, day = 3, quiet = TRUE))
              start_time <- 12 * 3600 + 1200
              end_time <- start_time + 10 * 60
              expect_warning (
                  ic <- gtfs_isochrone (g2,
                                        from = "S+U Zoologischer Garten Bhf",
                                        start_time = start_time,
                                        end_time = end_time),
                              "'gtfs_isochrone' is deprecated")
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
              #expect_identical (as.character (classes),
              #                  c ("sf", "sf", "sf", "sfc_LINESTRING", "sf",
              #                     "integer", "integer"))
              cnames <- c ("stop_name", "stop_id", "departure", "arrival",
                           "duration", "transfers", "geometry")
              expect_identical (names (ic$mid_points), cnames)
              expect_identical (names (ic$end_points), cnames)

              expect_warning (
                  ic2 <- gtfs_isochrone (g,
                                        from = "S+U Zoologischer Garten Bhf",
                                        start_time = 12 * 3600 + 1200,
                                        end_time = 12 * 3600 + 1200 + 10 * 60,
                                        day = 3),
                              "'gtfs_isochrone' is deprecated")
              expect_identical (ic, ic2)
             })

test_that("isochrone errors", {
              berlin_gtfs_to_zip ()
              f <- file.path (tempdir (), "vbb.zip")
              expect_true (file.exists (f))
              expect_silent (g <- extract_gtfs (f, quiet = TRUE))
              expect_silent (g <- gtfs_timetable (g, quiet = TRUE))
              expect_error (
                    suppressWarnings ( # deprecation warning
                      ic <- gtfs_isochrone (g,
                                            from = "Schonlein",
                                            start_time = 14 * 3600 + 1200,
                                            end_time = 14 * 3600 + 2400)),
                            "There are no scheduled services after that time")
             })
} # end if !is_test_workflow
