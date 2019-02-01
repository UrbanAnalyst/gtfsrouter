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
Rcpp::List rcpp_csa (Rcpp::DataFrame timetable,
        Rcpp::DataFrame transfers,
        const std::vector <std::string> stations,
        const std::vector <int> trips,
        const std::vector <int> start_stations,
        const std::vector <int> end_stations,
        const int start_time)
{
    const int nstations = stations.size ();
    std::unordered_map <std::string, int> station_map;
    for (int i = 0; i < nstations; i++)
        station_map.emplace (stations [i], i);

    const int ntrips = trips.size ();
    std::unordered_map <int, int> trip_map;
    for (int i = 0; i < ntrips; i++)
        trip_map.emplace (trips [i], i);

    int n = timetable.nrow ();

    // convert transfers into a map
    std::unordered_map <std::string, int> transfer_map;
    std::vector <int> trans_from = transfers ["from_stop_id"],
        trans_to = transfers ["to_stop_id"],
        trans_time = transfers ["min_transfer_time"];
    for (int i = 0; i < transfers.nrow (); i++)
        if (trans_from [i] != trans_to [i])
        {
            std::string trans_id = std::to_string (trans_from [i]) + "-" +
                std::to_string (trans_to [i]);
            transfer_map.emplace (trans_id, trans_time [i]);
        }

    // Then the main CSA loop
    std::vector <int> earliest_connection (INFINITE_INT);
    std::vector <bool> is_connected (ntrips, false);
    for (int i = 0; i < start_stations.size (); i++)
    {
        earliest_connection [start_stations [i] ] = start_time;
    }

    for (int i = 0; i < n; i++)
    {
        //int stn_i = stop_id_map.at (stop_id [i]);
        //if (departure_time [i] >= earliest_connection 
    }

    Rcpp::List res;
    return res;
}
