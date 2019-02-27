#include "csa.h"

//' rcpp_csa
//'
//' Connection Scan Algorithm for GTFS data. The timetable has 
//' [deparutre_station, arrival_station, departure_time, arrival_time,
//'     trip_id],
//' with all entries as integer values, including times in seconds after
//' 00:00:00. The station and trip IDs can be mapped back on to actual station
//' IDs, but do not necessarily form a single set of unit-interval values
//' because the timetable is first cut down to only that portion after the
//' desired start time. These are nevertheless used as direct array indices
//' throughout, so are all size_t objects rather than int. All indices in the
//' timetable and transfers DataFrames, as well as start_/end_stations, are
//' 1-based, but they are still used directly which just means that the first
//' entries (that is, entry [0]) of station and trip vectors are never used.
//'
//' @noRd
// [[Rcpp::export]]
Rcpp::DataFrame rcpp_csa (Rcpp::DataFrame timetable,
        Rcpp::DataFrame transfers,
        const size_t nstations,
        const size_t ntrips,
        const std::vector <size_t> start_stations,
        const std::vector <size_t> end_stations,
        const int start_time,
        const int max_transfers)
{
    // make start and end stations into std::unordered_sets to allow
    // constant-time lookup. stations at this point are 1-based R indices, but
    // that doesn't matter here.
    std::unordered_set <size_t> start_stations_set, end_stations_set;
    for (auto i: start_stations)
        start_stations_set.emplace (i);
    for (auto i: end_stations)
        end_stations_set.emplace (i);

    const size_t n = static_cast <size_t> (timetable.nrow ());

    // convert transfers into a map from start to (end, transfer_time). Transfer
    // indices are also 1-based here.
    std::unordered_map <size_t, std::unordered_map <size_t, int> > transfer_map;
    std::vector <size_t> trans_from = transfers ["from_stop_id"],
        trans_to = transfers ["to_stop_id"];
    std::vector <int> trans_time = transfers ["min_transfer_time"];
    for (size_t i = 0; i < static_cast <size_t> (transfers.nrow ()); i++)
        if (trans_from [i] != trans_to [i])
        {
            std::unordered_map <size_t, int> transfer_pair; // station, time
            if (transfer_map.find (trans_from [i]) ==
                    transfer_map.end ())
            {
                transfer_pair.clear ();
                transfer_pair.emplace (trans_to [i], trans_time [i]);
                transfer_map.emplace (trans_from [i], transfer_pair);
            } else
            {
                transfer_pair = transfer_map.at (trans_from [i]);
                transfer_pair.emplace (trans_to [i], trans_time [i]);
                transfer_map [trans_from [i] ] = transfer_pair;
            }
        }

    // set transfer times from first connection; the prev and current vars are
    // used in the main loop below. Thus use nstations + 1 because it's
    // 1-indexed throughout, and the first element is ignored.
    std::vector <int> earliest_connection (nstations + 1, INFINITE_INT),
        prev_time (nstations + 1, INFINITE_INT);
    std::vector <size_t> prev_stn (nstations + 1, INFINITE_INT),
        current_trip (nstations + 1, INFINITE_INT);
    for (size_t i = 0; i < start_stations.size (); i++)
    {
        earliest_connection [start_stations [i]] = start_time;
        if (transfer_map.find (start_stations [i]) !=
                transfer_map.end ())
        {
            std::unordered_map <size_t, int> transfer_pair =
                transfer_map.at (start_stations [i]);
            // Don't penalise these first footpaths:
            for (auto t: transfer_pair)
                earliest_connection [t.first] = start_time;
                //earliest_connection [t.first] = start_time + t.second;
        }
    }

    // main CSA loop
    // stations and trips are size_t because they're used as direct array indices.
    const std::vector <size_t> departure_station = timetable ["departure_station"],
        arrival_station = timetable ["arrival_station"],
        trip_id = timetable ["trip_id"];
    const std::vector <int> departure_time = timetable ["departure_time"],
        arrival_time = timetable ["arrival_time"];

    int earliest = INFINITE_INT;
    std::vector <bool> is_connected (ntrips, false);

    // trip connections:
    size_t end_station = INFINITE_INT;
    std::vector <int> n_transfers (nstations + 1, 0);
    for (size_t i = 0; i < n; i++)
    {
        if (departure_time [i] < start_time)
            continue; // # nocov - these lines already removed in R fn.

        // add all departures from start_stations_set:
        if (start_stations_set.find (departure_station [i]) !=
                start_stations_set.end () &&
                arrival_time [i] < earliest_connection [arrival_station [i] ])
        {
            is_connected [trip_id [i] ] = true;
            earliest_connection [arrival_station [i] ] = arrival_time [i];
            current_trip [arrival_station [i] ] = trip_id [i];
            prev_stn [arrival_station [i] ] = departure_station [i];
            prev_time [arrival_station [i] ] = departure_time [i];
        }

        // main connection scan:
        if (((earliest_connection [departure_station [i] ] <= departure_time [i]) &&
                    n_transfers [departure_station [i] ] < max_transfers) ||
                is_connected [trip_id [i]])
        {
            if (arrival_time [i] < earliest_connection [arrival_station [i] ])
            {
                earliest_connection [arrival_station [i] ] = arrival_time [i];
                prev_stn [arrival_station [i] ] = departure_station [i];
                prev_time [arrival_station [i] ] = departure_time [i];
                current_trip [arrival_station [i] ] = trip_id [i];
                n_transfers [arrival_station [i] ] =
                    n_transfers [departure_station [i] ];
            }
            if (end_stations_set.find (arrival_station [i]) !=
                    end_stations_set.end ())
            {
                if (arrival_time [i] < earliest)
                {
                    earliest = arrival_time [i];
                    end_station = arrival_station [i];
                }
                end_stations_set.erase (arrival_station [i]);
            }

            if (transfer_map.find (arrival_station [i]) != transfer_map.end ())
            {
                for (auto t: transfer_map.at (arrival_station [i]))
                {
                    size_t trans_dest = t.first;
                    int ttime = arrival_time [i] + t.second;
                    if (ttime < earliest_connection [trans_dest] &&
                            n_transfers [trans_dest] <= max_transfers)
                    {
                        earliest_connection [trans_dest] = ttime;
                        prev_stn [trans_dest] = arrival_station [i];
                        prev_time [trans_dest] = arrival_time [i];
                        n_transfers [trans_dest]++;

                        if (end_stations_set.find (trans_dest) !=
                                end_stations_set.end ())
                        {
                            // # nocov start
                            if (ttime < earliest)
                            {
                                earliest = ttime;
                                end_station = trans_dest;
                            }
                            // # nocov end
                            end_stations_set.erase (trans_dest);
                        }
                    }
                }
            }
            is_connected [trip_id [i]] = true;
        }
        if (end_stations_set.size () == 0)
            break;
    }

    size_t count = 1;
    size_t i = end_station;
    while (i < INFINITE_INT)
    {
        count++;
        i = prev_stn [static_cast <size_t> (i)];
        if (count > nstations)
            Rcpp::stop ("no route found; something went wrong"); // # nocov
    }

    std::vector <size_t> end_station_out (count), trip_out (count, INFINITE_INT);
    std::vector <int> time_out (count);
    i = end_station;
    if (i > current_trip.size ()) // No route able to be found
    {
        end_station_out.clear ();
        time_out.clear ();
        trip_out.clear ();
    } else
    {
        time_out [0] = earliest;
        trip_out [0] = current_trip [i];
        end_station_out [0] = i;
        count = 1;
        while (i < INFINITE_INT)
        {
            time_out [count] = prev_time [i];
            i = prev_stn [static_cast <size_t> (i)];
            end_station_out [count] = i;
            if (i < INFINITE_INT)
                trip_out [count] = current_trip [i];
            count++;
        }
        // The last entry of these is all INF, so must be removed.
        end_station_out.resize (end_station_out.size () - 1);
        time_out.resize (time_out.size () - 1);
        trip_out.resize (trip_out.size () - 1);
        // trip_out values don't exist for start stations of each route, so
        for (int j = 1; j < trip_out.size (); j++)
            if (trip_out [j] == INFINITE_INT)
                trip_out [j] = trip_out [j - 1];
        // and last value of trip_out is always Inf, so
        //trip_out [trip_out.size () - 1] = trip_out [trip_out.size () - 2];
    }

    Rcpp::DataFrame res = Rcpp::DataFrame::create (
            Rcpp::Named ("stop_id") = end_station_out,
            Rcpp::Named ("time") = time_out,
            Rcpp::Named ("trip_id") = trip_out,
            Rcpp::_["stringsAsFactors"] = false);

    return res;
}
