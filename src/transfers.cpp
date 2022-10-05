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

    std::unordered_map <std::pair <double, double>, std::unordered_set <size_t>, pair_hash> stop_map;
    std::unordered_map <size_t, std::pair <double, double>> stop_index;
    size_t count = 0;
    for (size_t i = 0; i < n; i++)
    {
        std::pair <double, double> xy_pair {stop_x [i], stop_y [i]};

        std::unordered_set <size_t> index_set;
        if (stop_map.find (xy_pair) != stop_map.end ())
        {
            index_set = stop_map.at (xy_pair);
        } else
        {
            stop_index.emplace (count++, xy_pair);
        }
        index_set.emplace (i);

        stop_map.erase (xy_pair);
        stop_map.emplace (xy_pair, index_set);
    }

    const size_t n_unique = stop_map.size ();

    Rcpp::List res (n * 2);

    for (size_t i = 0; i < n_unique; i++)
    {
        std::pair <double, double> xy_i = stop_index.at (i);
        std::unordered_set <size_t> index_i = stop_map.at (xy_i);

        const double cosy1 = cos (xy_i.second * pi / 180.0);

        std::vector <size_t> index;
        std::vector <double> dist;
        for (size_t j = 0; j < n_unique; j++)
        {
            std::pair <double, double> xy_j = stop_index.at (j);

            const double cosy2 = cos (xy_j.second * pi / 180.0);
            const double d_j = transfers::one_haversine (xy_i.first, xy_i.second,
                    xy_j.first, xy_j.second, cosy1, cosy2);
            if (d_j <= dlim)
            {
                std::unordered_set <size_t> index_j = stop_map.at (xy_j);
                for (auto k: index_j)
                {
                    index.push_back (k + 1L); // +1 for 1-based R index
                    dist.push_back (d_j);
                }
            }
        } // end for j

        // Then put those indices into expanded 'res', but need to exclude the
        // self-references from both
        for (auto j: index_i)
        {
            int self = -1;
            for (size_t k = 0; k < index.size (); k++) {
                if ((index [k] - 1L) == j) {
                    self = static_cast <int> (k);
                }
            }
            std::vector <size_t> index_j = index;
            std::vector <double> dist_j = dist;
            if (self >= 0)
            {
                index_j.erase (index_j.begin () + self);
                dist_j.erase (dist_j.begin () + self);
            }
            res (j) = index_j;
            res (n + j) = dist_j;
        }
    }

    return res;
}
