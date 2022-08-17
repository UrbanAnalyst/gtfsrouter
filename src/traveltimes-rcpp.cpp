#include "traveltimes.h"

// Minimal Rcpp interfaces to R. All of the main work done in traveltimes.cpp,
// which is then pure C++.

//' rcpp_traveltimes
//'
//' Calculate isochrones using Connection Scan Algorithm for GTFS data. Works
//' largely as rcpp_csa. Returns a list of integer vectors, with [i] holding
//' sequences of stations on a given route, the end one being the terminal
//' isochrone point, and [i+1] holding correpsonding trip numbers.
//'
//' All elements of all data are 1-indexed
//'
//' @noRd
// [[Rcpp::export]]
Rcpp::IntegerMatrix rcpp_traveltimes (Rcpp::DataFrame timetable,
        Rcpp::DataFrame transfers,
        const size_t nstations,
        const std::vector <size_t> start_stations,
        const int start_time_min,
        const int start_time_max,
        const bool minimise_transfers,
        const int max_traveltime)
{

    // make start and end stations into std::unordered_sets to allow
    // constant-time lookup. stations are submitted as 0-based, while all other
    // values in timetable and transfers table are 1-based R indices, so all are
    // converted below to 0-based.
    std::unordered_set <size_t> start_stations_set;
    for (auto s: start_stations)
        start_stations_set.emplace (s);

    // convert transfers into a map from start to (end, transfer_time). Transfer
    // indices are 1-based.
    std::unordered_map <size_t, std::unordered_map <size_t, int> > transfer_map;
    iso::make_transfer_map (transfer_map,
            transfers ["from_stop_id"],
            transfers ["to_stop_id"],
            transfers ["min_transfer_time"]);

    Iso iso (nstations + 1, max_traveltime);

    const std::vector <size_t> departure_station = timetable ["departure_station"],
        arrival_station = timetable ["arrival_station"],
        trip_id = timetable ["trip_id"];
    const std::vector <int> departure_time = timetable ["departure_time"],
        arrival_time = timetable ["arrival_time"];

    iso::trace_forward_traveltimes (
            iso,
            start_time_min,
            start_time_max,
            departure_station,
            arrival_station,
            trip_id, 
            departure_time,
            arrival_time,
            transfer_map,
            start_stations_set,
            minimise_transfers);

    Rcpp::IntegerMatrix res = iso::trace_back_traveltimes (
            iso,
            minimise_transfers);

    return res;
}


Rcpp::IntegerMatrix iso::trace_back_traveltimes (
        const Iso & iso,
        const bool &minimise_transfers
        )
{
    const int nst = static_cast <int> (iso.is_end_stn.size ());

    Rcpp::IntegerMatrix res (nst, 3);

    size_t count = 0;

    for (auto s: iso.connections)
    {
        int ntransfers = INFINITE_INT;
        int duration = INFINITE_INT;
        int start_time = INFINITE_INT;
        
        for (auto con: s.convec)
        {
            if (con.is_transfer)
                continue;

            int this_duration = con.arrival_time - con.initial_depart;

            bool update = (minimise_transfers && con.ntransfers < ntransfers);
            if (!update && !minimise_transfers)
                update = this_duration < duration ||
                    (this_duration == duration && con.ntransfers < ntransfers);

            if (update)
            {
                ntransfers = con.ntransfers;
                duration = this_duration;
                start_time = con.initial_depart;
            }
        }

        res (count, 0) = start_time;
        res (count, 1) = duration;
        res (count++, 2) = ntransfers;
    }

    return res;
}
