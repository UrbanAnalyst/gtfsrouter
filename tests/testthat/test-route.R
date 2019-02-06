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

test_that ("timetable", {
              f <- file.path (tempdir (), "vbb.zip")
              expect_true (file.exists (f))
              expect_silent (g <- extract_gtfs (f))
              expect_silent (gt <- gtfs_timetable (g))
              expect_false (identical (g, gt))
              expect_silent (gt2 <- gtfs_timetable (gt))
              expect_identical (gt, gt2)
              expect_true (length (gt) > length (g))
              index <- which (names (gt) %in% names (g))
              for (i in index)
                  expect_identical (g [[i]], gt [[i]])
              expect_equal (names (gt), c ("stop_times", "stops", "transfers",
                                          "trip_table", "routes", "timetable",
                                          "stations", "trip", "stop_ids",
                                          "n_stations", "n_trips"))
              expect_equal (gt$n_stations, 871)
              expect_equal (gt$n_trips, 1933)
})

test_that("route", {
              f <- file.path (tempdir (), "vbb.zip")
              expect_true (file.exists (f))
              expect_silent (g <- extract_gtfs (f))
})
