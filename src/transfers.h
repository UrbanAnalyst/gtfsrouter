#pragma once

#include <set>
#include <unordered_set>
#include <unordered_map>

#include <Rcpp.h>

static const double earth = 6378137.0; // WSG-84 definition

constexpr int INFINITE_INT =  std::numeric_limits <int>::max ();

#if defined(M_PI)
    static const double pi = M_PI;
#else
    static const double pi = atan2(0.0, -1.0);
#endif

struct pair_hash
{
    template <class T1, class T2>
        std::size_t operator() (const std::pair<T1, T2> &pair) const {
            return std::hash<T1>()(pair.first) ^ std::hash<T2>()(pair.second);
        }
};

namespace transfers {

double one_haversine (const double &x1, const double &y1,
        const double &x2, const double &y2,
        const double &cosy1, const double &cosy2);

} // end namespace transfers

Rcpp::List rcpp_transfer_nbs (Rcpp::DataFrame stops,
        const double dlim);

Rcpp::List rcpp_transfer_nbs2 (Rcpp::DataFrame stops,
        const double dlim);
