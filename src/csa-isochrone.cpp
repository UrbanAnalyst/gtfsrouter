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

    CSA_Iso2 csa_iso2 (nstations + 1);

    const std::vector <size_t> departure_station = timetable ["departure_station"],
        arrival_station = timetable ["arrival_station"],
        trip_id = timetable ["trip_id"];
    const std::vector <int> departure_time = timetable ["departure_time"],
        arrival_time = timetable ["arrival_time"];

    const int actual_end_time = csaiso::find_actual_end_time (nrows, departure_time,
            departure_station, start_stations_set, start_time, end_time);

    //for (auto s: start_stations)
    //    csa_iso2.earliest_departure [s] = start_time;

    for (size_t i = 0; i < nrows; i++)
    {
        if (departure_time [i] < start_time)
            continue; // # nocov - these lines already removed in R fn.
        if (departure_time [i] > actual_end_time)
            break;

        const bool is_start_stn = start_stations_set.find (departure_station [i]) !=
            start_stations_set.end ();

        if (!is_start_stn &&
                csa_iso2.earliest_departure [departure_station [i]] >
                departure_time [i])
            continue;

        bool filled = csaiso::fill_one_csa_iso (departure_station [i],
                arrival_station [i], trip_id [i], departure_time [i],
                arrival_time [i], isochrone_val, is_start_stn, csa_iso2);

        if (filled && transfer_map.find (arrival_station [i]) != transfer_map.end ())
        {
            for (auto t: transfer_map.at (arrival_station [i]))
            {
                const size_t trans_dest = t.first;
                if (trans_dest == departure_station [i]) // can happen
                    continue;

                const int tr_time = arrival_time [i] + t.second;
                const int journey = tr_time + csa_iso2.earliest_departure [arrival_station [i]];
                if (journey > isochrone_val)
                    continue;

                if (tr_time < csa_iso2.earliest_departure [trans_dest])
                {
                    csa_iso2.earliest_departure [trans_dest] = tr_time;

                    const size_t s = csa_iso2.extend (trans_dest);

                    csa_iso2.connections [trans_dest].prev_stn [s] = arrival_station [i];
                    csa_iso2.connections [trans_dest].departure_time [s] = arrival_time [i];
                    csa_iso2.connections [trans_dest].arrival_time [s] = tr_time;

                    // Find the latest initial departure time for all services
                    // connecting to arrival station:
                    int earliest = -1;
                    int ntransfers = INFINITE_INT;

                    for (size_t j = 0; j < csa_iso2.connections [arrival_station [i]].initial_depart.size (); i++)
                    {
                        const int this_depart =
                            csa_iso2.connections [arrival_station [i]].initial_depart [j];
                        if (this_depart > earliest)
                        {
                            earliest = this_depart;
                            if (csa_iso2.connections [arrival_station [i]].ntransfers [j] < ntransfers)
                            {
                                ntransfers =
                                    csa_iso2.connections [arrival_station [i]].ntransfers [j];
                            }
                        }
                    }

                    csa_iso2.connections [trans_dest].ntransfers [s] = ntransfers;
                    csa_iso2.connections [trans_dest].initial_depart [s] = earliest;
                } // end if tr_time < earliest_departure
            } // end for t over transfer map
        } // end if filled
    } // end for i over nrows of timetable

    Rcpp::List res = csaiso::trace_back_isochrones (csa_iso2);

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
            departure_time;
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
        const int &isochrone,
        const bool &is_start_stn,
        CSA_Iso2 &csa_iso2) {

    bool fill_vals = false;
    int earliest = -1L;
    int ntransfers = INFINITE_INT;
    int latest_depart = -1L;

    if (is_start_stn)
    {
        fill_vals = true;
    } else
    {
        for (size_t i = 0; i < csa_iso2.connections [departure_station].initial_depart.size (); i++)
        {
            const int this_depart =
                csa_iso2.connections [departure_station].initial_depart [i];
            if (this_depart < INFINITE_INT && this_depart > latest_depart)
                latest_depart = this_depart;
            if (this_depart < INFINITE_INT)
            {
                if ((arrival_time - this_depart) <= isochrone)
                {
                    fill_vals = true;
                    if (this_depart > earliest)
                    {
                        earliest = this_depart;
                        if (csa_iso2.connections [departure_station].ntransfers [i] < ntransfers)
                            ntransfers = csa_iso2.connections [departure_station].ntransfers [i];
                    }

                }
            }
        }

        if (csa_iso2.is_end_stn [departure_station])
            csa_iso2.is_end_stn [departure_station] = false;
        if (csa_iso2.is_end_stn [arrival_station])
            csa_iso2.is_end_stn [arrival_station] = false;
    }

    if (!fill_vals && !is_start_stn && latest_depart > 0)
    {
        csa_iso2.is_end_stn [departure_station] = true;
        return false;
    }

    const size_t s = csa_iso2.extend (arrival_station) - 1;

    csa_iso2.connections [arrival_station].prev_stn [s] = departure_station;
    csa_iso2.connections [arrival_station].departure_time [s] = departure_time;
    csa_iso2.connections [arrival_station].arrival_time [s] = arrival_time;
    csa_iso2.connections [arrival_station].trip [s] = trip_id;

    if (csa_iso2.earliest_departure [arrival_station] > arrival_time)
        csa_iso2.earliest_departure [arrival_station] = arrival_time;

    if (is_start_stn)
    {
        csa_iso2.connections [arrival_station].ntransfers [s] = 0L;
        csa_iso2.connections [arrival_station].initial_depart [s] = departure_time;
        csa_iso2.earliest_departure [departure_station] = departure_time;
        csa_iso2.earliest_departure [arrival_station] = departure_time;
    } else
    {
        csa_iso2.connections [arrival_station].ntransfers [s] = ntransfers;
        csa_iso2.connections [arrival_station].initial_depart [s] = earliest;
    }

    return true;
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
        const CSA_Iso2 & csa_iso2
        )
{
    const size_t nend = std::accumulate (csa_iso2.is_end_stn.begin (),
            csa_iso2.is_end_stn.end (), 0L);

    std::vector <size_t> end_stations (nend);
    size_t count = 0;
    for (size_t s = 0; s < csa_iso2.is_end_stn.size (); s++)
    {
        if (csa_iso2.is_end_stn [s])
        {
            end_stations [count++] = s;
        }
    }

    Rcpp::List res (3 * nend);

    // TODO: Add prev_time to insert final values at isochrone start point

    count = 0;
    for (size_t es: end_stations)
    {
        std::vector <int> trip_out, end_station_out, end_times_out;
        size_t stn = es;

        end_station_out.push_back (static_cast <int> (stn));

        size_t prev_index = csaiso::trace_back_prev_index (csa_iso2, stn, INFINITE_INT);

        trip_out.push_back (csa_iso2.connections [stn].trip [prev_index]);
        size_t departure_time = csa_iso2.connections [stn].arrival_time [prev_index];
        end_times_out.push_back (departure_time);

        int temp = 0;
        while (prev_index < INFINITE_INT)
        {
            stn = csa_iso2.connections [stn].prev_stn [prev_index];

            prev_index = csaiso::trace_back_prev_index (csa_iso2, stn, departure_time);

            if (prev_index < INFINITE_INT)
            {
                end_station_out.push_back (static_cast <int> (stn));
                trip_out.push_back (csa_iso2.connections [stn].trip [prev_index]);
                departure_time = csa_iso2.connections [stn].arrival_time [prev_index];
                end_times_out.push_back (departure_time);
            }

            temp++;
            if (temp > csa_iso2.is_end_stn.size ())
                Rcpp::stop ("backtrace has no end");
        }

        std::reverse (end_station_out.begin (), end_station_out.end ());
        std::reverse (end_times_out.begin (), end_times_out.end ());
        std::reverse (trip_out.begin (), trip_out.end ());

        res (3 * count) = end_station_out;
        res (3 * count + 1) = trip_out;
        res (3 * count++ + 2) = end_times_out;
    }

    return res;
}

//' Returns INFINITE_INT if there are no previous stations, so this can be used
//' as a flag for start stations.
//' @param stn Station from which previous station is to be traced
//' @param departure_time Time of departure at that station, used to ensure that
//' only previous stations with arrival times prior to that specified departure
//' are selected. For end stations this departure_time is initially INF.
//' @noRd
size_t csaiso::trace_back_prev_index (
        const CSA_Iso2 & csa_iso2,
        const size_t & stn,
        const size_t & departure_time
        )
{
    int latest = -1L;
    size_t prev_index = INFINITE_INT;
    int ntransfers = INFINITE_INT;

    for (size_t i = 0; i < csa_iso2.connections [stn].prev_stn.size (); i++)
    {
        if (csa_iso2.connections [stn].initial_depart [i] >= latest &&
                csa_iso2.connections [stn].arrival_time [i] < departure_time)
        {
            latest = csa_iso2.connections [stn].initial_depart [i];
            prev_index = i;
            if (csa_iso2.connections [stn].ntransfers [i] < ntransfers)
            {
                ntransfers = csa_iso2.connections [stn].ntransfers [i];
                prev_index = i;
            }
        }
    }

    return (prev_index);
}
