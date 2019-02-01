#pragma once

#include <cstdlib> // atoi

#include <Rcpp.h>

typedef std::vector <std::vector <std::string> > str_vec2_t;
typedef std::unordered_map <std::string, std::vector <std::string> > transfer_time_map_t;

int convert_time_to_seconds (std::string hms);
Rcpp::IntegerVector rcpp_time_to_seconds (std::vector <std::string> times);

Rcpp::List rcpp_transfer_times (const Rcpp::DataFrame stop_times);
void group_trips_by_id (const Rcpp::DataFrame stop_times,
        str_vec2_t &trips_by_id);
