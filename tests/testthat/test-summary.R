context("summary")

test_that("summary", {
              berlin_gtfs_to_zip ()
              f <- file.path (tempdir (), "vbb.zip")
              expect_true (file.exists (f))
              expect_silent (g <- extract_gtfs (f))
              expect_message (summary (g))
              n <- vapply (g, nrow, numeric (1))
              expect_identical (summary (g), n)
              expect_true (length (summary (g)) == length (g))

              gt <- gtfs_timetable (g, day = 3)
              expect_message (summary (gt))
              nt <- vapply (gt, nrow, numeric (1))
              expect_identical (summary (gt), nt)
              expect_true (length (summary (gt)) >
                           length (summary (g)))
})
