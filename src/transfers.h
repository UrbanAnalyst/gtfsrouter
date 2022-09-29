#pragma once

#include <Rcpp.h>

static const double earth = 6378137.0; // WSG-84 definition

#if defined(M_PI)
    static const double pi = M_PI;
#else
    static const double pi = atan2(0.0, -1.0);
#endif

namespace transfers {

double one_haversine (const double &x1, const double &y1,
        const double &x2, const double &y2,
        const double &cosy1, const double &cosy2);

} // end namespace transfers

Rcpp::List rcpp_transfer_nbs (Rcpp::DataFrame stops,
        const double dlim);
