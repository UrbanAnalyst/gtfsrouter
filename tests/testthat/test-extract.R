context ("summary")

test_all <- (identical (Sys.getenv ("MPADGE_LOCAL"), "true") ||
    identical (Sys.getenv ("GITHUB_JOB"), "test-coverage"))

nthr <- data.table::setDTthreads (1L)

test_that ("extract non gtfs", {
    f <- fs::path (fs::path_temp (), "junk.txt")
    con <- file (f)
    writeLines ("blah", con)
    close (con)
    fz <- fs::path (fs::path_temp (), "vbb.zip")
    if (fs::file_exists (fz)) {
        chk <- fs::file_delete (fz)
    }
    chk <- zip (fz, file = f)

    msg <- paste0 (fz, " does not appear to be a GTFS file")
    if (test_all) { # windows paths get mucked up
        expect_error (g <- extract_gtfs (fz), msg)
    }
    invisible (fs::file_delete (fz))
})

test_that ("extract", {
    berlin_gtfs_to_zip ()
    f <- fs::path (fs::path_temp (), "vbb.zip")
    expect_true (fs::file_exists (f))
    expect_message (g <- extract_gtfs (f, quiet = FALSE))

    # remove calendar and transfers from feed:
    unzip (fs::path (fs::path_temp (), "vbb.zip"),
        exdir = fs::path_temp (),
        junkpaths = TRUE
    )
    froutes <- fs::path (fs::path_temp (), "routes.txt")
    ftrips <- fs::path (fs::path_temp (), "trips.txt")
    fstop_times <- fs::path (fs::path_temp (), "stop_times.txt")
    fstops <- fs::path (fs::path_temp (), "stops.txt")
    ftransfers <- fs::path (fs::path_temp (), "transfers.txt")
    fcalendar <- fs::path (fs::path_temp (), "calendar.txt")
    f_cut <- fs::path (fs::path_temp (), "vbb_cut.zip")

    chk <- zip (f_cut,
        file = c (
            froutes, ftrips, fstop_times, fstops,
            fcalendar
        )
    )
    expect_warning (
        g <- extract_gtfs (f_cut),
        "This feed contains no transfers.txt"
    )

    x <- capture.output (summary (g))
    expect_equal (length (x), 2)
    nms <- strsplit (x [1], "[[:space:]]+") [[1]]
    nms <- nms [which (!nms == "")]
    vals <- as.numeric (strsplit (x [2], "[[:space:]]+") [[1]])
    vals <- vals [!is.na (vals)]
    names (vals) <- nms
    expect_identical (vals, vapply (g, nrow, numeric (1)))
    expect_true (!"transfers" %in% names (vals))
    invisible (fs::file_delete (f_cut))

    chk <- zip (f_cut,
        file = c (
            froutes, ftrips, fstop_times, fstops,
            ftransfers
        )
    )
    # feed contains no calendar.txt, but should still read:
    expect_silent (g <- extract_gtfs (f_cut, quiet = TRUE))

    x <- capture.output (summary (g))
    expect_equal (length (x), 2)
    nms <- strsplit (x [1], "[[:space:]]+") [[1]]
    nms <- nms [which (!nms == "")]
    vals <- as.numeric (strsplit (x [2], "[[:space:]]+") [[1]])
    vals <- vals [!is.na (vals)]
    names (vals) <- nms
    expect_identical (vals, vapply (g, nrow, numeric (1)))
    expect_true (!"calendar" %in% names (vals))
    invisible (fs::file_delete (f_cut))
})

test_that ("summary", {
    berlin_gtfs_to_zip ()
    f <- fs::path (fs::path_temp (), "vbb.zip")
    expect_true (fs::file_exists (f))
    expect_silent (g <- extract_gtfs (f, quiet = TRUE))

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
    f <- fs::path (fs::path_temp (), "vbb.zip")
    expect_true (fs::file_exists (f))
    expect_silent (g <- extract_gtfs (f, quiet = TRUE))
    gt <- gtfs_timetable (g, day = 3)

    x <- capture.output (summary (gt))
    # expect_equal (length (x), 2)
    nms <- strsplit (x [1], "[[:space:]]+") [[1]]
    nms <- nms [which (!nms == "")]
    vals <- as.numeric (strsplit (x [2], "[[:space:]]+") [[1]])
    vals <- vals [!is.na (vals)]
    names (vals) <- nms
    # expect_identical (vals, vapply (gt, nrow, numeric (1)))
})

# CRAN submission attempts were reject because examples had "CPU time > 2.5
# times elapsed time". This was addressed via #109 by switching off most
# examples. This is the last one which still actually runs, with this test
# hopefully catching any likely reasons for rejection.

data.table::setDTthreads (nthr)

skip_on_cran ()
skip_if (TRUE)
test_that ("cpu time", {

    test <- function () {
        berlin_gtfs_to_zip ()
        f <- fs::path (fs::path_temp (), "vbb.zip")
        gtfs <- extract_gtfs (f)
    }
    st <- system.time (test ())
    st_ratio <- st [1] / st [3]
    expect_true (st_ratio < 1)
})
