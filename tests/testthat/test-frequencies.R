context("frequencies")

test_that ("not gtfs", {
            no_gtfs <- "a"
            msg <- "selected object does not appear to be a GTFS file"
            expect_error (g <- frequencies_to_stop_times (no_gtfs), msg)
})

test_that ("gtfs without frequencies", {
            berlin_gtfs_to_zip()
            tempfiles <- list.files (tempdir (), full.names = TRUE)
            filename <- tempfiles [grep ("vbb.zip", tempfiles)]
            gtfs <- extract_gtfs (filename)
            
            msg <- "selected gtfs does not contain frequencies"
            expect_error (g <- frequencies_to_stop_times (gtfs), msg)
})


test_that ("gtfs with empty frequencies", {
            berlin_gtfs_to_zip()
            tempfiles <- list.files (tempdir (), full.names = TRUE)
            filename <- tempfiles [grep ("vbb.zip", tempfiles)]
            gtfs <- extract_gtfs (filename)
            
            need_these_columns <- c("trip_id" ,"start_time","end_time","headway_secs")
            gtfs$frequencies <- data.table::data.table()[,`:=`(c(need_these_columns),NA)][0]
            
            msg <- "frequencies table is empty"
            expect_error (g <- frequencies_to_stop_times (gtfs), msg)
})


test_that ("frequencies with missing columns", {
            berlin_gtfs_to_zip()
            tempfiles <- list.files (tempdir (), full.names = TRUE)
            filename <- tempfiles [grep ("vbb.zip", tempfiles)]
            gtfs <- extract_gtfs (filename)
            
            need_these_columns <- c("trip_id" ,"start_time","end_time","headway_secs")
            gtfs$frequencies <- data.table::data.table()[,`:=`(c(need_these_columns)[1:3],NA)]
            
            msg <- paste0("frequencies must contain all required columns:\n  ",
                          paste (need_these_columns, collapse = ", "))
            expect_error (g <- frequencies_to_stop_times (gtfs), msg)
})

test_that ("only routes with frequencies to stop_times", {
            berlin_gtfs_to_zip ()
            f <- file.path (tempdir (), "vbb.zip")
            expect_true (file.exists (f))
            gtfs <- extract_gtfs (f)
            
            # filter only one route from gtfs 
            gtfs$routes <- gtfs$routes[route_short_name == "U1"]
            
            gtfs$trips <- gtfs$trips [route_id %in% gtfs$routes$route_id]
            sel_trip_id <- head (gtfs$stop_times [trip_id %in% gtfs$trips$trip_id, 
                                                  .N, by = "trip_id"][N == max(N), trip_id], 1)
            gtfs$trips <- gtfs$trips[trip_id == sel_trip_id]
            
            gtfs$calendar <- gtfs$calendar[service_id %in% gtfs$trips$service_id]
            gtfs$stop_times <- gtfs$stop_times[trip_id %in% gtfs$trips$trip_id]
            gtfs$stops <- gtfs$stops[stop_id %in% gtfs$stop_times$stop_id]
            
            gtfs$transfers <- gtfs$transfers[from_stop_id %in% gtfs$stops$stop_id &
                                                 to_stop_id %in% gtfs$stops$stop_id]
            # create frequencies in gtfs with one frequency
            gtfs$frequencies <-data.table::data.table(
                trip_id = gtfs$trips$trip_id,
                start_time = "08:00:00",
                end_time = "09:00:00",
                headway_secs = 8*60 # frequency of 8 minutes: 8 trips expected
            )
            
            stop_times_no_freq <- nrow(gtfs$stop_times)
            gtfs_freq1 <- frequencies_to_stop_times(gtfs)
            
            expect_equal(nrow(gtfs_freq1$stop_times), stop_times_no_freq*8)
            expect_equal(min(gtfs_freq1$stop_times$arrival_time), 8*3600)
            expect_lte(max(gtfs_freq1$stop_times[stop_sequence == 0][["arrival_time"]]), 9*3600)
            
            # update frequencies to include two subsequent time window 
            gtfs$frequencies <-data.table::data.table(
                trip_id = gtfs$trips$trip_id,
                start_time = c("08:00:00", "09:00:00"),
                end_time = c("09:00:00", "10:00:00"),
                headway_secs = c(8*60, 10*60)
            )
            
            freq_2_exp_arrival <- c(seq(8*3600, 9*3600, 8*60),  seq(8*3600+7*8*60+10*60, 10*3600, 10*60))
            gtfs_freq2 <- frequencies_to_stop_times(gtfs)
            
            expect_equal(gtfs_freq2$stop_times[stop_sequence == 0][["arrival_time"]], freq_2_exp_arrival)
            
            # check the last departure in the first time window
            gtfs$frequencies <-data.table::data.table(
                trip_id = gtfs$trips$trip_id,
                start_time = c("08:00:00", "10:00:00"),
                end_time = c("09:00:00", "11:00:00"),
                headway_secs = c(40*60, 50*60)
            )
            
            gtfs_freq3 <- frequencies_to_stop_times(gtfs)
            freq_3_exp_arrival <- c(8*3600, 8*3600+40*60, 10*3600, 10*3600+50*60)
            
            expect_equal(gtfs_freq3$stop_times[stop_sequence == 0][["arrival_time"]], freq_3_exp_arrival)
})

test_that ("gtfs with mixed frequencies", {
    berlin_gtfs_to_zip ()
    f <- file.path (tempdir (), "vbb.zip")
    expect_true (file.exists (f))
    gtfs <- extract_gtfs (f)
    
    # filter two routes: U1 - only one trip and U3 with all trips
    gtfs$routes <- gtfs$routes[route_short_name %in% c("U1", "U3")]
    
    trips_U3 <- gtfs$trips [route_id %in% gtfs$routes[route_short_name == "U3"][["route_id"]]]
    
    trips_U1 <- gtfs$trips [route_id %in% gtfs$routes[route_short_name == "U1"][["route_id"]]]

    sel_trip_id_U1 <- head (gtfs$stop_times [trip_id %in% trips_U1$trip_id, 
                                          .N, by = "trip_id"][N == max(N), trip_id], 1)
    
    gtfs$trips <- gtfs$trips[trip_id %in% c(trips_U3$trip_id, sel_trip_id_U1)]
    
    gtfs$calendar <- gtfs$calendar[service_id %in% gtfs$trips$service_id]
    gtfs$stop_times <- gtfs$stop_times[trip_id %in% gtfs$trips$trip_id]
    gtfs$stops <- gtfs$stops[stop_id %in% gtfs$stop_times$stop_id]
    
    gtfs$transfers <- gtfs$transfers[from_stop_id %in% gtfs$stops$stop_id &
                                         to_stop_id %in% gtfs$stops$stop_id]
    
    # create frequencies for the route U1
    gtfs$frequencies <-data.table::data.table(
        trip_id = sel_trip_id_U1,
        start_time = "08:00:00",
        end_time = "09:00:00",
        headway_secs = 10*60 # frequency of 8 minutes: 8 trips expected
    )
    
    gtfs_freq4 <- frequencies_to_stop_times(gtfs)
    
    expect_lt(nrow(gtfs$stop_times), nrow(gtfs_freq4$stop_times))
    # line which does not has frequencies should remain untouched
    expect_equal(nrow(gtfs$stop_times[trip_id %in% trips_U3$trip_id]), 
                 nrow(gtfs_freq4$stop_times[trip_id %in% trips_U3$trip_id]))
    # line with frequencies should have stop_times multiplied
    expect_lt(nrow(gtfs$stop_times[trip_id == sel_trip_id_U1]),
              nrow(gtfs_freq4$stop_times[grepl(sel_trip_id_U1, trip_id)]))
})

test_that("gtfs frequencies in gtfs_route", {
  berlin_gtfs_to_zip()
  f <- file.path(tempdir(), "vbb.zip")
  expect_true(file.exists(f))
  gtfs <- extract_gtfs(f)
  
  gtfs$routes <- gtfs$routes[route_short_name %in% c("U1", "U6")]
  
  # select only one route wich runs on mondays
  trips_U1 <- gtfs$trips [(route_id %in% gtfs$routes[route_short_name == "U1"][["route_id"]] )
                          & (service_id %in% gtfs$calendar[monday == "1"][["service_id"]])]
  
  sel_trip_id_U1 <- head(gtfs$stop_times [trip_id %in% trips_U1$trip_id,
                                          .N,
                                          by = "trip_id"
  ][N == max(N), trip_id], 1)
  
  gtfs$trips <- gtfs$trips[trip_id %in% c(sel_trip_id_U1)]
  
  gtfs$calendar <- gtfs$calendar[service_id %in% gtfs$trips$service_id]
  gtfs$stop_times <- gtfs$stop_times[trip_id %in% gtfs$trips$trip_id]
  gtfs$stops <- gtfs$stops[stop_id %in% gtfs$stop_times$stop_id]
  
  gtfs$transfers <- gtfs$transfers[from_stop_id %in% gtfs$stops$stop_id &
                                     to_stop_id %in% gtfs$stops$stop_id]
  
  # create frequencies for the route U1
  gtfs$frequencies <- data.table::data.table(
    trip_id = sel_trip_id_U1[1],
    start_time = "08:00:00",
    end_time = "09:00:00",
    headway_secs = 10 * 60)
  
  gtfs_freq <- frequencies_to_stop_times(gtfs)
  gtfs_timetable <- gtfs_timetable(gtfs_freq, day = "Monday")
  r <- gtfs_route(gtfs_timetable, "Warschauer", "Prinzenstr", start_time = 8 * 3600 + 10*60)
  
  expect_equal(r[1, "arrival_time"], "08:10:00")
  expect_equal(r[nrow(r), "arrival_time"], "08:17:30")
})
