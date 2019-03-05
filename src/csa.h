#pragma once

#include <Rcpp.h>

constexpr int INFINITE_INT =  std::numeric_limits<int>::max ();

typedef std::unordered_map <size_t, std::unordered_map <size_t, int> > 
    TransferMapType;

// ---- csa-timetable.cpp
struct Timetable_Inputs
{
    std::vector <std::string> stop_id, trip_id;
    std::vector <int> arrival_time, departure_time;
};

struct Timetable_Outputs
{
    std::vector <int> departure_time, arrival_time,
        departure_station, arrival_station, trip_id;
};

namespace timetable {
    void timetable_in_from_df (Rcpp::DataFrame &stop_times,
            Timetable_Inputs &tt_in);
    size_t count_connections (const Timetable_Inputs &tt_in);
    void initialise_tt_outputs (Timetable_Outputs &tt_out, size_t n);
    void make_trip_stop_map (const std::vector <std::string> &input,
            std::unordered_map <std::string, int> &output_map);
    void make_timetable (const Timetable_Inputs &tt_in,
            Timetable_Outputs &tt_out,
            const std::vector <std::string> &stop_ids,
            const std::vector <std::string> &trip_ids);
}

Rcpp::DataFrame rcpp_make_timetable (Rcpp::DataFrame stop_times,
        std::vector <std::string> stop_ids, std::vector <std::string> trip_ids);

// ---- csa.cpp
struct CSA_Parameters
{
    size_t timetable_size, ntrips, nstations;
    int start_time, max_transfers;
};

struct CSA_Inputs
{
    // stations and trips are size_t because they're used as direct array indices.
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

namespace csa {

void fill_csa_pars (CSA_Parameters &csa_pars, int max_transfers, int start_time,
        size_t timetable_size, size_t ntrips, size_t nstations);
void make_station_sets (const std::vector <size_t> &start_stations,
        const std::vector <size_t> &end_stations,
        std::unordered_set <size_t> &start_stations_set,
        std::unordered_set <size_t> &end_stations_set);
void csa_in_from_df (Rcpp::DataFrame &timetable,
        CSA_Inputs &csa_in);
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
void fill_one_csa_out (CSA_Outputs &csa_out, const CSA_Inputs &csa_in,
        const size_t &i, const size_t &j);
void check_end_stations (std::unordered_set <size_t> &end_stations_set,
        const size_t &arrival_station, const int &arrival_time,
        CSA_Return &csa_ret);
size_t get_route_length (const CSA_Outputs &csa_out,
        const CSA_Parameters &csa_pars, const size_t &end_stn);
void extract_final_trip (const CSA_Outputs &csa_out,
        const CSA_Return &csa_ret,
        std::vector <size_t> &end_station,
        std::vector <size_t> &trip,
        std::vector <int> &time);

} // end namespace csa

Rcpp::DataFrame rcpp_csa (Rcpp::DataFrame timetable,
        Rcpp::DataFrame transfers,
        const size_t nstations,
        const size_t ntrips,
        const std::vector <size_t> start_stations,
        const std::vector <size_t> end_stations,
        const int start_time,
        const int max_transfers);

// ---- csa-median-timetable.cpp
// # nocov start
struct Median_Vectors
{
    std::vector <int> depart_time, duration;
};

struct Median_Outputs
{
    std::vector <int> start_station, end_station,
        duration_min, duration_median, duration_max,
        interval_min, interval_median, interval_max;
};

struct GraphSimpleEdge {
    int to, dist;
};
// # nocov end

namespace median_timetable {

void fill_tt_inputs (Rcpp::DataFrame &full_timetable,
    Timetable_Outputs &tt_out);
void fill_timetable_services (const Timetable_Outputs &tt_in,
        std::unordered_map <std::string, Median_Vectors> &tt_vectors);
void fill_outputs (const std::unordered_map <std::string, Median_Vectors> &tt_vecs,
        Median_Outputs &med_out);
void fill_graph_inputs (Rcpp::DataFrame &timetable,
    Median_Outputs &gr_in);
void fill_transfer_inputs (Rcpp::DataFrame &transfers,
        std::unordered_map <std::string, int> &transfer_times);

} // end namespace median-timetable
Rcpp::DataFrame rcpp_median_timetable (Rcpp::DataFrame full_timetable);
Rcpp::DataFrame rcpp_median_graph (int nverts, Rcpp::DataFrame timetable,
        Rcpp::DataFrame transfers, int v0);

// ---- csa-isochrone.cpp
Rcpp::List rcpp_csa_isochrone (Rcpp::DataFrame timetable,
        Rcpp::DataFrame transfers,
        const size_t nstations,
        const size_t ntrips,
        const std::vector <size_t> start_stations,
        const int start_time, const int end_time);
