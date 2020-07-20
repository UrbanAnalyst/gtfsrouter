#' frequencies_to_stop_times
#' 
#' Convert a GTFS 'frequencies' table to equivalent 'stop_times' that can be
#' used for routing.
#'
#' @param gtfs A set of GTFS data returned from \link{extract_gtfs}.
#'
#' @return The input GTFS data with data from the 'frequencies' table converted
#' to equivalent 'arrival_time' and 'departure_time' values in `stop_times`.
#' 
#' @importFrom data.table shift
#'    
#' @export
frequencies_to_stop_times <- function(gtfs)  
{
    # check if gtfs is a gtfs class of object
    if (class(gtfs)[1] != "gtfs")
        stop ("selected object does not appear to be a GTFS file")
    
    # test if gtfs contains no empty `frequencies`
    if (!("frequencies" %in% names (gtfs)))
        stop ("selected gtfs does not contain frequencies")
    if (nrow (gtfs$frequencies) == 0)
        stop ("frequencies table is empty")
    
    # frequencies must contain required columns:
    # "trip_id" ,"start_time","end_time","headway_secs"
    need_these_columns <- c("trip_id" ,"start_time","end_time","headway_secs")
    checks <- vapply (need_these_columns, function (i)
        any (grepl (i, names(gtfs$frequencies))), logical (1))
    
    arrival_time <- departure_time <- end_time <-
        start_time <- stop_sequence <- trip_id <- trip_id_f <- NULL

    if (!all (checks))
        stop ("frequencies must contain all required columns:\n  ",
              paste (need_these_columns, collapse = ", "))

    
    # IMPORTANT: data.table works entirely by reference, so all operations
    # change original values unless first copied! This function thus returns a
    # copy even when it does nothing else, so always entails some cost.
    gtfs_cp <- data.table::copy (gtfs)
    
    gtfs_cp$frequencies[, start_time :=  rcpp_time_to_seconds (start_time)]
    gtfs_cp$frequencies[, end_time :=  rcpp_time_to_seconds (end_time)]

    # add column for a new individual trip_id
    gtfs_cp$stop_times [, trip_id_f := trip_id]
    
    # create empty data.table for output from frequencies
    stop_times <- gtfs_cp$stop_times [0]
    
    trips <- unique (gtfs_cp$frequencies [, trip_id])
    
    for (trip in trips)  {
        
        # n is to  be added to trip_id
        n <- 1 
        
        # order frequencies table by trip_id and start_time
        frequencies_trip <- gtfs_cp$frequencies [order (trip_id, start_time)] [trip_id == trip]

        # in case end_time of the previous period and start_time of the next are equal:
        frequencies_trip [end_time == data.table::shift (start_time, 1, type = "lead"), end_time := end_time - 1]
        
        stop_times_trip <- gtfs_cp$stop_times [order (stop_sequence)] [trip_id == trip]
        
        # in case of the first arrival time > 0, then reset them: 
        if (stop_times_trip [1] [["arrival_time"]] > 0)  {
            stop_times_trip [, c ("arrival_time", "departure_time") := list(
                arrival_time - stop_times_trip [1] [["arrival_time"]],
                departure_time - stop_times_trip [1] [["arrival_time"]]     )]
        }
        
        start_t <- min (frequencies_trip$start_time)
        
        headway <- headway_old <- frequencies_trip [1] [["headway_secs"]]
        
        for (i in row (frequencies_trip))  {
            
            end_t <- frequencies_trip [i] [["end_time"]]
            headway <- frequencies_trip [i] [["headway_secs"]]
            
            # in order to ensure a 'smooth' transition between frequency periods
            ifelse (
                headway_old - start_t + frequencies_trip [i] [["start_time"]] < headway,
                start_t <- start_t - headway_old + headway,
                start_t <- frequencies_trip [i] [["start_time"]]
            )
            
            # multiply stop_times for all trips based on a given frequency 
            while (start_t < end_t)  {
                
                stop_times_trip_i <- data.table::copy (stop_times_trip) [, c ("arrival_time", "departure_time", "trip_id_f") := list (
                    (arrival_time + start_t), 
                    (departure_time + start_t),
                    paste (trip_id, n, sep = "_"))]
                
                n <- n + 1
                
                stop_times <- rbind (stop_times, stop_times_trip_i)
                
                start_t <- start_t + headway
            }
            
            headway_old <- headway
            
        }
        
    }
    
    gtfs_cp$stop_times <- rbind (gtfs_cp$stop_times [!(trip_id) %in% gtfs_cp$frequencies$trip_id], stop_times)
    
    trip_id_mapping <- unique(gtfs_cp$stop_times [, c("trip_id", "trip_id_f")])
    gtfs_cp$trips <- merge(gtfs_cp$trips, trip_id_mapping, by = "trip_id", all.y = T)
    gtfs_cp$trips$trip_id <- gtfs_cp$trips$trip_id_f
    gtfs_cp$trips <- subset(gtfs_cp$trips, select= names(gtfs_cp$trips) != "trip_id_f") # rm trip_id_f
    
    gtfs_cp$stop_times$trip_id <- gtfs_cp$stop_times$trip_id_f
    gtfs_cp$stop_times <- subset(gtfs_cp$stop_times, select= names(gtfs_cp$stop_times) != "trip_id_f") # rm trip_id_f
    
    return (gtfs_cp)
}
