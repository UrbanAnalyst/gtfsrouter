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

        const bool is_start_stn = start_stations_set.find (departure_station [i]) !=
            start_stations_set.end ();

        if (!is_start_stn &&
                csa_iso.earliest_departure [departure_station [i]] < INFINITE_INT &&
                csa_iso.earliest_departure [departure_station [i]] >
                departure_time [i])
            continue;

        bool filled = csaiso::fill_one_csa_iso (departure_station [i],
                arrival_station [i], trip_id [i], departure_time [i],
                arrival_time [i], isochrone_val, is_start_stn, csa_iso);

        if (filled && transfer_map.find (arrival_station [i]) != transfer_map.end ())
        {
            for (auto t: transfer_map.at (arrival_station [i]))
            {
                const size_t trans_dest = t.first;
                const int tr_time = arrival_time [i] + t.second;

                bool insert_transfer = (trans_dest != departure_station [i]);
                if (!insert_transfer)
                    insert_transfer = !csaiso::is_transfer_in_isochrone (
                            csa_iso, arrival_station [i], tr_time, isochrone_val);
                if (!insert_transfer)
                    insert_transfer = !csaiso::is_transfer_quicker (
                            csa_iso, trans_dest, tr_time);

                if (!insert_transfer)
                    continue;

                csa_iso.earliest_departure [trans_dest] = tr_time;

                const size_t s = csa_iso.extend (trans_dest) - 1;

                csa_iso.connections [trans_dest].prev_stn [s] = arrival_station [i];
                csa_iso.connections [trans_dest].departure_time [s] = arrival_time [i];
                csa_iso.connections [trans_dest].arrival_time [s] = tr_time;

                // Find the latest initial departure time for all services
                // connecting to arrival station:
                int earliest = -1;
                int ntransfers = INFINITE_INT;

                for (size_t j = 0; j < csa_iso.connections [arrival_station [i]].initial_depart.size (); j++)
                {
                    const int this_initial =
                        csa_iso.connections [arrival_station [i]].initial_depart [j];
                    const int this_arrive =
                        csa_iso.connections [arrival_station [i]].arrival_time [j];
                    if (this_arrive <= arrival_time [i] && this_initial > earliest)
                    {
                        earliest = this_initial;
                        if (csa_iso.connections [arrival_station [i]].ntransfers [j] < ntransfers)
                        {
                            ntransfers =
                                csa_iso.connections [arrival_station [i]].ntransfers [j];
                        }
                    }
                }

                csa_iso.connections [trans_dest].ntransfers [s] = ntransfers;
                csa_iso.connections [trans_dest].initial_depart [s] = earliest;
                if (earliest > csa_iso.earliest_departure [trans_dest])
                    csa_iso.earliest_departure [trans_dest] = earliest;
            } // end for t over transfer map
        } // end if filled
    } // end for i over nrows of timetable

    Rcpp::List res = csaiso::trace_back_isochrones (csa_iso, start_stations_set);

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


bool csaiso::fill_one_csa_iso (
        const size_t &departure_station,
        const size_t &arrival_station,
        const size_t &trip_id,
        const int &departure_time,
        const int &arrival_time,
        const int &isochrone,
        const bool &is_start_stn,
        CSA_Iso &csa_iso) {

    bool fill_vals = false;
    int earliest = -1L;
    int prev_trip = -1L;
    int ntransfers = INFINITE_INT;
    int latest_depart = -1L;

    if (is_start_stn)
    {
        fill_vals = true;
    } else
    {
        for (size_t i = 0; i < csa_iso.connections [departure_station].initial_depart.size (); i++)
        {
            const int this_depart =
                csa_iso.connections [departure_station].initial_depart [i];
            if (this_depart < INFINITE_INT)
            {
                if (this_depart > latest_depart)
                    latest_depart = this_depart;
                if ((arrival_time - this_depart) <= isochrone)
                {
                    fill_vals = true;
                    if (this_depart >= earliest)
                    {
                        earliest = this_depart;
                        prev_trip = csa_iso.connections [departure_station].trip [i];
                        if (csa_iso.connections [departure_station].ntransfers [i] < ntransfers)
                            ntransfers = csa_iso.connections [departure_station].ntransfers [i];
                    }
                }
            }
        }

        if (csa_iso.is_end_stn [departure_station])
            csa_iso.is_end_stn [departure_station] = false;
        if (csa_iso.is_end_stn [arrival_station])
            csa_iso.is_end_stn [arrival_station] = false;
    }

    if (!fill_vals)
    {
        if (!is_start_stn && latest_depart > 0)
            csa_iso.is_end_stn [departure_station] = true;
    } else
    {
        const size_t s = csa_iso.extend (arrival_station) - 1;

        csa_iso.connections [arrival_station].prev_stn [s] = departure_station;
        csa_iso.connections [arrival_station].departure_time [s] = departure_time;
        csa_iso.connections [arrival_station].arrival_time [s] = arrival_time;
        csa_iso.connections [arrival_station].trip [s] = trip_id;

        if (csa_iso.earliest_departure [arrival_station] > arrival_time)
            csa_iso.earliest_departure [arrival_station] = arrival_time;

        if (is_start_stn)
        {
            csa_iso.connections [arrival_station].ntransfers [s] = 0L;
            csa_iso.connections [arrival_station].initial_depart [s] = departure_time;
            csa_iso.earliest_departure [departure_station] = departure_time;
            csa_iso.earliest_departure [arrival_station] = departure_time;
        } else
        {
            // Trip changes happen here mostly when services departing before the
            // nominated start time catch up with other services, so fastest trips
            // change services at same stop.
            if (trip_id != prev_trip)
                ntransfers++;

            csa_iso.connections [arrival_station].ntransfers [s] = ntransfers;
            csa_iso.connections [arrival_station].initial_depart [s] = earliest;
        }
    }

    return fill_vals;
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
        const CSA_Iso & csa_iso,
        const std::unordered_set <size_t> & start_stations_set
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

        size_t prev_index = csaiso::trace_back_prev_index (csa_iso, stn, INFINITE_INT, INFINITE_INT);

        int arrival_time = csa_iso.connections [stn].arrival_time [prev_index];
        int departure_time = csa_iso.connections [stn].departure_time [prev_index];
        size_t departure_stn = csa_iso.connections [stn].prev_stn [prev_index];
        size_t this_trip = csa_iso.connections [stn].trip [prev_index];

        end_station_out.push_back (static_cast <int> (stn));
        trip_out.push_back (this_trip);
        end_times_out.push_back (arrival_time);

        int temp = 0;

        while (prev_index < INFINITE_INT)
        {
            stn = csa_iso.connections [stn].prev_stn [prev_index];

            // stn is then the previous stn, while departure_time remains the
            // time of the service departing from that station. Connecting
            // services can only be traced back to those with arrival_time
            // values at stn that are <= departure_time.
            prev_index = csaiso::trace_back_prev_index (csa_iso, stn, departure_time, this_trip);

            trip_out.push_back (this_trip);
            end_times_out.push_back (departure_time);

            if (prev_index < INFINITE_INT)
            {
                this_trip = csa_iso.connections [stn].trip [prev_index];
                arrival_time = csa_iso.connections [stn].arrival_time [prev_index];

                end_station_out.push_back (static_cast <int> (stn));

                departure_time = csa_iso.connections [stn].departure_time [prev_index];
                departure_stn = csa_iso.connections [stn].prev_stn [prev_index];
            }

            /*
            if (prev_index < INFINITE_INT)
            {
                this_trip = csa_iso.connections [stn].trip [prev_index];
                arrival_time = csa_iso.connections [stn].arrival_time [prev_index];

                end_station_out.push_back (static_cast <int> (stn));

                departure_time = csa_iso.connections [stn].departure_time [prev_index];
                departure_stn = csa_iso.connections [stn].prev_stn [prev_index];
            } else
            {
                // Trace back to start station. departure_stn at that point is
                // the one after the start station, so still need to trace back
                // one further step, to insert original station and
                // departure_time. departure_time at that point is from
                end_station_out.push_back (departure_stn);

                int ntransfers = INFINITE_INT;
                departure_time = -1;
                for (size_t i = 0; i < csa_iso.connections [stn].prev_stn.size (); i++)
                {
                    if (csa_iso.connections [stn].departure_time [i] <= departure_time)
                    {
                        // Several OR expressions more clearly written as
                        // independent steps:
                        bool fill = (prev_index == INFINITE_INT);
                        if (!fill)
                            fill = (csa_iso.connections [stn].trip [i] == this_trip &&
                                    csa_iso.connections [stn].departure_time [i] > departure_time);
                        if (!fill)
                            fill = (csa_iso.connections [stn].ntransfers [i] < ntransfers);
                        if (!fill)
                            fill = (csa_iso.connections [stn].trip [i] == this_trip);

                        if (fill)
                        {
                            prev_index = i;
                            ntransfers = csa_iso.connections [stn].ntransfers [i];
                            departure_time = csa_iso.connections [stn].departure_time [i];
                            departure_stn = csa_iso.connections [stn].prev_stn [i];
                            this_trip = csa_iso.connections [stn].trip [i];
                        }
                    }
                }

                if (departure_stn != end_station_out.back ())
                {
                    end_station_out.push_back (departure_stn);
                    trip_out.push_back (this_trip);
                    end_times_out.push_back (departure_time);
                }
            }
            */

            temp++;
            if (temp > csa_iso.is_end_stn.size ())
                Rcpp::stop ("backtrace has no end");
        }
        end_station_out.push_back (departure_stn);

        // Trips can start with initial journeys between different start
        // stations, which can not be removed at the outset because the initial
        // connections set appropriate initial departure times for all
        // stations connected by such trips.
        /*
        while (start_stations_set.find (end_station_out [end_station_out.size () - 2]) !=
                start_stations_set.end ())
        {
            end_station_out.resize (end_station_out.size () - 1);
            end_times_out.resize (end_times_out.size () - 1);
            trip_out.resize (trip_out.size () - 1);
        }
        */

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
//' only previous stations with arrival times <= that specified departure
//' are selected. For end stations this departure_time is initially INF.
//' @noRd
size_t csaiso::trace_back_prev_index (
        const CSA_Iso & csa_iso,
        const size_t & stn,
        const size_t & departure_time,
        const int & trip_id
        )
{
    int latest = -1L;
    size_t prev_index = INFINITE_INT;
    int ntransfers = INFINITE_INT;

    for (size_t i = 0; i < csa_iso.connections [stn].prev_stn.size (); i++)
    {
        if (csa_iso.connections [stn].arrival_time [i] <= departure_time &&
                csa_iso.connections [stn].initial_depart [i] > latest)
        {
            // ******** UPDATE RULES *******
            // These accord with the following sequential priorities
            // 1. Station not yet reached
            // 2. Trip number should remain the same
            // 3. Initial departure time should be the latest possible
            // 4. Number of transfers should be as few as possible
            bool update = (trip_id == INFINITE_INT); // end stations
            if (!update) // keep on same trip
                update = (csa_iso.connections [stn].trip [i] == trip_id);
            if (!update) // leave as late as possible
                update = (csa_iso.connections [stn].initial_depart [i] > latest);
            if (!update) // connect with fewest transfers
                update = (csa_iso.connections [stn].ntransfers [i] < ntransfers);

            if (update)
            {
                prev_index = i;
                latest = csa_iso.connections [stn].initial_depart [i];
                ntransfers = csa_iso.connections [stn].ntransfers [i];
            }
        }
    }

    return (prev_index);
}

// Return a dummy value of 0 for stations which have not yet been reached, so
// they will be connected by transfer no matter what; otherwise return actual
// minimal journey time to that station.
const bool csaiso::is_transfer_in_isochrone (
        const CSA_Iso & csa_iso,
        const size_t & station,
        const int & transfer_time,
        const int & isochrone
        )
{
    int journey = 0L;
    if (csa_iso.earliest_departure [station] < INFINITE_INT)
        journey = transfer_time - csa_iso.earliest_departure [station];

    return (journey <= isochrone);
}

const bool csaiso::is_transfer_quicker (
        const CSA_Iso & csa_iso,
        const size_t & station,
        const int & transfer_time
        )
{
    const bool res = (transfer_time <= csa_iso.earliest_departure [station]);

    return res;
}
