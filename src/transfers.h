#pragma once

#include <Rcpp.h>

typedef std::string StopType;

Rcpp::List rcpp_transfer_nbs (Rcpp::DataFrame stops,
        Rcpp::NumericMatrix dmat,
        const double dlim,
        const Rcpp::IntegerVector index);
