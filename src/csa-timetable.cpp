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
    Timetable_Inputs tt_in;
    timetable::timetable_in_from_df (stop_times, tt_in);

    size_t n = timetable::count_connections (tt_in);

    Timetable_Outputs tt_out;
    timetable::initialise_tt_outputs (tt_out, n);
    timetable::make_timetable (tt_in, tt_out, stop_ids, trip_ids);

    Rcpp::DataFrame timetable = Rcpp::DataFrame::create (
            Rcpp::Named ("departure_station") = tt_out.departure_station,
            Rcpp::Named ("arrival_station") = tt_out.arrival_station,
            Rcpp::Named ("departure_time") = tt_out.departure_time,
            Rcpp::Named ("arrival_time") = tt_out.arrival_time,
            Rcpp::Named ("trip_id") = tt_out.trip_id,
            Rcpp::_["stringsAsFactors"] = false);

    return timetable;
}

void timetable::timetable_in_from_df (Rcpp::DataFrame &stop_times,
        Timetable_Inputs &tt_in)
{
    tt_in.stop_id = Rcpp::as <std::vector <std::string> > (stop_times ["stop_id"]);
    tt_in.trip_id = Rcpp::as <std::vector <std::string> > (stop_times ["trip_id"]);
    tt_in.arrival_time = Rcpp::as <std::vector <int> > (
            stop_times ["arrival_time"]);
    tt_in.departure_time = Rcpp::as <std::vector <int> > (
            stop_times ["departure_time"]);
}

size_t timetable::count_connections (const Timetable_Inputs &tt_in)
{
    size_t n_connections = 0;
    std::string trip_id_i = tt_in.trip_id [0];
    for (size_t i = 1; i < tt_in.trip_id.size (); i++)
    {
        if (tt_in.trip_id [i] == trip_id_i)
            n_connections++;
        else
        {
            trip_id_i = tt_in.trip_id [i];
        }
    }
    return n_connections;
}
    
void timetable::initialise_tt_outputs (Timetable_Outputs &tt_out, size_t n)
{
    tt_out.departure_time.resize (n);
    tt_out.arrival_time.resize (n);
    tt_out.departure_station.resize (n);
    tt_out.arrival_station.resize (n);
    tt_out.trip_id.resize (n);
}

void timetable::make_timetable (const Timetable_Inputs &tt_in,
        Timetable_Outputs &tt_out,
        const std::vector <std::string> &stop_ids,
        const std::vector <std::string> &trip_ids)
{
    std::unordered_map <std::string, int> trip_id_map;
    int i = 1; // 1-indexed
    for (auto tr: trip_ids)
        trip_id_map.emplace (tr, i++);

    std::unordered_map <std::string, int> stop_id_map;
    i = 1;
    for (auto st: stop_ids)
        stop_id_map.emplace (st, i++);

    size_t n_connections = 0;
    std::string trip_id_i = tt_in.trip_id [0];
    int dest_stop = stop_id_map.at (tt_in.stop_id [0]);
    for (size_t i = 1; i < tt_in.trip_id.size (); i++)
    {
        if (tt_in.trip_id [i] == trip_id_i)
        {
            int arrival_stop = stop_id_map.at (tt_in.stop_id [i]);
            tt_out.departure_station [n_connections] = dest_stop;
            tt_out.arrival_station [n_connections] = arrival_stop;
            tt_out.departure_time [n_connections] = tt_in.departure_time [i - 1];
            tt_out.arrival_time [n_connections] = tt_in.arrival_time [i];
            tt_out.trip_id [n_connections] = trip_id_map.at (trip_id_i);
            dest_stop = arrival_stop;
            n_connections++;
        } else
        {
            dest_stop = stop_id_map.at (tt_in.stop_id [i]);
            trip_id_i = tt_in.trip_id [i];
        }
    }
}

// # nocov start
template <class T>
std::vector <T> vec_diff (std::vector <T> x)
{
    std::vector <T> res (x.size () - 1);
    for (int i = 1; i < x.size (); i++)
        res [i - 1] = x [i] - x [i - 1];
    return res;
}

//' rcpp_median_timetable
//' @noRd
// [[Rcpp::export]]
Rcpp::List rcpp_median_timetable (Rcpp::DataFrame full_timetable)
{
    std::vector <int>
        departure_station = full_timetable ["departure_station"],
        arrival_station = full_timetable ["arrival_station"],
        departure_time = full_timetable ["departure_time"],
        arrival_time = full_timetable ["arrival_time"];

    std::unordered_map <std::string, std::vector <int> > timetable;
    std::unordered_map <std::string, std::vector <int> > services;
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

        times.clear();
        if (services.find (stn_str) != services.end ())
            times = services.at (stn_str);
        times.push_back (departure_time [i]);
        services [stn_str] = times;
    }

    // TODO: timetable and services are by definition the same size, so the
    // following iteration could be combined to avoid the repetive string
    // parsing of station numbers, but that would no longer be as safe as the
    // auto iterators used here?
    size_t n = timetable.size ();
    std::vector <int> start_station_t (n), end_station_t (n),
        time_min (n), time_median (n), time_max (n);
    int i = 0;
    for (auto t: timetable)
    {
        std::string stn_str = t.first;
        size_t ipos = stn_str.find ("-");
        start_station_t [i] = atoi (stn_str.substr (0, ipos).c_str ());
        stn_str = stn_str.substr (ipos + 1, stn_str.size () - 1);
        end_station_t [i] = atoi (stn_str.c_str ());

        std::vector <int> times = t.second;
        std::sort (times.begin (), times.end ());
        time_min [i] = times [0];
        time_max [i] = times [times.size () - 1];
        ipos = round (times.size () / 2);
        time_median [i] = times [ipos];
        i++;
    }

    Rcpp::DataFrame times = Rcpp::DataFrame::create (
            Rcpp::Named ("departure_station") = start_station_t,
            Rcpp::Named ("arrival_station") = end_station_t,
            Rcpp::Named ("time_min") = time_min,
            Rcpp::Named ("time_median") = time_median,
            Rcpp::Named ("time_max") = time_max,
            Rcpp::_["stringsAsFactors"] = false);

    n = services.size ();
    std::vector <int> start_station_s (n), end_station_s (n),
        interval_min (n, INFINITE_INT),
        interval_median (n, INFINITE_INT),
        interval_max (n, INFINITE_INT);
    i = 0;
    for (auto s: services)
    {
        std::string stn_str = s.first;
        size_t ipos = stn_str.find ("-");
        start_station_s [i] = atoi (stn_str.substr (0, ipos).c_str ());
        stn_str = stn_str.substr (ipos + 1, stn_str.size () - 1);
        end_station_s [i] = atoi (stn_str.c_str ());

        std::vector <int> service_times = s.second;
        std::vector <int> service_interval = vec_diff (service_times);
        std::sort (service_interval.begin (), service_interval.end ());
        if (service_interval.size () > 0)
        {
            interval_min [i] = service_interval [0];
            interval_max [i] = service_interval [service_interval.size () - 1];
            ipos = round (service_interval.size () / 2);
            interval_median [i] = service_interval [ipos];
        }
        i++;
    }

    Rcpp::DataFrame intervals = Rcpp::DataFrame::create (
            Rcpp::Named ("departure_station") = start_station_s,
            Rcpp::Named ("arrival_station") = end_station_s,
            Rcpp::Named ("interval_min") = interval_min,
            Rcpp::Named ("interval_median") = interval_median,
            Rcpp::Named ("interval_max") = interval_max,
            Rcpp::_["stringsAsFactors"] = false);

    Rcpp::List res = Rcpp::List::create (
            Rcpp::Named ("times") = times,
            Rcpp::Named ("intervals") = intervals);

    return res;
}
// # nocov end
