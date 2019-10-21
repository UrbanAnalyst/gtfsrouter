context("summary")

test_that ("extract non gtfs", {
              f <- file.path (tempdir (), "junk.txt")
              con <- file (f)
              writeLines ("blah", con)
              close (con)
              fz <- file.path (tempdir (), "vbb.zip")
              chk <- zip (fz, file = f)

              msg <- paste0 (fz, " does not appear to be a GTFS file")
              expect_error (g <- extract_gtfs (fz), msg)
})

test_that ("extract", {
              berlin_gtfs_to_zip ()
              f <- file.path (tempdir (), "vbb.zip")
              expect_true (file.exists (f))
              expect_silent (g <- extract_gtfs (f))

              # remove calendar and transfers from feed:
              unzip (file.path (tempdir (), "vbb.zip"), exdir = tempdir (),
                     junkpaths = TRUE)
              froutes <- file.path (tempdir (), "routes.txt")
              ftrips <- file.path (tempdir (), "trips.txt")
              fstop_times <- file.path (tempdir (), "stop_times.txt")
              fstops <- file.path (tempdir (), "stops.txt")
              ftransfers <- file.path (tempdir (), "transfers.txt")
              fcalendar <- file.path (tempdir (), "calendar.txt")
              f_cut <- file.path (tempdir (), "vbb_cut.zip")

              chk <- zip (f_cut,
                          file = c (froutes, ftrips, fstop_times, fstops,
                                    fcalendar))
              expect_warning (g <- extract_gtfs (f_cut),
                              "This feed contains no transfers.txt")

              x <- capture.output (summary (g))
              expect_equal (length (x), 2)
              nms <- strsplit (x [1], "[[:space:]]+") [[1]]
              nms <- nms [which (!nms == "")]
              vals <- as.numeric (strsplit (x [2], "[[:space:]]+") [[1]])
              vals <- vals [!is.na (vals)]
              names (vals) <- nms
              expect_identical (vals, vapply (g, nrow, numeric (1)))
              expect_true (!"transfers" %in% names (vals))
              invisible (file.remove (f_cut))

              chk <- zip (f_cut,
                          file = c (froutes, ftrips, fstop_times, fstops,
                                    ftransfers))
              # feed contains no calendar.txt, but should still read:
              expect_silent (g <- extract_gtfs (f_cut))

              x <- capture.output (summary (g))
              expect_equal (length (x), 2)
              nms <- strsplit (x [1], "[[:space:]]+") [[1]]
              nms <- nms [which (!nms == "")]
              vals <- as.numeric (strsplit (x [2], "[[:space:]]+") [[1]])
              vals <- vals [!is.na (vals)]
              names (vals) <- nms
              expect_identical (vals, vapply (g, nrow, numeric (1)))
              expect_true (!"calendar" %in% names (vals))
              invisible (file.remove (f_cut))
})

test_that("summary", {
              berlin_gtfs_to_zip ()
              f <- file.path (tempdir (), "vbb.zip")
              expect_true (file.exists (f))
              expect_silent (g <- extract_gtfs (f))

              x <- capture.output (summary (g))
              expect_equal (length (x), 2)
              nms <- strsplit (x [1], "[[:space:]]+") [[1]]
              nms <- nms [which (!nms == "")]
              vals <- as.numeric (strsplit (x [2], "[[:space:]]+") [[1]])
              vals <- vals [!is.na (vals)]
              names (vals) <- nms
              expect_identical (vals, vapply (g, nrow, numeric (1)))
})

test_that ("timetable summary", {
              berlin_gtfs_to_zip ()
              f <- file.path (tempdir (), "vbb.zip")
              expect_true (file.exists (f))
              expect_silent (g <- extract_gtfs (f))
              gt <- gtfs_timetable (g, day = 3)

              x <- capture.output (summary (gt))
              #expect_equal (length (x), 2)
              nms <- strsplit (x [1], "[[:space:]]+") [[1]]
              nms <- nms [which (!nms == "")]
              vals <- as.numeric (strsplit (x [2], "[[:space:]]+") [[1]])
              vals <- vals [!is.na (vals)]
              names (vals) <- nms
              #expect_identical (vals, vapply (gt, nrow, numeric (1)))
})
