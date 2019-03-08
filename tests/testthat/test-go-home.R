context("go home")

test_that("go home set up", {
              berlin_gtfs_to_zip()
              f <- file.path (tempdir (), "vbb.zip")
              Sys.setenv ("gtfs_home" = "Innsbrucker Platz")
              Sys.setenv ("gtfs_work" = "Alexanderplatz")
              Sys.setenv ("gtfs_data" = f)
              expect_silent (process_gtfs_local ())
})

test_that ("go home", {
               expect_silent (route1 <- go_home (start_time = "12:00:00"))
               expect_is (route1, "data.frame")
               expect_equal (ncol (route1), 5)
               expect_equal (names (route1), c ("route_name", "trip_name",
                                                "stop_name",
                                                "departure_time", "arrival_time"))

               expect_silent (route2 <- go_home (wait = 3, start_time = "12:00:00"))
               expect_true (!identical (route1, route2))
               expect_true (route1$departure_time [1] < route2$departure_time [1])
})

test_that ("go to work", {
               expect_silent (route1 <- go_home (start_time = "12:00:00"))
               expect_silent (route3 <- go_to_work (start_time = "12:00:00"))
               expect_equal (ncol (route3), 5)
               expect_equal (names (route3), c ("route_name", "trip_name",
                                               "stop_name",
                                               "departure_time", "arrival_time"))
               expect_equal (route3$stop_name [1], route1$stop_name [nrow (route1)])
})
