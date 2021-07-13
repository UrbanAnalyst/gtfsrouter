context("transfers")

test_all <- (identical (Sys.getenv ("MPADGE_LOCAL"), "true") |
             identical (Sys.getenv ("GITHUB_WORKFLOW"), "test-coverage"))

test_that ("transfers works", {
              berlin_gtfs_to_zip ()
              f <- file.path (tempdir (), "vbb.zip")
              expect_silent (g <- extract_gtfs (f, quiet = TRUE))

              expect_silent (
                    g200 <- gtfs_transfer_table (g,
                                                 d_limit = 200,
                                                 min_transfer_time = 0))

              expect_is (g200, "gtfs")
              tr200 <- g200$transfers
              expect_is (tr200, "data.table")
              expect_identical (names (tr200),
                                c ("from_stop_id",
                                   "to_stop_id",
                                   "transfer_type",
                                   "min_transfer_time",
                                   "from_route_id",
                                   "to_route_id",
                                   "from_trip_id",
                                   "to_trip_id"))
              expect_true (all (tr200$transfer_type %in% c (1, 2)))
              expect_true (nrow (tr200) > nrow (g$transfers))

              expect_silent (
                    g500 <- gtfs_transfer_table (g,
                                                 d_limit = 500,
                                                 min_transfer_time = 0))

              tr500 <- g500$transfers
              expect_true (nrow (tr500) > nrow (tr200))
              expect_true (all (tr200$from_stop_id %in% tr500$from_stop_id))
              expect_true (all (tr200$to_stop_id %in% tr500$to_stop_id))
              expect_true (all (tr500$from_stop_id %in% tr200$from_stop_id))
              expect_true (all (tr500$to_stop_id %in% tr200$to_stop_id))
              expect_true (mean (tr500$min_transfer_time) >
                           mean (tr200$min_transfer_time))
})
