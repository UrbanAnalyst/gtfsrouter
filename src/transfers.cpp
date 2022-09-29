#include "transfers.h"

//' Haversine for variable x and y
//'
//' @return single distance
//'
//' @note The sxd and syd values could be calculated in arrays, each value of
//' which could be determined with only n operations, rather than the n2 used
//' here. Doing so, however, requires very large C arrays which are often
//' problematic, so this is safer.
//'
//' @noRd
double transfers::one_haversine (const double &x1, const double &y1,
        const double &x2, const double &y2,
        const double &cosy1, const double &cosy2)
{
    double sxd = sin ((x2 - x1) * M_PI / 360.0);
    double syd = sin ((y2 - y1) * M_PI / 360.0);
    double d = syd * syd + cosy1 * cosy2 * sxd * sxd;
    d = 2.0 * earth * asin (sqrt (d));
    return (d);
}


//' rcpp_transfer_nbs
//'
//' Get nbs of every station within range dlim
//'
//' @noRd
// [[Rcpp::export]]
Rcpp::List rcpp_transfer_nbs (Rcpp::DataFrame stops,
        const double dlim)
{
    const size_t n = static_cast <size_t> (stops.nrow ());

    const std::vector <double> stop_x = stops ["stop_lon"];
    const std::vector <double> stop_y = stops ["stop_lat"];

    Rcpp::List res (n * 2);

    for (size_t i = 0; i < n; i++)
    {
        const double cosy1 = cos (stop_y [i] * pi / 180.0);

        //std::unordered_set <TransferPair, pair_hash> nbs;
        std::vector <size_t> index;
        std::vector <double> dist;
        for (size_t j = 0; j < n; j++)
        {
            if (j == i) continue;

            const double cosy2 = cos (stop_y [j] * pi / 180.0);
            const double d_j = transfers::one_haversine (stop_x [i], stop_y [i],
                    stop_x [j], stop_y [j], cosy1, cosy2);
            if (d_j <= dlim)
            {
                // + 1 so can be returned as 1-based R index:
                //nbs.emplace (j + 1, d_j);
                index.push_back (j + 1);
                dist.push_back (d_j);
            }
        }

        //res (i) = nbs;
        res (i) = index;
        res (n + i) = dist;

        //nbs.clear ();
    }

    return res;
}
