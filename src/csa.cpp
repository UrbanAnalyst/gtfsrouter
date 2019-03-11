#include "csa.h"

//' rcpp_csa
//'
//' Connection Scan Algorithm for GTFS data. The timetable has 
//' [deparutre_station, arrival_station, departure_time, arrival_time,
//'     trip_id],
//' with all entries as integer values, including times in seconds after
//' 00:00:00. The station and trip IDs can be mapped back on to actual station
//' IDs, but do not necessarily form a single set of unit-interval values
//' because the timetable is first cut down to only that portion after the
//' desired start time. These are nevertheless used as direct array indices
//' throughout, so are all size_t objects rather than int. All indices in the
//' timetable and transfers DataFrames, as well as start_/end_stations, are
//' 1-based, but they are still used directly which just means that the first
//' entries (that is, entry [0]) of station and trip vectors are never used.
//'
//' @noRd
// [[Rcpp::export]]
Rcpp::DataFrame rcpp_csa (Rcpp::DataFrame timetable,
        Rcpp::DataFrame transfers,
        const size_t nstations,
        const size_t ntrips,
        const std::vector <size_t> start_stations,
        const std::vector <size_t> end_stations,
        const int start_time,
        const int max_transfers)
{
    CSA_Parameters csa_pars;
    csa::fill_csa_pars (csa_pars, max_transfers, start_time,
            static_cast <size_t> (timetable.nrow ()), ntrips, nstations);

    std::unordered_set <size_t> start_stations_set, end_stations_set;
    csa::make_station_sets (start_stations, end_stations,
            start_stations_set, end_stations_set);

    CSA_Inputs csa_in;
    csa::make_transfer_map (csa_in.transfer_map, transfers);

    // The csa_out vectors use nstations + 1 because it's 1-indexed throughout,
    // and the first element is ignored.
    CSA_Outputs csa_out;
    csa_out.earliest_connection.resize (csa_pars.nstations + 1, INFINITE_INT);
    csa_out.n_transfers.resize (csa_pars.nstations + 1, 0);
    csa_out.prev_time.resize (csa_pars.nstations + 1, INFINITE_INT);
    csa_out.prev_stn.resize (csa_pars.nstations + 1, INFINITE_INT);
    csa_out.current_trip.resize (csa_pars.nstations + 1, INFINITE_INT);

    csa::get_earliest_connection (start_stations, csa_pars.start_time,
            csa_in.transfer_map, csa_out.earliest_connection);

    csa::csa_in_from_df (timetable, csa_in);

    CSA_Return csa_ret = csa::main_csa_loop (csa_pars, start_stations_set,
            end_stations_set, csa_in, csa_out);

    size_t route_len = csa::get_route_length (csa_out, csa_pars,
            csa_ret.end_station);

    std::vector <size_t> end_station_out (route_len),
        trip_out (route_len, INFINITE_INT);
    std::vector <int> time_out (route_len);

    csa::extract_final_trip (csa_out, csa_ret, end_station_out,
            trip_out, time_out);

    Rcpp::DataFrame res = Rcpp::DataFrame::create (
            Rcpp::Named ("stop_number") = end_station_out,
            Rcpp::Named ("time") = time_out,
            Rcpp::Named ("trip_number") = trip_out,
            Rcpp::_["stringsAsFactors"] = false);

    return res;
}

void csa::fill_csa_pars (CSA_Parameters &csa_pars, int max_transfers, int start_time,
        size_t timetable_size, size_t ntrips, size_t nstations)
{
    csa_pars.max_transfers = max_transfers;
    csa_pars.start_time = start_time;
    csa_pars.timetable_size = timetable_size;
    csa_pars.ntrips = ntrips;
    csa_pars.nstations = nstations;
}

// make start and end stations into std::unordered_sets to allow constant-time
// lookup.
void csa::make_station_sets (const std::vector <size_t> &start_stations,
        const std::vector <size_t> &end_stations,
        std::unordered_set <size_t> &start_stations_set,
        std::unordered_set <size_t> &end_stations_set)
{
    for (auto i: start_stations)
        start_stations_set.emplace (i);
    for (auto i: end_stations)
        end_stations_set.emplace (i);
}

void csa::csa_in_from_df (Rcpp::DataFrame &timetable,
        CSA_Inputs &csa_in)
{
    csa_in.departure_station = Rcpp::as <std::vector <size_t> > (
            timetable ["departure_station"]);
    csa_in.arrival_station = Rcpp::as <std::vector <size_t> > (
            timetable ["arrival_station"]);
    csa_in.trip_id = Rcpp::as <std::vector <size_t> > (
            timetable ["trip_id"]);
    csa_in.departure_time = Rcpp::as <std::vector <int> > (
            timetable ["departure_time"]);
    csa_in.arrival_time = Rcpp::as <std::vector <int> > (
            timetable ["arrival_time"]);
}

// convert transfers into a map from start to (end, transfer_time).
void csa::make_transfer_map (TransferMapType &transfer_map,
        Rcpp::DataFrame &transfers)
{
    transfer_map.clear ();
    std::vector <size_t> trans_from = transfers ["from_stop_id"],
        trans_to = transfers ["to_stop_id"];
    std::vector <int> trans_time = transfers ["min_transfer_time"];
    for (size_t i = 0; i < static_cast <size_t> (transfers.nrow ()); i++)
        if (trans_from [i] != trans_to [i])
        {
            std::unordered_map <size_t, int> transfer_pair; // station, time
            if (transfer_map.find (trans_from [i]) ==
                    transfer_map.end ())
            {
                transfer_pair.clear ();
                transfer_pair.emplace (trans_to [i], trans_time [i]);
                transfer_map.emplace (trans_from [i], transfer_pair);
            } else
            {
                transfer_pair = transfer_map.at (trans_from [i]);
                transfer_pair.emplace (trans_to [i], trans_time [i]);
                transfer_map [trans_from [i] ] = transfer_pair;
            }
        }
}

void csa::get_earliest_connection (
        const std::vector <size_t> &start_stations,
        const int &start_time,
        const TransferMapType &transfer_map,
        std::vector <int> &earliest_connection)
{
    for (size_t i = 0; i < start_stations.size (); i++)
    {
        earliest_connection [start_stations [i]] = start_time;
        if (transfer_map.find (start_stations [i]) !=
                transfer_map.end ())
        {
            std::unordered_map <size_t, int> transfer_pair =
                transfer_map.at (start_stations [i]);
            // Don't penalise these first footpaths:
            for (auto t: transfer_pair)
                earliest_connection [t.first] = start_time;
                //earliest_connection [t.first] = start_time + t.second;
        }
    }
}

CSA_Return csa::main_csa_loop (const CSA_Parameters &csa_pars,
        const std::unordered_set <size_t> &start_stations_set,
        std::unordered_set <size_t> &end_stations_set,
        const CSA_Inputs &csa_in,
        CSA_Outputs &csa_out)
{
    CSA_Return csa_ret;
    csa_ret.earliest_time = INFINITE_INT;
    csa_ret.end_station = INFINITE_INT;

    std::vector <bool> is_connected (csa_pars.ntrips, false);

    // trip connections:
    for (size_t i = 0; i < csa_pars.timetable_size; i++)
    {
        if (csa_in.departure_time [i] < csa_pars.start_time)
            continue; // # nocov - these lines already removed in R fn.

        // add all departures from start_stations_set:
        if (start_stations_set.find (csa_in.departure_station [i]) !=
                start_stations_set.end () &&
                csa_in.arrival_time [i] < csa_out.earliest_connection [csa_in.arrival_station [i] ])
        {
            is_connected [csa_in.trip_id [i] ] = true;
            csa::fill_one_csa_out (csa_out, csa_in, csa_in.arrival_station [i], i);
        }

        // main connection scan:
        if (((csa_out.earliest_connection [csa_in.departure_station [i] ] <= csa_in.departure_time [i]) &&
                    csa_out.n_transfers [csa_in.departure_station [i] ] < csa_pars.max_transfers) ||
                is_connected [csa_in.trip_id [i]])
        {
            if (csa_in.arrival_time [i] < csa_out.earliest_connection [csa_in.arrival_station [i] ])
            {
                csa::fill_one_csa_out (csa_out, csa_in, csa_in.arrival_station [i], i);

                csa_out.n_transfers [csa_in.arrival_station [i] ] =
                    csa_out.n_transfers [csa_in.departure_station [i] ];
            }
            csa::check_end_stations (end_stations_set, csa_in.arrival_station [i],
                    csa_in.arrival_time [i], csa_ret);

            if (csa_in.transfer_map.find (csa_in.arrival_station [i]) != csa_in.transfer_map.end ())
            {
                for (auto t: csa_in.transfer_map.at (csa_in.arrival_station [i]))
                {
                    size_t trans_dest = t.first;
                    int ttime = csa_in.arrival_time [i] + t.second;
                    if (ttime < csa_out.earliest_connection [trans_dest] &&
                            csa_out.n_transfers [trans_dest] <= csa_pars.max_transfers)
                    {
                        // modified version of fill_one_csa_out:
                        csa_out.earliest_connection [trans_dest] = ttime;
                        csa_out.prev_stn [trans_dest] = csa_in.arrival_station [i];
                        csa_out.prev_time [trans_dest] = csa_in.arrival_time [i];
                        csa_out.n_transfers [trans_dest]++;

                        csa::check_end_stations (end_stations_set,
                                trans_dest, ttime, csa_ret);

                    }
                }
            }
            is_connected [csa_in.trip_id [i]] = true;
        }
        if (end_stations_set.size () == 0)
            break;
    }
    return csa_ret;
}

void csa::fill_one_csa_out (CSA_Outputs &csa_out, const CSA_Inputs &csa_in,
        const size_t &i, const size_t &j)
{
    csa_out.earliest_connection [i] = csa_in.arrival_time [j];
    csa_out.current_trip [i] = csa_in.trip_id [j];
    csa_out.prev_stn [i] = csa_in.departure_station [j];
    csa_out.prev_time [i] = csa_in.departure_time [j];
}

void csa::check_end_stations (std::unordered_set <size_t> &end_stations_set,
        const size_t &arrival_station, const int &arrival_time,
        CSA_Return &csa_ret)
{
    if (end_stations_set.find (arrival_station) != end_stations_set.end ())
    {
        if (arrival_time < csa_ret.earliest_time)
        {
            csa_ret.earliest_time = arrival_time;
            csa_ret.end_station = arrival_station;
        }
        end_stations_set.erase (arrival_station);
    }
}

size_t csa::get_route_length (const CSA_Outputs &csa_out,
        const CSA_Parameters &csa_pars, const size_t &end_stn)
{
    size_t count = 1;
    size_t i = end_stn;
    while (i < INFINITE_INT)
    {
        count++;
        i = csa_out.prev_stn [static_cast <size_t> (i)];
        if (count > csa_pars.nstations)
            Rcpp::stop ("no route found; something went wrong"); // # nocov
    }

    return count;
}

void csa::extract_final_trip (const CSA_Outputs &csa_out,
        const CSA_Return &csa_ret,
        std::vector <size_t> &end_station,
        std::vector <size_t> &trip,
        std::vector <int> &time)
{
    size_t i = csa_ret.end_station;
    if (i > csa_out.current_trip.size ()) // No route able to be found
    {
        end_station.clear ();
        time.clear ();
        trip.clear ();
    } else
    {
        time [0] = csa_ret.earliest_time;
        trip [0] = csa_out.current_trip [i];
        end_station [0] = i;
        size_t count = 1;
        while (i < INFINITE_INT)
        {
            time [count] = csa_out.prev_time [i];
            i = csa_out.prev_stn [static_cast <size_t> (i)];
            end_station [count] = i;
            if (i < INFINITE_INT)
                trip [count] = csa_out.current_trip [i];
            count++;
        }
        // The last entry of these is all INF, so must be removed.
        end_station.resize (end_station.size () - 1);
        time.resize (time.size () - 1);
        trip.resize (trip.size () - 1);
        // trip values don't exist for start stations of each route, so
        for (size_t j = 1; j < trip.size (); j++)
            if (trip [j] == INFINITE_INT)
                trip [j] = trip [j - 1];
    }
}
