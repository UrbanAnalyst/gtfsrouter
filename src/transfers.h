#pragma once

#include <Rcpp.h>

typedef std::string StopType;
typedef std::unordered_set <StopType> StrSet;

Rcpp::List rcpp_transfer_nbs (Rcpp::DataFrame stops,
        Rcpp::DataFrame ss_serv,
        Rcpp::DataFrame ss_stop,
        Rcpp::NumericMatrix dmat,
        const double dlim);
