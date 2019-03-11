context("go home")

is_appveyor <- Sys.getenv ("APPVEYOR") != "" # appevyor sets this envvar
test_all <- (identical (Sys.getenv ("MPADGE_LOCAL"), "true") |
             identical (Sys.getenv ("TRAVIS"), "true"))

test_that("go home set up", {
              if (Sys.getenv ("gtfs_home") == "" |
                  Sys.getenv ("gtfs_work") == "" |
                  Sys.getenv ("gtfs_data") == "")
                  expect_error (process_gtfs_local (),
                                "This function requires environmental variables")
              f <- file.path (tempdir (), "doesnotexist.zip")
              Sys.setenv ("gtfs_home" = "Innsbrucker Platz")
              Sys.setenv ("gtfs_work" = "Alexanderplatz")
              Sys.setenv ("gtfs_data" = f)
              if (test_all)
                  expect_error (process_gtfs_local (),
                                paste0 ("File ", f, " specified by environmental ",
                                        "variable 'gtfs_data' does not exist"))
              berlin_gtfs_to_zip()
              f <- file.path (tempdir (), "vbb.zip")
              Sys.setenv ("gtfs_data" = f)

              expect_error (route1 <- go_home (),
                            paste0 ("This function requires the GTFS data ",
                                    "to be pre-processed"))

              expect_silent (process_gtfs_local ())
})

test_that ("go home", {
               expect_silent (route1 <- go_home (start_time = "12:00:00"))
               expect_is (route1, "data.frame")
               expect_equal (ncol (route1), 5)
               expect_equal (names (route1), c ("route_name", "trip_name",
                                                "stop_name",
                                                "arrival_time", "departure_time"))

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
                                               "arrival_time", "departure_time"))
               expect_equal (route3$stop_name [1], route1$stop_name [nrow (route1)])
})
