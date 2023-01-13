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


// [[Rcpp::export]]
Rcpp::List rcpp_transfer_nbs (Rcpp::DataFrame stops,
        const double dlim)
{
    const size_t n = static_cast <size_t> (stops.nrow ());

    const std::vector <double> stop_x = stops ["stop_lon"];
    const std::vector <double> stop_y = stops ["stop_lat"];

    Rcpp::List res (n * 2);
    // Initialize res:
    for (size_t i = 0; i < n; i++)
    {
        res (i) = std::vector <size_t> ();
        res (i + n) = std::vector <double> ();
    }

    for (size_t i = 0; i < (n - 1); i++)
    {
        const double cosy1 = cos (stop_y [i] * pi / 180.0);

        std::vector <size_t> index;
        std::vector <double> dist;
        for (size_t j = (i + 1); j < n; j++)
        {
            const double cosy2 = cos (stop_y [j] * pi / 180.0);
            const double d_j = transfers::one_haversine (stop_x [i], stop_y [i],
                    stop_x [j], stop_y [j], cosy1, cosy2);
            if (d_j <= dlim)
            {
                index.push_back (j);
                dist.push_back (d_j);
            }
        } // end for j

        // Each vector in 'res' needs to be extended by these new values:
        std::vector <size_t> index_i = res (i);
        std::vector <double> dist_i = res (n + i);
        for (size_t j = 0; j < index.size (); j++)
        {
            index_i.push_back (index [j]);
            dist_i.push_back (dist [j]);
        }

        res (i) = index_i;
        res (n + i) = dist_i;

        // But the 'j' values are only incrementally obtained, so have to be
        // expanded each time. Each element of 'index' has to be mapped back to
        // the 'res' entry, which needs an 'i' appended. Each element of 'dist'
        // maps back to 'res(index[j])`, and has to have 'd(i,j)' appended.
        for (size_t j = 0; j < index.size (); j++)
        {
            std::vector <size_t> vec_j = res (index [j]);
            vec_j.push_back (i);
            res (index [j]) = vec_j;

            std::vector <double> dist_j = res (index [j] + n);
            dist_j.push_back (dist [j]);
            res (index [j] + n) = dist_j;
        }

        index.clear ();
        dist.clear ();
    }

    // Then increment all 'index' values by 1 for 1-based R:
    for (size_t i = 0; i < n; i++)
    {
        std::vector <size_t> vec_i = res (i);
        for (size_t j = 0; j < vec_i.size (); j++)
        {
            vec_i [j] = vec_i [j] + 1;
        }
        res (i) = vec_i;
    }

    return res;
}
