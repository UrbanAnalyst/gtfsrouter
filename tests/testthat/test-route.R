context("route")

test_all <- (identical (Sys.getenv ("MPADGE_LOCAL"), "true") |
             identical (Sys.getenv ("TRAVIS"), "true"))

source ("../make-zip.R")

test_that("extract", {
              f <- file.path (tempdir (), "vbb.zip")
              expect_true (file.exists (f))
              expect_silent (g <- extract_gtfs (f))
              expect_is (g, "list")
              expect_true (all (sapply (g, function (i)
                                        is (i, "data.table"))))
              expect_equal (names (g), c ("stop_times", "stops", "transfers",
                                          "trip_table", "routes"))
})
