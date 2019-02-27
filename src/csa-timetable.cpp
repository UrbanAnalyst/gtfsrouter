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

// # nocov start
//' rcpp_median_timetable
//' @noRd
// [[Rcpp::export]]
Rcpp::DataFrame rcpp_median_timetable (Rcpp::DataFrame full_timetable)
{
    std::vector <int>
        departure_station = full_timetable ["departure_station"],
        arrival_station = full_timetable ["arrival_station"],
        departure_time = full_timetable ["departure_time"],
        arrival_time = full_timetable ["arrival_time"];

    std::unordered_map <std::string, std::vector <int> > timetable;
    size_t n_stop_times = static_cast <size_t> (full_timetable.nrow ());
    for (size_t i = 0; i < n_stop_times; i++)
    {
        std::string stn_str;
        stn_str = std::to_string (departure_station [i]) +
            "-" + std::to_string (arrival_station [i]);
        std::vector <int> times;
        if (timetable.find (stn_str) != timetable.end ())
            times = timetable.at (stn_str);
        times.push_back (arrival_time [i] - departure_time [i]);
        timetable [stn_str] = times;
    }

    size_t n = timetable.size ();
    std::vector <int> start_station (n), end_station (n),
        time_min (n), time_median (n), time_max (n);
    int i = 0;
    for (auto t: timetable)
    {
        std::string stn_str = t.first;
        size_t ipos = stn_str.find ("-");
        start_station [i] = atoi (stn_str.substr (0, ipos).c_str ());
        stn_str = stn_str.substr (ipos + 1, stn_str.size () - 1);
        end_station [i] = atoi (stn_str.c_str ());
        std::vector <int> times = t.second;
        std::sort (times.begin (), times.end ());
        time_min [i] = times [0];
        time_max [i] = times [times.size () - 1];
        ipos = round (times.size () / 2);
        time_median [i] = times [ipos];
        i++;
    }

    Rcpp::DataFrame res = Rcpp::DataFrame::create (
            Rcpp::Named ("departure_station") = start_station,
            Rcpp::Named ("arrival_station") = end_station,
            Rcpp::Named ("time_min") = time_min,
            Rcpp::Named ("time_median") = time_median,
            Rcpp::Named ("time_max") = time_max,
            Rcpp::_["stringsAsFactors"] = false);
    return res;
}
// # nocov end
