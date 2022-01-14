#include "transfers.h"


//' rcpp_transfer_nbs
//'
//' Get nbs of every station within range dlim
//'
//' @noRd
// [[Rcpp::export]]
Rcpp::List rcpp_transfer_nbs (Rcpp::DataFrame stops,
        const Rcpp::NumericMatrix dmat,
        const double dlim)
{
    const size_t n = static_cast <size_t> (stops.nrow ());

    if (dmat.nrow () != n)
        Rcpp::stop ("dmat must be same size as stops");

    const std::vector <StopType> stop_id = stops ["stop_id"];

    Rcpp::List res (n);

    for (size_t i = 0; i < n; i++)
    {
        const StopType stop_i = stop_id [i];

        std::unordered_set <StopType> nbs;
        for (size_t j = 0; j < n; j++)
        {
            if (dmat (i, j) <= dlim)
            {
                nbs.emplace (stop_id [j]);
            }
        }

        res (i) = nbs;

        nbs.clear ();
    }

    return res;
}
