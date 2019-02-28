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

void timetable::make_trip_stop_map (const std::vector <std::string> &input,
        std::unordered_map <std::string, int> &output_map)
{
    int count = 1; // 1-indexed
    for (auto i: input)
        output_map.emplace (i, count++);
}

void timetable::make_timetable (const Timetable_Inputs &tt_in,
        Timetable_Outputs &tt_out,
        const std::vector <std::string> &stop_ids,
        const std::vector <std::string> &trip_ids)
{
    std::unordered_map <std::string, int> trip_id_map;
    make_trip_stop_map (trip_ids, trip_id_map);

    std::unordered_map <std::string, int> stop_id_map;
    make_trip_stop_map (stop_ids, stop_id_map);

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
