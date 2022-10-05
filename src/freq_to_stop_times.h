#pragma once

#include <Rcpp.h>

constexpr int INFINITE_INT =  std::numeric_limits<int>::max ();

namespace freq_to_stop_times {

} // end namespace freq_to_stop_times

Rcpp::DataFrame rcpp_freq_to_stop_times (Rcpp::DataFrame frequencies,
        Rcpp::DataFrame stop_times, const int nrows,
        const std::string sfx);
