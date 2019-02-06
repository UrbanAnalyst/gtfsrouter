library (gtfsrouter)

flist <- c ("routes.txt", "trips.txt", "stop_times.txt",
            "stops.txt", "transfers.txt")
chk <- sapply (flist, function (i)
                   data.table::fwrite (berlin_gtfs [strsplit (i, ".txt") [[1]] ],
                                       file.path (tempdir (), i), quote = TRUE)
                   )
flist <- file.path (tempdir (), flist)
zip (file.path (tempdir (), "vbb.zip"), files = flist)
