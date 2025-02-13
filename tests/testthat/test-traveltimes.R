context ("traveltimes")

nthr <- data.table::setDTthreads (1L)

berlin_gtfs_to_zip ()
f <- fs::path (fs::path_temp (), "vbb.zip")
g <- extract_gtfs (f, quiet = TRUE)
g2 <- gtfs_timetable (g, day = 3, quiet = TRUE)

test_that ("gtfs_traveltimes", {
    from <- "Alexanderplatz"
    start_times <- c (12, 13) * 3600
    res <- gtfs_traveltimes (g2, from, start_times)
    expect_is (res, "data.frame")
    expect_equal (ncol (res), 7)
    expect_true (nrow (res) > 100)
    expect_true (nrow (res) < nrow (g2$stops))

    expect_identical (names (res), c (
        "start_time",
        "duration",
        "ntransfers",
        "stop_id",
        "stop_name",
        "stop_lon",
        "stop_lat"
    ))
})

test_that ("traveltime errors", {
    from <- "Alexanderplatz"
    start_times <- NULL
    expect_error (
        gtfs_traveltimes (g2, from, start_times),
        "start_time_limits must have exactly two entries"
    )
    start_times <- 1:3
    expect_error (
        gtfs_traveltimes (g2, from, start_times),
        "start_time_limits must have exactly two entries"
    )
    start_times <- c ("a", "b")
    expect_error (
        gtfs_traveltimes (g2, from, start_times),
        "start_time_limits must be a vector of 2 integer"
    )
    start_times <- 2:1
    expect_error (
        gtfs_traveltimes (g2, from, start_times),
        "start_time_limits must be \\(min, max\\) values"
    )

    start_time_limits <- c (43212, 49212)
    expect_error (
        gtfs_traveltimes (g2, from, start_times,
            max_traveltime = -1
        ),
        "max_traveltime must be a single number greater than 0"
    )

    g2$transfers <- NULL
    expect_error (
        gtfs_traveltimes (g2, from, start_times),
        "gtfs must have a transfers table"
    )
})

data.table::setDTthreads (nthr)
