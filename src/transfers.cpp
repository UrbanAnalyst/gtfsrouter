#include "transfers.h"


//' rcpp_transfer_nbs
//'
//' Get nbs of every station within range dlim
//'
//' @noRd
// [[Rcpp::export]]
Rcpp::List rcpp_transfer_nbs (Rcpp::DataFrame stops,
        const Rcpp::NumericMatrix dmat,
        const double dlim,
        const Rcpp::IntegerVector index)
{
    const size_t n = static_cast <size_t> (stops.nrow ());

    const std::vector <StopType> stop_id = stops ["stop_id"];

    Rcpp::List res (n);

    for (size_t i = 0; i < n; i++)
    {
        const size_t i_d = static_cast <size_t> (index [static_cast <int> (i)]);
        const StopType stop_i = stop_id [i];

        std::unordered_set <StopType> nbs;
        for (size_t j = 0; j < n; j++)
        {
            const size_t j_d = static_cast <size_t> (index [static_cast <int> (j)]);
            if (dmat (i_d, j_d) <= dlim)
            {
                nbs.emplace (stop_id [j]);
            }
        }

        res (i) = nbs;

        nbs.clear ();
    }

    return res;
}
