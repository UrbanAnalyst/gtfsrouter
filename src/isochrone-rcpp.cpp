#include "iso.h"

//' rcpp_csa_isochrone
//'
//' Calculate isochrones using Connection Scan Algorithm for GTFS data. Works
//' largely as rcpp_csa. Returns a list of integer vectors, with [i] holding
//' sequences of stations on a given route, the end one being the terminal
//' isochrone point, and [i+1] holding correpsonding trip numbers.
//'
//' All elements of all data are 1-indexed
//'
//' @noRd
// [[Rcpp::export]]
Rcpp::List rcpp_csa_isochrone (Rcpp::DataFrame timetable,
        Rcpp::DataFrame transfers,
        const size_t nstations,
        const size_t ntrips,
        const std::vector <size_t> start_stations,
        const int start_time,
        const int end_time,
        const bool minimise_transfers)
{

    const int isochrone_val = end_time - start_time;

    // make start and end stations into std::unordered_sets to allow
    // constant-time lookup. stations are submitted as 0-based, while all other
    // values in timetable and transfers table are 1-based R indices, so all are
    // converted below to 0-based.
    std::unordered_set <size_t> start_stations_set;
    for (auto s: start_stations)
        start_stations_set.emplace (s);

    const size_t nrows = static_cast <size_t> (timetable.nrow ());

    // convert transfers into a map from start to (end, transfer_time). Transfer
    // indices are 1-based.
    std::unordered_map <size_t, std::unordered_map <size_t, int> > transfer_map;
    csaiso::make_transfer_map (transfer_map,
            transfers ["from_stop_id"],
            transfers ["to_stop_id"],
            transfers ["min_transfer_time"]);

    CSA_Iso csa_iso (nstations + 1);

    const std::vector <size_t> departure_station = timetable ["departure_station"],
        arrival_station = timetable ["arrival_station"],
        trip_id = timetable ["trip_id"];
    const std::vector <int> departure_time = timetable ["departure_time"],
        arrival_time = timetable ["arrival_time"];

    const int actual_end_time = csaiso::find_actual_end_time (nrows, departure_time,
            departure_station, start_stations_set, start_time, end_time);

    for (size_t i = 0; i < nrows; i++)
    {
        if (departure_time [i] < start_time)
            continue; // # nocov - these lines already removed in R fn.
        if (departure_time [i] > actual_end_time)
            break;

        const bool is_start_stn = csaiso::is_start_stn (start_stations_set,
                departure_station [i]);

        if (!is_start_stn &&
                csa_iso.earliest_departure [departure_station [i]] < INFINITE_INT &&
                csa_iso.earliest_departure [departure_station [i]] >
                departure_time [i])
            continue;

        if (csaiso::arrival_already_visited (csa_iso,
                    departure_station [i], arrival_station [i]))
            continue;

        bool filled = csaiso::fill_one_csa_iso (departure_station [i],
                arrival_station [i], trip_id [i], departure_time [i],
                arrival_time [i], isochrone_val, is_start_stn,
                minimise_transfers, csa_iso);

        if (filled && transfer_map.find (arrival_station [i]) != transfer_map.end ())
        {
            for (auto t: transfer_map.at (arrival_station [i]))
            {
                const size_t trans_dest = t.first;
                const int trans_duration = t.second;

                if (!csaiso::is_start_stn (start_stations_set, trans_dest))
                {
                    csaiso::fill_one_csa_transfer (departure_station [i],
                            arrival_station [i], arrival_time [i], trans_dest,
                            trans_duration, isochrone_val,
                            minimise_transfers, csa_iso);
                }

            } // end for t over transfer map
        } // end if filled
    } // end for i over nrows of timetable

    Rcpp::List res = csaiso::trace_back_isochrones (csa_iso, start_stations_set,
            minimise_transfers);

    return res;
}
