#include "csa.h"

//' rcpp_make_timetable
//'
//' Make timetable from GTFS stop_times. Both stop_ids and trip_ids are vectors
//' of unique values which are converted to unordered_maps on to 1-indexed
//' integer values.
//'
//' @noRd
// [[Rcpp::export]]
Rcpp::DataFrame rcpp_make_timetable (Rcpp::DataFrame stop_times,
        std::vector <std::string> stop_ids, std::vector <std::string> trip_ids)
{
    std::unordered_map <std::string, int> trip_id_map;
    int i = 1; // 1-indexed
    for (auto tr: trip_ids)
        trip_id_map.emplace (tr, i++);

    std::unordered_map <std::string, int> stop_id_map;
    i = 1;
    for (auto st: stop_ids)
        stop_id_map.emplace (st, i++);

    std::vector <std::string> stop_times_stop_id = stop_times ["stop_id"],
        stop_times_trip_id = stop_times ["trip_id"];
    std::vector <int> arrival_time_vec = stop_times ["arrival_time"],
        departure_time_vec = stop_times ["departure_time"];

    // count number of connections
    size_t n_connections = 0;
    std::string trip_id_i = stop_times_trip_id [0];
    size_t n_stop_times = static_cast <size_t> (stop_times.nrow ());
    for (size_t i = 1; i < n_stop_times; i++)
    {
        if (stop_times_trip_id [i] == trip_id_i)
            n_connections++;
        else
        {
            trip_id_i = stop_times_trip_id [i];
        }
    }

    // The vectors forming the timetable:
    std::vector <int> departure_time (n_connections),
        arrival_time (n_connections),
        departure_station (n_connections),
        arrival_station (n_connections),
        trip_id (n_connections);

    n_connections = 0;
    trip_id_i = stop_times_trip_id [0];
    int dest_stop = stop_id_map.at (stop_times_stop_id [0]);
    for (size_t i = 1; i < n_stop_times; i++)
    {
        if (stop_times_trip_id [i] == trip_id_i)
        {
            int arrival_stop = stop_id_map.at (stop_times_stop_id [i]);
            departure_station [n_connections] = dest_stop;
            arrival_station [n_connections] = arrival_stop;
            departure_time [n_connections] = departure_time_vec [i - 1];
            arrival_time [n_connections] = arrival_time_vec [i];
            trip_id [n_connections] = trip_id_map.at (trip_id_i);
            dest_stop = arrival_stop;
            n_connections++;
        } else
        {
            dest_stop = stop_id_map.at (stop_times_stop_id [i]);
            trip_id_i = stop_times_trip_id [i];
        }
    }

    Rcpp::DataFrame timetable = Rcpp::DataFrame::create (
            Rcpp::Named ("departure_station") = departure_station,
            Rcpp::Named ("arrival_station") = arrival_station,
            Rcpp::Named ("departure_time") = departure_time,
            Rcpp::Named ("arrival_time") = arrival_time,
            Rcpp::Named ("trip_id") = trip_id,
            Rcpp::_["stringsAsFactors"] = false);

    return timetable;
}

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
        const int start_time)
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
    // used in the main loop below.
    std::vector <int> earliest_connection (nstations, INFINITE_INT),
        prev_time (nstations, INFINITE_INT);
    std::vector <size_t> prev_stn (nstations, INFINITE_INT),
        current_trip (nstations, INFINITE_INT);
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
    for (size_t i = 0; i < n; i++)
    {
        if (departure_time [i] < start_time)
            continue;

        // add all departures from start_stations_set:
        if (start_stations_set.find (departure_station [i]) !=
                start_stations_set.end () &&
                arrival_time [i] < earliest_connection [arrival_station [i] ])
        {
            is_connected [trip_id [i] ] = true;
            earliest_connection [arrival_station [i] ] = arrival_time [i];
            current_trip [departure_station [i] ] = trip_id [i];
            current_trip [arrival_station [i] ] = trip_id [i];
            prev_stn [arrival_station [i] ] = departure_station [i];
            prev_time [arrival_station [i] ] = departure_time [i];
        }

        // main connection scan:
        if ((earliest_connection [departure_station [i] ] <= departure_time [i])
                || is_connected [trip_id [i]])
        {
            if (arrival_time [i] < earliest_connection [arrival_station [i] ])
            {
                earliest_connection [arrival_station [i] ] = arrival_time [i];
                prev_stn [arrival_station [i] ] = departure_station [i];
                prev_time [arrival_station [i] ] = departure_time [i];
                current_trip [arrival_station [i] ] = trip_id [i];
                current_trip [departure_station [i] ] = trip_id [i];
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
                    if (ttime < earliest_connection [trans_dest])
                    {
                        earliest_connection [trans_dest] = ttime;
                        prev_stn [trans_dest] = arrival_station [i];
                        prev_time [trans_dest] = arrival_time [i];

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
    }

    Rcpp::DataFrame res = Rcpp::DataFrame::create (
            Rcpp::Named ("stop_id") = end_station_out,
            Rcpp::Named ("time") = time_out,
            Rcpp::Named ("trip_id") = trip_out,
            Rcpp::_["stringsAsFactors"] = false);

    return res;
}
