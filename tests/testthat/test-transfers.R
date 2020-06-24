context("transfers")

test_all <- (identical (Sys.getenv ("MPADGE_LOCAL"), "true") |
             identical (Sys.getenv ("TRAVIS"), "true"))

test_that ("transfers works", {
              berlin_gtfs_to_zip ()
              f <- file.path (tempdir (), "vbb.zip")
              expect_silent (g <- extract_gtfs (f, quiet = TRUE))

              expect_message (x200 <- gtfs_transfer_table (g,
                                                           d_limit = 200,
                                                           min_transfer_time = 0))

              expect_is (x200, "data.table")
              expect_identical (names (x200), c ("from_stop_id",
                                                 "to_stop_id",
                                                 "transfer_type",
                                                 "min_transfer_time"))
              expect_true (all (x200$transfer_type == 2))
              expect_equal (min (x200$min_transfer_time), 0)

              expect_message (x500 <- gtfs_transfer_table (g,
                                                           d_limit = 500,
                                                           min_transfer_time = 0))

              expect_true (nrow (x500) > nrow (x200))
              expect_true (all (x200$from_stop_id %in% x500$from_stop_id))
              expect_true (all (x200$to_stop_id %in% x500$to_stop_id))
              expect_false (all (x500$from_stop_id %in% x200$from_stop_id))
              expect_false (all (x500$to_stop_id %in% x200$to_stop_id))
})
