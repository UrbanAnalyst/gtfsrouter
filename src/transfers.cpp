#include "transfers.h"


//' rcpp_transfer_nbs
//'
//' Get nbs of every station within range dlim
//'
//' @noRd
// [[Rcpp::export]]
Rcpp::List rcpp_transfer_nbs (Rcpp::DataFrame stops,
        Rcpp::DataFrame ss_serv, // sorted by services
        Rcpp::DataFrame ss_stop, // sorted by sstops
        const Rcpp::NumericMatrix dmat,
        const double dlim)
{

    const size_t n = static_cast <size_t> (stops.nrow ());
    const size_t ns = static_cast <size_t> (ss_serv.nrow ());

    const std::vector <StopType> stop_id = stops ["stop_id"];

    if (dmat.nrow () != n)
        Rcpp::stop ("dmat must be same size as stops");

    // map from stops to services:
    const std::vector <StopType> ss_stop_stop = ss_stop ["stop_id"];
    const std::vector <StopType> ss_stop_service = ss_stop ["services"];
    std::unordered_map <StopType, StrSet > stop_service_map;
    StopType prev_stop = ss_stop_stop [0];
    StrSet stop_service_set;
    for (size_t i = 0; i < ns; i++)
    {
        if (ss_stop_stop [i] != prev_stop)
        {
            stop_service_map.emplace (prev_stop, stop_service_set);
            prev_stop = ss_stop_stop [i];
            stop_service_set.clear ();
        }
        stop_service_set.emplace (ss_stop_service [i]);
    }

    // map from services to stops:
    const std::vector <StopType> ss_serv_stop = ss_serv ["stop_id"];
    const std::vector <StopType> ss_serv_service = ss_serv ["services"];
    std::unordered_map <StopType, StrSet > service_stop_map;
    StopType prev_service = ss_serv_service [0];
    StrSet service_stop_set;
    for (size_t i = 0; i < ns; i++)
    {
        if (ss_serv_service [i] != prev_service)
        {
            service_stop_map.emplace (prev_service, service_stop_set);
            prev_service = ss_serv_service [i];
            service_stop_set.clear ();
        }
        service_stop_set.emplace (ss_serv_stop [i]);
    }

    Rcpp::List res (n);

    for (size_t i = 0; i < n; i++)
    {
        const StopType stop_i = stop_id [i];

        std::unordered_set <StopType> nbs;
        for (size_t j = 0; j < n; j++)
        {
            if (dmat (i, j) <= dlim)
            {
                bool in_services = false; // is stop [j] in connecting services?
                // Find services connecting from stop_id [i]:
                if (stop_service_map.find (stop_id [i]) != stop_service_map.end ())
                {
                    for (auto s: stop_service_map.at (stop_id [i])) {
                        if (service_stop_map.find (s) != service_stop_map.end ())
                        {
                            // Then find whether stop_id [j] in is those
                            // services:
                            if (service_stop_map.at (s).find (stop_id [j]) !=
                                    service_stop_map.at (s).end ())
                            {
                                in_services = true;
                                continue;
                            }
                        }
                    }
                }
                if (!in_services)
                    nbs.emplace (stop_id [j]);
            }
        }

        res (i) = nbs;

        nbs.clear ();
    }

    return res;
}
