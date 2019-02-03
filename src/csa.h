#pragma once

#include <Rcpp.h>

constexpr int INFINITE_INT =  std::numeric_limits<int>::max ();

Rcpp::List rcpp_make_timetable (Rcpp::DataFrame stop_times);

int rcpp_csa (Rcpp::DataFrame timetable,
        Rcpp::DataFrame transfers,
        const int nstations, const int ntrips,
        const std::vector <int> start_stations,
        const std::vector <int> end_stations,
        const int start_time);
