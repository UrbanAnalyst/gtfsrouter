#pragma once

#include <string>
#include <algorithm> // std::count
#include <cmath> // floor
#include <stdexcept>
#include <time.h>

#include <Rcpp.h>

// ----------  Functions to convert start time:  ----------
bool time_is_hhmmss (const std::string &hms);
bool time_is_hhmm (const std::string &hms);
bool time_is_lubridate (const std::string &hms);
int convert_time_hhmmss (std::string hms);
int convert_time_hhmm (std::string hms);
int convert_time_lubridate (std::string hms);
int rcpp_convert_time (const std::string &hms);

// ----------  Vector conversion of GTFS times:  ----------
int convert_time_to_seconds (std::string hms);
Rcpp::IntegerVector rcpp_time_to_seconds (std::vector <std::string> times);
