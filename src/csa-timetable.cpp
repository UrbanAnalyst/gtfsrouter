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
