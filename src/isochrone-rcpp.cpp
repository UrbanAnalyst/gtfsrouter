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

    // make start and end stations into std::unordered_sets to allow
    // constant-time lookup. stations are submitted as 0-based, while all other
    // values in timetable and transfers table are 1-based R indices, so all are
    // converted below to 0-based.
    std::unordered_set <size_t> start_stations_set;
    for (auto s: start_stations)
        start_stations_set.emplace (s);

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

    csaiso::trace_forward_iso (csa_iso, start_time, end_time,
            departure_station, arrival_station, trip_id, 
            departure_time, arrival_time,
            transfer_map, start_stations_set, minimise_transfers);

    Rcpp::List res = csaiso::trace_back_isochrones (csa_iso, start_stations_set,
            minimise_transfers);

    return res;
}


Rcpp::List csaiso::trace_back_isochrones (
        const CSA_Iso & csa_iso,
        const std::unordered_set <size_t> & start_stations_set,
        const bool &minimise_transfers
        )
{
    const size_t nend = std::accumulate (csa_iso.is_end_stn.begin (),
            csa_iso.is_end_stn.end (), 0L);

    std::vector <size_t> end_stations (nend);
    size_t count = 0;
    for (size_t s = 0; s < csa_iso.is_end_stn.size (); s++)
    {
        if (csa_iso.is_end_stn [s])
        {
            end_stations [count++] = s;
        }
    }

    Rcpp::List res (3 * nend);

    count = 0;
    for (size_t es: end_stations)
    {
        std::vector <int> trip_out, end_station_out, end_times_out;
        size_t stn = es; // stn is arrival_stn

        size_t prev_index = csaiso::trace_back_first (csa_iso, stn);

        int arrival_time = csa_iso.connections [stn].convec [prev_index].arrival_time;
        int departure_time = csa_iso.connections [stn].convec [prev_index].departure_time;
        size_t departure_stn = csa_iso.connections [stn].convec [prev_index].prev_stn;
        size_t this_trip = csa_iso.connections [stn].convec [prev_index].trip;

        end_station_out.push_back (static_cast <int> (stn));
        trip_out.push_back (this_trip);
        end_times_out.push_back (arrival_time);

        int temp = 0;

        while (prev_index < INFINITE_INT)
        {
            stn = csa_iso.connections [stn].convec [prev_index].prev_stn;

            prev_index = csaiso::trace_back_prev_index (csa_iso, stn, departure_time, this_trip,
                    minimise_transfers);

            trip_out.push_back (this_trip);
            end_times_out.push_back (departure_time);

            if (prev_index < INFINITE_INT)
            {
                this_trip = csa_iso.connections [stn].convec [prev_index].trip;
                arrival_time = csa_iso.connections [stn].convec [prev_index].arrival_time;

                end_station_out.push_back (static_cast <int> (stn));

                departure_time = csa_iso.connections [stn].convec [prev_index].departure_time;
                departure_stn = csa_iso.connections [stn].convec [prev_index].prev_stn;
            }


            temp++;
            if (temp > csa_iso.is_end_stn.size ())
                Rcpp::stop ("backtrace has no end");
        }
        end_station_out.push_back (departure_stn);

        std::reverse (end_station_out.begin (), end_station_out.end ());
        std::reverse (end_times_out.begin (), end_times_out.end ());
        std::reverse (trip_out.begin (), trip_out.end ());

        // trips can end with transfers which have to be removed here
        while (trip_out.back () == INFINITE_INT)
        {
            end_station_out.resize (end_station_out.size () - 1);
            end_times_out.resize (end_times_out.size () - 1);
            trip_out.resize (trip_out.size () - 1);
        }

        if (trip_out.size () > 1)
        {
            res (3 * count) = end_station_out;
            res (3 * count + 1) = trip_out;
            res (3 * count++ + 2) = end_times_out;
        }
    }

    return res;
}
