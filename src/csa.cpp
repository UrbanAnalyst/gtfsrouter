#include "csa.h"

//' rcpp_make_timetable
//'
//' Make timetable from GTFS stop_times
//'
//' @noRd
// [[Rcpp::export]]
Rcpp::List rcpp_make_timetable (Rcpp::DataFrame stop_times)
{
    int n = stop_times.nrow ();

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
    for (int i = 0; i < n; i++)
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
    int n_connections = 0, n_trip_id = trip_id_vec [0];
    for (int i = 1; i < n; i++)
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
    for (int i = 1; i < n; i++)
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
//' Connection Scan Algorithm for GTFS data
//'
//' @noRd
// [[Rcpp::export]]
int rcpp_csa (Rcpp::DataFrame timetable,
        Rcpp::DataFrame transfers,
        const std::vector <std::string> stations,
        const std::vector <int> trips,
        const std::vector <int> start_stations,
        const std::vector <int> end_stations,
        const int start_time)
{
    // make start and end stations into std::unordered_sets
    std::unordered_set <int> start_stations_set, end_stations_set;
    for (auto i: start_stations)
        start_stations_set.emplace (i);
    for (auto i: end_stations)
        end_stations_set.emplace (i);

    const int nstations = stations.size ();
    std::unordered_map <std::string, int> station_map;
    for (int i = 0; i < nstations; i++)
        station_map.emplace (stations [i], i);

    const int ntrips = trips.size ();
    std::unordered_map <int, int> trip_map;
    for (int i = 0; i < ntrips; i++)
        trip_map.emplace (trips [i], i);

    const int n = timetable.nrow ();

    // convert transfers into a map from start to (end, transfer_time)
    std::unordered_map <int, std::unordered_map <int, int> > transfer_map;
    std::vector <int> trans_from = transfers ["from_stop_id"],
        trans_to = transfers ["to_stop_id"],
        trans_time = transfers ["min_transfer_time"];
    for (int i = 0; i < transfers.nrow (); i++)
        if (trans_from [i] != trans_to [i])
        {
            std::unordered_map <int, int> transfer_pair;
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
    std::vector <int> earliest_connection (nstations, INFINITE_INT);
    for (int i = 0; i < start_stations.size (); i++)
    {
        earliest_connection [start_stations [i] ] = start_time;
        if (transfer_map.find (start_stations [i]) !=
                transfer_map.end ())
        {
            std::unordered_map <int, int> transfer_pair =
                transfer_map.at (start_stations [i]);
            // Don't penalise these first footpaths:
            for (auto t: transfer_pair)
                earliest_connection [t.first] = start_time;
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
    std::vector <bool> is_connected (n, false);
    bool at_start = false;
    for (int i = 0; i < n; i++)
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

        if ((earliest_connection [departure_station [i]] <= departure_time [i])
                || (i > 1 && is_connected [i - 1]))
        {
            earliest_connection [arrival_station [i]] =
                std::min (earliest_connection [arrival_station [i]],
                        arrival_time [i]);
            for (auto j: end_stations)
                if (arrival_station [i] == j &&
                    earliest_connection [i] < earliest)
                {
                        earliest = earliest_connection [i];
                }

            if (transfer_map.find (arrival_station [i]) !=
                    transfer_map.end ())
            {
                std::unordered_map <int, int> transfer_pair =
                    transfer_map.at (arrival_station [i]);
                for (auto t: transfer_pair)
                {
                    int ttime = arrival_time [i] + t.second;
                    if (earliest_connection [t.first] > ttime)
                    {
                        earliest_connection [t.first] = ttime;
                        for (auto j: end_stations)
                            if (arrival_station [i] == j &&
                                earliest_connection [i] < earliest)
                            {
                                    earliest = earliest_connection [i];
                            }
                    }
                }
            }
            is_connected [i] = true;
        }
    }

    return earliest;
}
