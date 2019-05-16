context("summary")

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
              invisible (file.remove (f_cut))

              chk <- zip (f_cut,
                          file = c (froutes, ftrips, fstop_times, fstops,
                                    ftransfers))
              expect_warning (g <- extract_gtfs (f_cut),
                              "This feed contains no calendar.txt")
              invisible (file.remove (f_cut))
})

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
