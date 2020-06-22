#include "csa.h"

//' rcpp_csa_isochrone
//'
//' Calculate isochrones using Connection Scan Algorithm for GTFS data. Works
//' largely as rcpp_csa. Returns a list of integer vectors, with [i] holding
//' sequences of stations on a given route, the end one being the terminal
//' isochrone point, and [i+1] holding correpsonding trip numbers.
//'
//' @noRd
// [[Rcpp::export]]
Rcpp::List rcpp_csa_isochrone (Rcpp::DataFrame timetable,
        Rcpp::DataFrame transfers,
        const size_t nstations,
        const size_t ntrips,
        const std::vector <size_t> start_stations,
        const int start_time, const int end_time)
{
    // make start and end stations into std::unordered_sets to allow
    // constant-time lookup. stations at this point are 1-based R indices, but
    // that doesn't matter here.
    std::unordered_set <size_t> start_stations_set;
    for (auto i: start_stations)
        start_stations_set.emplace (i);

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

    std::vector <bool> is_connected (ntrips, false);

    // trip connections:
    std::unordered_set <size_t> end_stations, transfer_stations;
    bool start_time_found = false;
    int actual_start_time = INFINITE_INT, actual_end_time = INFINITE_INT;
    for (size_t i = 0; i < n; i++)
    {
        if (departure_time [i] < start_time)
            continue; // # nocov - these lines already removed in R fn.
        if (departure_time [i] > actual_end_time)
            break;

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

            end_stations.emplace (arrival_station [i]);
            if (!start_time_found)
            {
                actual_start_time = departure_time [i];
                actual_end_time = actual_start_time + end_time - start_time;
                start_time_found = true;
            }
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

                end_stations.emplace (arrival_station [i]);
                end_stations.erase (departure_station [i]);
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
                    }
                }
            }
            is_connected [trip_id [i]] = true;
        }
    }

   
    Rcpp::List res (2 * end_stations.size () + 1);
    size_t count = 0;
    for (auto es: end_stations)
    {
        std::vector <int> trip_out, end_station_out;
        size_t i = es;
        trip_out.push_back (static_cast <int> (current_trip [i]));
        end_station_out.push_back (static_cast <int> (i));
        while (i < INFINITE_INT)
        {
            i = prev_stn [static_cast <size_t> (i)];
            end_station_out.push_back (static_cast <int> (i));
            if (i < INFINITE_INT)
                trip_out.push_back (static_cast <int> (current_trip [i]));
        }
        end_station_out.resize (end_station_out.size () - 1);
        std::reverse (end_station_out.begin (), end_station_out.end ());
        std::reverse (trip_out.begin (), trip_out.end ());

        res (2 * count) = end_station_out;
        res (2 * count++ + 1) = trip_out;
    }
    res (static_cast <size_t> (res.length ()) - 1) = actual_start_time;

    return res;
}
