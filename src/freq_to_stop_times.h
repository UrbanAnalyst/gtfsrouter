#pragma once

#include <Rcpp.h>

namespace freq_to_stop_times {

} // end namespace freq_to_stop_times

Rcpp::List rcpp_freq_to_stop_times (Rcpp::DataFrame frequencies,
        Rcpp::DataFrame stop_times, const int n_timetables,
        const std::string sfx);
