#pragma once

#include <Rcpp.h>

constexpr float INFINITE_FLOAT =  std::numeric_limits<float>::max ();
constexpr double INFINITE_DOUBLE =  std::numeric_limits<double>::max ();
constexpr int INFINITE_INT =  std::numeric_limits<int>::max ();

Rcpp::List rcpp_make_timetable (Rcpp::DataFrame stop_times);

Rcpp::List rcpp_csa (Rcpp::DataFrame timetable,
        Rcpp::DataFrame transfers,
        const std::vector <std::string> stations,
        const std::vector <int> trips,
        const std::vector <int> start_stations,
        const std::vector <int> end_stations,
        const int start_time);
