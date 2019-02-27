#pragma once

#include <Rcpp.h>

constexpr int INFINITE_INT =  std::numeric_limits<int>::max ();

// ---- csa-timetable.cpp
Rcpp::DataFrame rcpp_make_timetable (Rcpp::DataFrame stop_times,
        std::vector <std::string> stop_ids, std::vector <std::string> trip_ids);
Rcpp::DataFrame rcpp_median_timetable (Rcpp::DataFrame timetable,
        Rcpp::DataFrame transfers, std::vector <std::string> stop_ids);

// ---- csa.cpp
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
