#include "csa.h"

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
        const int start_time, const int end_time)
{

    const int duration = end_time - start_time;

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

    for (size_t i = 0; i < start_stations.size (); i++)
    {
        csa_iso.earliest_connection [start_stations [i]] = start_time;
    }

    const std::vector <size_t> departure_station = timetable ["departure_station"],
        arrival_station = timetable ["arrival_station"],
        trip_id = timetable ["trip_id"];
    const std::vector <int> departure_time = timetable ["departure_time"],
        arrival_time = timetable ["arrival_time"];

    const int actual_end_time = csaiso::find_actual_end_time (nrows, departure_time,
            departure_station, start_stations_set, start_time, end_time);

    std::vector <bool> is_connected (ntrips, false);

    std::unordered_set <size_t> end_stations;

    for (size_t i = 0; i < nrows; i++)
    {
        if (departure_time [i] < start_time)
            continue; // # nocov - these lines already removed in R fn.
        if (departure_time [i] > actual_end_time)
            break;

        // add all departures from start_stations_set:
        if (start_stations_set.find (departure_station [i]) !=
                start_stations_set.end () &&
                arrival_time [i] <= csa_iso.earliest_connection [arrival_station [i] ])
        {
            bool filled = csaiso::fill_one_start_stn (departure_station [i],
                    arrival_station [i], trip_id [i], departure_time [i],
                    arrival_time [i], csa_iso);

            if (filled)
            {
                is_connected [trip_id [i] ] = true;

                end_stations.emplace (arrival_station [i]);
            }
        }

        // main connection scan:
        if ((csa_iso.earliest_connection [departure_station [i] ] <= departure_time [i])
                || is_connected [trip_id [i]])
        {
            int elapsed = arrival_time [i] -
                csa_iso.trip_start_time [departure_station [i] ];
            if (elapsed < csa_iso.elapsed_time [arrival_station [i] ])
            {
                bool filled = csaiso::fill_one_csa_iso (departure_station [i],
                        arrival_station [i], trip_id [i], departure_time [i],
                        arrival_time [i], csa_iso);

                bool in_isochrone = (csa_iso.elapsed_time [arrival_station [i]] < duration);

                if (in_isochrone && filled) {
                    end_stations.emplace (arrival_station [i]);
                    end_stations.erase (departure_station [i]);
                }
            }

            if (transfer_map.find (arrival_station [i]) != transfer_map.end ())
            {
                for (auto t: transfer_map.at (arrival_station [i]))
                {
                    size_t trans_dest = t.first;
                    int ttime = arrival_time [i] + t.second;
                    if (ttime < csa_iso.earliest_connection [trans_dest])
                    {
                        // Note: transfers do not have a current_trip value
                        csa_iso.earliest_connection [trans_dest] = ttime;
                        csa_iso.elapsed_time [trans_dest] =
                            csa_iso.elapsed_time [arrival_station [i]] + t.second;
                        csa_iso.prev_stn [trans_dest] = arrival_station [i];
                        csa_iso.trip_start_time [trans_dest] =
                            csa_iso.trip_start_time [departure_station [i]];
                    }
                }
            }
            is_connected [trip_id [i]] = true;
        }
    }
   
    Rcpp::List res = csaiso::trace_back_isochrones (end_stations, csa_iso);

    return res;
}


void csaiso::make_transfer_map (
    std::unordered_map <size_t, std::unordered_map <size_t, int> > &transfer_map,
    const std::vector <size_t> &trans_from,
    const std::vector <size_t> &trans_to,
    const std::vector <int> &trans_time
        )
{
    for (size_t i = 0; i < static_cast <size_t> (trans_from.size ()); i++)
    {
        if (trans_from [i] != trans_to [i])
        {
            std::unordered_map <size_t, int> transfer_pair; // station, time
            if (transfer_map.find (trans_from [i]) == transfer_map.end ())
            {
                transfer_pair.clear ();
                transfer_pair.emplace (trans_to [i], trans_time [i]);
                transfer_map.emplace (trans_from [i], transfer_pair);
            } else
            {
                transfer_pair = transfer_map.at (trans_from [i]);
                transfer_pair.emplace (trans_to [i], trans_time [i]);
                transfer_map [trans_from [i]] = transfer_pair;
            }
        }
    }
}

bool csaiso::fill_one_start_stn (
        const size_t &departure_station,
        const size_t &arrival_station,
        const size_t &trip_id,
        const int &departure_time,
        const int &arrival_time,
        CSA_Iso &csa_iso) {

    bool fill_vals = (arrival_time < csa_iso.earliest_connection [arrival_station]);
    if (!fill_vals) {
        // service at that time already exists, so only replace if trip_id of
        // csa_in is same as trip that connected to the departure station.
        // This clause ensures connection remains on same service in cases of
        // parallel services; see #48 and equivalent code in csa.cpp
        const size_t prev_trip = csa_iso.current_trip [departure_station];
        fill_vals = (prev_trip < INFINITE_INT &&
                trip_id == csa_iso.current_trip [departure_station]);

        if (!fill_vals && csa_iso.trip_start_time [departure_station] < INFINITE_INT)
            fill_vals = ((arrival_time - csa_iso.trip_start_time [departure_station]) <
                    csa_iso.elapsed_time [arrival_station]);
    }

    if (fill_vals) {

        csa_iso.earliest_connection [arrival_station] = arrival_time;
        csa_iso.elapsed_time [arrival_station] = arrival_time -
            csa_iso.trip_start_time [departure_station];
        csa_iso.current_trip [arrival_station] = trip_id;
        csa_iso.prev_stn [arrival_station] = departure_station;
        // fill in trip_id from departure_station only for the start of trips:
        if (csa_iso.current_trip [departure_station] == INFINITE_INT)
            csa_iso.current_trip [departure_station] = trip_id;
        // propagate trip start time from departure to arrival station:
        if (csa_iso.trip_start_time [arrival_station] >
                csa_iso.trip_start_time [departure_station])
            csa_iso.trip_start_time [arrival_station] =
                csa_iso.trip_start_time [departure_station];

        if (csa_iso.trip_start_time [departure_station] == INFINITE_INT ||
                csa_iso.trip_start_time [departure_station] < departure_time)
            csa_iso.trip_start_time [departure_station ] = departure_time;
        if (csa_iso.trip_start_time [arrival_station] == INFINITE_INT ||
                csa_iso.trip_start_time [arrival_station] < departure_time)
            csa_iso.trip_start_time [arrival_station ] = departure_time;
        csa_iso.elapsed_time [departure_station] = 0L;
        csa_iso.elapsed_time [arrival_station] =
            arrival_time - csa_iso.trip_start_time [departure_station];
    }

    return (fill_vals);
}

bool csaiso::fill_one_csa_iso (
        const size_t &departure_station,
        const size_t &arrival_station,
        const size_t &trip_id,
        const int &departure_time,
        const int &arrival_time,
        CSA_Iso &csa_iso) {

    bool fill_vals = (arrival_time < csa_iso.earliest_connection [arrival_station]);
    if (!fill_vals) {
        // service at that time already exists, so only replace if trip_id of
        // csa_in is same as trip that connected to the departure station.
        // This clause ensures connection remains on same service in cases of
        // parallel services; see #48 and equivalent code in csa.cpp
        const size_t prev_trip = csa_iso.current_trip [departure_station];
        fill_vals = (prev_trip < INFINITE_INT &&
                trip_id == csa_iso.current_trip [departure_station]);

        if (!fill_vals && csa_iso.trip_start_time [departure_station] < INFINITE_INT)
            fill_vals = ((arrival_time - csa_iso.trip_start_time [departure_station]) <
                    csa_iso.elapsed_time [arrival_station]);
    }

    if (fill_vals) {

        csa_iso.earliest_connection [arrival_station] = arrival_time;
        csa_iso.elapsed_time [arrival_station] = arrival_time -
            csa_iso.trip_start_time [departure_station];
        csa_iso.current_trip [arrival_station] = trip_id;
        csa_iso.prev_stn [arrival_station] = departure_station;
        // fill in trip_id from departure_station only for the start of trips:
        if (csa_iso.current_trip [departure_station] == INFINITE_INT)
            csa_iso.current_trip [departure_station] = trip_id;
        // propagate trip start time from departure to arrival station:
        if (csa_iso.trip_start_time [arrival_station] >
                csa_iso.trip_start_time [departure_station])
            csa_iso.trip_start_time [arrival_station] =
                csa_iso.trip_start_time [departure_station];
    }

    return (fill_vals);
}

int csaiso::find_actual_end_time (
        const size_t &n,
        const std::vector <int> &departure_time,
        const std::vector <size_t> &departure_station,
        const std::unordered_set <size_t> &start_stations_set,
        const int &start_time,
        const int &end_time)
{
    // Find time of first departing service from one of the start_stations
    bool found = false;
    int actual_start_time = INFINITE_INT;
    int actual_end_time = INFINITE_INT;
    for (size_t i = 0; i < n; i++)
    {
        if (departure_time [i] < start_time)
            continue; // # nocov - these lines already removed in R fn.

        // add all departures from start_stations_set:
        if (start_stations_set.find (departure_station [i]) !=
                start_stations_set.end ())
        {
            actual_start_time = departure_time [i];
            found = true;
        }
        if (found)
            break;
    }
    // Scan up until twice the isochrone duration from the actual start time:
    if (actual_start_time < INFINITE_INT)
        actual_end_time = 2 * (end_time - start_time) + actual_start_time;

    return (actual_end_time);
}

Rcpp::List csaiso::trace_back_isochrones (
        const std::unordered_set <size_t> &end_stations,
        const CSA_Iso & csa_iso
        )
{
    Rcpp::List res (3 * end_stations.size ());
    size_t count = 0;
    int time;
    for (auto es: end_stations)
    {
        std::vector <int> trip_out, end_station_out, end_times_out;
        size_t i = es;
        int prev_time; // holds original departure time at end
        if (csa_iso.current_trip [i] == INFINITE_INT)
            continue;

        trip_out.push_back (static_cast <int> (csa_iso.current_trip [i]));
        end_station_out.push_back (static_cast <int> (i));
        while (i < INFINITE_INT)
        {
            //time = csa_iso.prev_arrival_time [i];
            time = csa_iso.trip_start_time [i] + csa_iso.elapsed_time [i];
            if (time < INFINITE_INT && csa_iso.current_trip [i] < INFINITE_INT) {
                end_times_out.push_back (static_cast <int> (time));
                end_station_out.push_back (static_cast <int> (i));
                trip_out.push_back (static_cast <int> (csa_iso.current_trip [i]));

                //if (csa_iso.prev_time [i] < INFINITE_INT)
                //    prev_time = csa_iso.prev_time [i];
            }
            i = csa_iso.prev_stn [static_cast <size_t> (i)];
            if (i < INFINITE_INT)
                prev_time = csa_iso.trip_start_time [i] + csa_iso.elapsed_time [i];
        }
        
        end_times_out.push_back (prev_time);

        std::reverse (end_station_out.begin (), end_station_out.end ());
        std::reverse (end_times_out.begin (), end_times_out.end ());
        std::reverse (trip_out.begin (), trip_out.end ());

        res (3 * count) = end_station_out;
        res (3 * count + 1) = trip_out;
        res (3 * count++ + 2) = end_times_out;
    }

    return res;
}
