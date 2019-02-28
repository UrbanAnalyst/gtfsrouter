#pragma once

#include <Rcpp.h>

constexpr int INFINITE_INT =  std::numeric_limits<int>::max ();

typedef std::unordered_map <size_t, std::unordered_map <size_t, int> > 
    TransferMapType;

struct CSA_Parameters
{
    size_t timetable_size, ntrips, nstations;
    int start_time, max_transfers;
};

struct CSA_Inputs
{
    std::vector <size_t> departure_station,
        arrival_station, trip_id;
    std::vector <int> departure_time, arrival_time;
    TransferMapType transfer_map;
};

struct CSA_Outputs
{
    std::vector <int> earliest_connection, prev_time, n_transfers;
    std::vector <size_t> prev_stn, current_trip;
};

struct CSA_Return
{
    int end_station;
    size_t earliest_time;
};

// ---- csa-timetable.cpp
Rcpp::DataFrame rcpp_make_timetable (Rcpp::DataFrame stop_times,
        std::vector <std::string> stop_ids, std::vector <std::string> trip_ids);
Rcpp::List rcpp_median_timetable (Rcpp::DataFrame full_timetable);

// ---- csa.cpp
namespace csa {
void make_transfer_map (TransferMapType &transfer_map,
        Rcpp::DataFrame &transfers);
void get_earliest_connection (
        const std::vector <size_t> &start_stations,
        const int &start_time,
        const TransferMapType &transfer_map,
        std::vector <int> &earliest_connection);
CSA_Return main_csa_loop (const CSA_Parameters &csa_pars,
        const std::unordered_set <size_t> &start_stations_set,
        std::unordered_set <size_t> &end_stations_set,
        const CSA_Inputs &csa_inputs,
        CSA_Outputs &csa_out);
} // end namespace csa

Rcpp::DataFrame rcpp_csa (Rcpp::DataFrame timetable,
        Rcpp::DataFrame transfers,
        const size_t nstations,
        const size_t ntrips,
        const std::vector <size_t> start_stations,
        const std::vector <size_t> end_stations,
        const int start_time,
        const int max_transfers);

// ---- csa-isochrone.cpp
Rcpp::List rcpp_csa_isochrone (Rcpp::DataFrame timetable,
        Rcpp::DataFrame transfers,
        const size_t nstations,
        const size_t ntrips,
        const std::vector <size_t> start_stations,
        const int start_time, const int end_time);
