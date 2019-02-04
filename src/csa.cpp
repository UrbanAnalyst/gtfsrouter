#include "csa.h"

//' rcpp_make_timetable
//'
//' Make timetable from GTFS stop_times
//'
//' @noRd
// [[Rcpp::export]]
Rcpp::List rcpp_make_timetable (Rcpp::DataFrame stop_times)
{
    size_t n = static_cast <size_t> (stop_times.nrow ());

    std::unordered_map <std::string, int> stop_id_map;
    std::deque <std::string> stop_ids;
    std::deque <int> trip_ids;
    std::unordered_map <int, int> trip_id_map;

    std::vector <std::string> stop_id_vec = stop_times ["stop_id"];
    std::vector <int> trip_id_vec = stop_times ["trip_id"],
        arrival_time_vec = stop_times ["arrival_time"],
        departure_time_vec = stop_times ["departure_time"];

    // Get maps of stop and trip IDs
    int count_stops = 0, count_trips = 0;
    for (size_t i = 0; i < n; i++)
    {
        if (stop_id_map.find (stop_id_vec [i]) == stop_id_map.end ())
        {
            stop_ids.push_back (stop_id_vec [i]);
            stop_id_map.emplace (stop_id_vec [i], count_stops++);
        }
        if (trip_id_map.find (trip_id_vec [i]) == trip_id_map.end ())
        {
            trip_ids.push_back (trip_id_vec [i]);
            trip_id_map.emplace (trip_id_vec [i], count_trips++);
        }
    }

    // count number of connections
    size_t n_connections = 0;
    int n_trip_id = trip_id_vec [0];
    for (size_t i = 1; i < n; i++)
    {
        if (trip_id_vec [i] == n_trip_id)
            n_connections++;
        else
        {
            n_trip_id = trip_id_vec [i];
        }
    }

    std::vector <int> departure_time (n_connections),
        arrival_time (n_connections),
        departure_station (n_connections),
        arrival_station (n_connections),
        trip_id (n_connections);

    n_connections = 0;
    n_trip_id = trip_id_vec [0];
    int ds = stop_id_map.at (stop_id_vec [0]);
    int tn = trip_id_map.at (trip_id_vec [0]);
    for (size_t i = 1; i < n; i++)
    {
        if (trip_id_vec [i] == n_trip_id)
        {
            int as = stop_id_map.at (stop_id_vec [i]);
            departure_station [n_connections] = ds;
            arrival_station [n_connections] = as;
            departure_time [n_connections] = departure_time_vec [i - 1];
            arrival_time [n_connections] = arrival_time_vec [i];
            trip_id [n_connections] = tn;
            ds = as;
            n_connections++;
        } else
        {
            ds = stop_id_map.at (stop_id_vec [i]);
            n_trip_id = trip_id_vec [i];
            tn = trip_id_map.at (n_trip_id);
        }
    }

    Rcpp::DataFrame timetable = Rcpp::DataFrame::create (
            Rcpp::Named ("departure_station") = departure_station,
            Rcpp::Named ("arrival_station") = arrival_station,
            Rcpp::Named ("departure_time") = departure_time,
            Rcpp::Named ("arrival_time") = arrival_time,
            Rcpp::Named ("trip_id") = trip_id,
            Rcpp::_["stringsAsFactors"] = false);
    Rcpp::CharacterVector station_names = Rcpp::wrap (stop_ids);
    Rcpp::IntegerVector trip_numbers = Rcpp::wrap (trip_ids);

    return Rcpp::List::create (
            Rcpp::Named ("timetable") = timetable,
            Rcpp::Named ("stations") = station_names,
            Rcpp::Named ("trips") = trip_numbers);
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
//' desired start time.
//'
//' @noRd
// [[Rcpp::export]]
int rcpp_csa (Rcpp::DataFrame timetable,
        Rcpp::DataFrame transfers,
        const int nstations,
        const int ntrips,
        const std::vector <int> start_stations,
        const std::vector <int> end_stations,
        const int start_time)
{
    const size_t nstations_st = static_cast <size_t> (nstations);
    const size_t ntrips_st = static_cast <size_t> (ntrips);

    // make start and end stations into std::unordered_sets to allow
    // constant-time lookup.
    std::unordered_set <int> start_stations_set, end_stations_set;
    for (auto i: start_stations)
        start_stations_set.emplace (i);
    for (auto i: end_stations)
        end_stations_set.emplace (i);

    const size_t n = static_cast <size_t> (timetable.nrow ());

    // convert transfers into a map from start to (end, transfer_time)
    std::unordered_map <int, std::unordered_map <int, int> > transfer_map;
    std::vector <int> trans_from = transfers ["from_stop_id"],
        trans_to = transfers ["to_stop_id"],
        trans_time = transfers ["min_transfer_time"];
    for (size_t i = 0; i < static_cast <size_t> (transfers.nrow ()); i++)
        if (trans_from [i] != trans_to [i])
        {
            std::unordered_map <int, int> transfer_pair; // station, time
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

    // set transfer times from first connection
    std::vector <int> earliest_connection (nstations_st, INFINITE_INT);
    for (size_t i = 0; i < start_stations.size (); i++)
    {
        earliest_connection [static_cast <size_t> (start_stations [i])] =
            start_time;
        if (transfer_map.find (start_stations [i]) !=
                transfer_map.end ())
        {
            std::unordered_map <int, int> transfer_pair =
                transfer_map.at (start_stations [i]);
            // Don't penalise these first footpaths:
            for (auto t: transfer_pair)
                earliest_connection [static_cast <size_t> (t.first)] = start_time;
                //earliest_connection [t.first] = start_time + t.second;
        }
    }

    // main CSA loop
    const std::vector <int> departure_station = timetable ["departure_station"],
        arrival_station = timetable ["arrival_station"],
        departure_time = timetable ["departure_time"],
        arrival_time = timetable ["arrival_time"],
        trip_id = timetable ["trip_id"];

    int earliest = INFINITE_INT;
    std::vector <bool> is_connected (ntrips_st, false);
    bool at_start = false;

    // trip connections:
    std::vector <int> prev_stn (nstations_st, -1);
    int end_station = -1;

    for (size_t i = 0; i < n; i++)
    {
        // skip all connections until start_station is found
        if (!at_start)
        {
            if (start_stations_set.find (departure_station [i]) !=
                    start_stations_set.end () &&
                    departure_time [i] >= start_time)
                at_start = true;
            else
                continue;
        }
        // add all departures from start_stations_set:
        size_t asi = static_cast <size_t> (arrival_station [i]),
               dsi = static_cast <size_t> (departure_station [i]),
               tidi = static_cast <size_t> (trip_id [i]);
        if (start_stations_set.find (departure_station [i]) !=
                start_stations_set.end () &&
                departure_time [i] >= start_time)
        {
            is_connected [tidi] = true;
            earliest_connection [asi] = 
                std::min (earliest_connection [asi], arrival_time [i]);
        }

        // main connection scan:
        if ((earliest_connection [dsi] <= departure_time [i])
                || is_connected [tidi])
        {
            if (arrival_time [i] < earliest_connection [asi])
            {
                earliest_connection [asi] = arrival_time [i];
                prev_stn [static_cast <size_t> (arrival_station [i])] =
                    departure_station [i];
            }
            if (end_stations_set.find (arrival_station [i]) !=
                    end_stations_set.end ())
            {
                if (arrival_time [i] < earliest)
                    earliest = arrival_time [i];
                end_station = arrival_station [i];
                end_stations_set.erase (arrival_station [i]);
            }

            if (transfer_map.find (arrival_station [i]) != transfer_map.end ())
            {
                for (auto t: transfer_map.at (arrival_station [i]))
                {
                    int ttime = arrival_time [i] + t.second;
                    int trans_dest = t.first;
                    size_t trans_dest_st = static_cast <size_t> (trans_dest);
                    if (ttime < earliest_connection [trans_dest_st])
                    {
                        earliest_connection [trans_dest_st] = ttime;
                        prev_stn [trans_dest_st] = arrival_station [i];
                        if (end_stations_set.find (trans_dest) !=
                                end_stations_set.end ())
                        {
                            if (ttime < earliest)
                            {
                                earliest = ttime;
                                end_station = trans_dest;
                            }
                            end_stations_set.erase (trans_dest);
                        }
                    }
                }
            }
            is_connected [tidi] = true;
        }
        if (end_stations_set.size () == 0)
            break;
    }
    Rcpp::Rcout << "end station = " << end_station << std::endl;
    int i = end_station;
    while (i >= 0)
    {
        Rcpp::Rcout << i << std::endl;
        i = prev_stn [static_cast <size_t> (i)];
    }

    return earliest;
}
