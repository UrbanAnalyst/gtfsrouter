#include "traveltimes.h"

void iso::trace_forward_traveltimes (
        Iso & iso,
        const int & start_time_min,
        const int & start_time_max,
        const std::vector <size_t> & departure_station,
        const std::vector <size_t> & arrival_station,
        const std::vector <size_t> & trip_id,
        const std::vector <int> & departure_time,
        const std::vector <int> & arrival_time,
        const std::unordered_map <size_t, std::unordered_map <size_t, int> > & transfer_map,
        const std::unordered_set <size_t> & start_stations_set,
        const bool & minimise_transfers)
{
    const size_t nrows = departure_station.size ();

    std::unordered_map <size_t, bool> stations;
    for (size_t a: arrival_station)
        stations.emplace (std::make_pair (a, false));

    for (size_t i = 0; i < nrows; i++)
    {
        if (departure_time [i] < start_time_min)
            continue; // # nocov - these lines already removed in R fn.

        // connections can also arrive at one of the departure stations, and
        // these are also flagged as start stations to prevent transfers being
        // constructed from the arrival/start station.
        const bool arrive_at_start =
            iso::is_start_stn (start_stations_set, arrival_station [i]);
        const bool is_start_stn = arrive_at_start ||
            iso::is_start_stn (start_stations_set, departure_station [i]);

        if (arrive_at_start || (is_start_stn && departure_time [i] > start_time_max))
            continue;

        if (!is_start_stn &&
                (iso.earliest_departure [departure_station [i]] == INFINITE_INT ||
                 (iso.earliest_departure [departure_station [i]] < INFINITE_INT &&
                  iso.earliest_departure [departure_station [i]] > departure_time [i])))
        {
            continue;
        }

        bool filled = iso::fill_one_iso (departure_station [i],
                arrival_station [i], trip_id [i], departure_time [i],
                arrival_time [i], is_start_stn,
                minimise_transfers, iso);

        if (filled && !stations.at (arrival_station [i]))
        {
            stations [arrival_station [i]] = true;
        }

        // Exclude transfers from start stations; see #88. These can't be
        // included because they can't be allocated a start time from the
        // timetable, so are effectively considered to take no time, allowing
        // the algorithm to jump to nearby stations at same start time, which
        // mucks everything up.
        if (!is_start_stn && filled && transfer_map.find (arrival_station [i]) != transfer_map.end ())
        {
            for (auto t: transfer_map.at (arrival_station [i]))
            {
                const size_t trans_dest = t.first;
                const int trans_duration = t.second;

                if (!iso::is_start_stn (start_stations_set, trans_dest))
                {
                    iso::fill_one_transfer (
                            departure_station [i],
                            arrival_station [i],
                            arrival_time [i],
                            trans_dest,
                            trans_duration,
                            minimise_transfers,
                            iso);

                    if (stations.find (trans_dest) !=
                            stations.end ())
                    {
                        if (!stations.at (trans_dest))
                        {
                            stations [trans_dest] = true;
                        }
                    }
                }

            } // end for t over transfer map
        } // end if filled
    } // end for i over nrows of timetable
}



//' Translate one timetable line into values at arrival station
//'
//' The trace_back function requires each connection to have a corresponding
//' initial departure time and number of transfers. For each connection from a
//' departure to an arrival station, these have to be worked out by looping over
//' all connections to the departure station, and finding the best previous
//' connection in order to copy respective values across.
//'
//' @noRd
bool iso::fill_one_iso (
        const size_t &departure_station,
        const size_t &arrival_station,
        const size_t &trip_id,
        const int &departure_time,
        const int &arrival_time,
        const bool &is_start_stn,
        const bool &minimise_transfers,
        Iso &iso) {

    bool fill_vals = false, is_end_stn = false, same_trip = false;
    bool is_transfer = false;
    // is_transfer is used to increment "implicit" transfers to different
    // services from same stop_id, which do not otherwise appear as transfers.

    int ntransfers = INFINITE_INT;
    int latest_initial = -1L;

    if (is_start_stn)
    {
        fill_vals = true;
        ntransfers = 0;
        latest_initial = departure_time;
    } else
    {
        // fill_vals determines whether a connection is viable, which is if it
        // arrives at departure station prior to nominated departure time, and
        // arrives within isochrone time.
        //
        // This loop also determines whether a station is an end station, which
        // happens if the arrival time would extend beyond the isochrone value.
        // This requires one or more connections to meet this condition with no
        // conditions failing it. That requires an additional bool variable,
        // not_end_stn, which is set to true when any connection arrives within
        // time, while is_end_stn is only set to true when one or more
        // connections can reach the departure yet not arrival station. The
        // final value of is_end_stn is then only true is also !not_end_stn.

        bool not_end_stn = false;

        for (auto st: iso.connections [departure_station].convec)
        {
            // don't fill any connections > max_traveltime
            if ((arrival_time - st.initial_depart) > iso.get_max_traveltime ())
                continue;

            bool fill_here = (st.arrival_time <= departure_time);

            if (fill_here)
                not_end_stn = true;
            else if (!not_end_stn)
                is_end_stn = is_end_stn ||
                    ((departure_time - st.initial_depart) <= iso.get_max_traveltime ());

            if (fill_here || is_end_stn)
            {
                // Bunch of AND conditions written separately for clarity.
                same_trip = (st.trip == trip_id);
                // only follow same trip if it has equal fewest transfers
                bool update = (minimise_transfers &&
                        same_trip &&
                        st.ntransfers <= ntransfers &&
                        st.initial_depart > latest_initial);

                if (!update)
                {
                    update = (ntransfers == INFINITE_INT);
                }

                if (!same_trip)
                {
                    // only update if departure is after listed initial depart
                    update = departure_time > st.initial_depart;
                    // and if connection is a transfer, then only if
                    // arrival_time < listed departure time
                    if (update && st.is_transfer)
                    {
                        update = departure_time >= st.arrival_time;
                    }

                    // for !minimise_transfers, update if:
                    // 1. st.initial_depart > latest_initial OR
                    // 2. st.ntransfers < ntransfers &&
                    //      st.initial_depart == latest_initial
                    if (update)
                    {
                        update = iso::update_best_connection (
                                st.initial_depart,
                                latest_initial,
                                st.ntransfers,
                                ntransfers,
                                minimise_transfers);
                    }
                }

                if (update)
                {
                    DEBUGMSG("   update: (" << departure_station << " -> " <<
                            arrival_station << "), time(" <<
                            departure_time << " -> " <<
                            arrival_time << "); (dur, tr) = (" <<
                            arrival_time - st.initial_depart <<
                            ", " << st.ntransfers <<
                            "); init = " << latest_initial <<
                            " -> " << st.initial_depart <<
                            "; prev_stn = " << st.prev_stn <<
                            " on trip#" << st.trip << " -> " << trip_id <<
                            "; is_transfer = " << st.is_transfer,
                            departure_station, arrival_station,
                            departure_time);

                    latest_initial = st.initial_depart;
                    ntransfers = st.ntransfers;
                    is_transfer = st.is_transfer;
                }
            }

            // fill_vals will remain true whenever any single fill_here is true,
            // while is_end_stn = true must imply that fill_vals is false.
            fill_vals = fill_vals || fill_here;

            if (same_trip)
                break;
        }

        DEBUGMSG("--stn: (" << departure_station << " -> " <<
                arrival_station << "), time(" <<
                departure_time << " -> " <<
                arrival_time << "), dur = " <<
                arrival_time - latest_initial <<
                " with " << ntransfers << " transfers",
                departure_station, arrival_station,
                departure_time);

        is_end_stn = is_end_stn && !not_end_stn;

        if (is_end_stn)
        {
            iso.is_end_stn [departure_station] = true;
        } else
        {
            iso.is_end_stn [departure_station] = false;
            iso.is_end_stn [arrival_station] = false;
        }

    }

    if (!fill_vals)
        return false;

    const size_t s = iso.extend (arrival_station) - 1;

    iso.connections [arrival_station].convec [s].prev_stn = departure_station;
    iso.connections [arrival_station].convec [s].departure_time = departure_time;
    iso.connections [arrival_station].convec [s].arrival_time = arrival_time;
    iso.connections [arrival_station].convec [s].trip = trip_id;

    if (iso.earliest_departure [arrival_station] > arrival_time)
        iso.earliest_departure [arrival_station] = arrival_time;
            
    if (is_start_stn)
    {
        iso.connections [arrival_station].convec [s].ntransfers = 0L;
        iso.connections [arrival_station].convec [s].initial_depart = departure_time;
        iso.earliest_departure [departure_station] = departure_time;
        iso.earliest_departure [arrival_station] = departure_time;
    } else
    {
        if (!same_trip && !is_transfer)
        {
            // connections flagged with 'is_transfer' have already had transfers
            // incremented; this increments only "implicit" transfers from same
            // stop_id to different service (trip_id)
            ntransfers++;
        }
        iso.connections [arrival_station].convec [s].ntransfers = ntransfers;
        iso.connections [arrival_station].convec [s].initial_depart = latest_initial;
    }

    return fill_vals;
}


// Transfers are used to define the `earliest_departure` time, which is
// important to enable timetable lines to be skipped if:
//     iso.earliest_departure [departure_station [i]] > departure_time [i]
// It is nevertheless important to connect all possible transfers, because they
// may represent later initial departure times with subsequent connecting
// services.
void iso::fill_one_transfer (
        const size_t &departure_station,
        const size_t &arrival_station,
        const int &arrival_time,
        const size_t &trans_dest,
        const int &trans_duration,
        const bool &minimise_transfers,
        Iso &iso)
{
    const int trans_time = arrival_time + trans_duration;

    // Bunch of AND conditions separated for easy reading.
    bool insert_transfer = (trans_dest != departure_station); // can happen
    //if (insert_transfer)
    //    insert_transfer = iso::is_transfer_connected (
    //            iso, trans_dest, trans_time);
    if (insert_transfer)
        insert_transfer = iso::is_transfer_in_isochrone (
                iso, arrival_station, trans_time);

    if (!insert_transfer)
        return;

    if (iso.earliest_departure [trans_dest] == INFINITE_INT ||
            trans_time < iso.earliest_departure [trans_dest])
        iso.earliest_departure [trans_dest] = trans_time;

    const size_t s = iso.extend (trans_dest) - 1;

    iso.connections [trans_dest].convec [s].is_transfer = true;
    iso.connections [trans_dest].convec [s].prev_stn = arrival_station;
    iso.connections [trans_dest].convec [s].departure_time = arrival_time;
    iso.connections [trans_dest].convec [s].arrival_time = trans_time;

    // Find the latest initial departure time for all services
    // connecting to arrival station:
    int latest_initial = -1L;
    int ntransfers = INFINITE_INT;

    for (auto st: iso.connections [arrival_station].convec)
    {
        bool fill_here = (st.arrival_time <= arrival_time) &&
            ((arrival_time - st.initial_depart) <= iso.get_max_traveltime ());

        if (fill_here)
        {
            bool update = iso::update_best_connection (
                    st.initial_depart,
                    latest_initial,
                    st.ntransfers,
                    ntransfers,
                    minimise_transfers);

            if (update)
                update = (trans_time - st.initial_depart) < iso.get_max_traveltime();

            if (update)
            {
                ntransfers = st.ntransfers;
                latest_initial = st.initial_depart;
            }
        }
    }

    iso.connections [trans_dest].convec [s].ntransfers = ntransfers + 1;
    iso.connections [trans_dest].convec [s].initial_depart = latest_initial;

    DEBUGMSGTR("---TR: (" << arrival_station << " -> " <<
            trans_dest << "), time(" <<
            arrival_time << " -> " <<
            trans_time << ") - " << latest_initial <<
            " = " << trans_time - latest_initial <<
            "s with " << ntransfers << " transfers" <<
            "; INITIAL DEPART = " << latest_initial,
            trans_dest, arrival_time);
}

int iso::find_actual_end_time (
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

void iso::make_transfer_map (
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


void iso::trace_back_one_stn (
        const Iso & iso,
        BackTrace & backtrace,
        const size_t & end_stn,
        const bool &minimise_transfers
        )
{
    size_t stn = end_stn;

    size_t prev_index = iso::trace_back_first (iso, stn);

    int arrival_time = iso.connections [stn].convec [prev_index].arrival_time;
    int departure_time = iso.connections [stn].convec [prev_index].departure_time;
    size_t departure_stn = iso.connections [stn].convec [prev_index].prev_stn;
    size_t this_trip = iso.connections [stn].convec [prev_index].trip;

    backtrace.end_station.push_back (stn);
    backtrace.trip.push_back (this_trip);
    backtrace.end_times.push_back (arrival_time);

    size_t temp = 0;

    while (prev_index < INFINITE_INT)
    {
        stn = iso.connections [stn].convec [prev_index].prev_stn;

        prev_index = iso::trace_back_prev_index (iso, stn, departure_time, this_trip,
                minimise_transfers);

        backtrace.trip.push_back (this_trip);
        backtrace.end_times.push_back (departure_time);

        if (prev_index < INFINITE_INT)
        {
            this_trip = iso.connections [stn].convec [prev_index].trip;
            arrival_time = iso.connections [stn].convec [prev_index].arrival_time;

            backtrace.end_station.push_back (stn);

            departure_time = iso.connections [stn].convec [prev_index].departure_time;
            departure_stn = iso.connections [stn].convec [prev_index].prev_stn;
        }


        temp++;
        if (temp > iso.is_end_stn.size ())
            Rcpp::stop ("backtrace has no end");
    }
    backtrace.end_station.push_back (departure_stn);

    std::reverse (backtrace.end_station.begin (), backtrace.end_station.end ());
    std::reverse (backtrace.end_times.begin (), backtrace.end_times.end ());
    std::reverse (backtrace.trip.begin (), backtrace.trip.end ());

    // trips can end with transfers which have to be removed here
    while (backtrace.trip.back () == INFINITE_INT)
    {
        backtrace.end_station.resize (backtrace.end_station.size () - 1);
        backtrace.end_times.resize (backtrace.end_times.size () - 1);
        backtrace.trip.resize (backtrace.trip.size () - 1);
    }
}

// Trace back first connection from terminal station, which is simply the first
// equal shortest connection to that stn
size_t iso::trace_back_first (
        const Iso & iso,
        const size_t & stn
        )
{
    size_t prev_index = INFINITE_INT;
    int shortest_journey = INFINITE_INT;

    size_t index = 0;
    for (auto st: iso.connections [stn].convec)
    {
        const int journey = st.arrival_time - st.initial_depart;

        if (journey < shortest_journey)
        {
            shortest_journey = journey;
            prev_index = index;
        }

        index++;
    }

    return (prev_index);
}

size_t iso::trace_back_prev_index (
        const Iso & iso,
        const size_t & stn,
        const int & departure_time,
        const size_t & trip_id,
        const bool &minimise_transfers
        )
{
    size_t prev_index = INFINITE_INT;
    int ntransfers = INFINITE_INT;
    int latest_initial = -1l;

    bool same_trip = false;

    size_t index = 0;
    for (auto st: iso.connections [stn].convec)
    {
        if (st.arrival_time <= departure_time)
        {
            bool update = same_trip = (st.trip == trip_id);
            if (!update)
            {
                update = iso::update_best_connection (
                        st.initial_depart,
                        latest_initial,
                        st.ntransfers,
                        ntransfers,
                        minimise_transfers);
            }

            if (update)
            {
                prev_index = index;
                latest_initial = st.initial_depart;
                ntransfers = st.ntransfers;
            }
        }
        if (same_trip)
            break;

        index++;
    }

    return (prev_index);
}

bool iso::update_best_connection (
        const int & this_initial,
        const int & latest_initial,
        const int & this_transfers,
        const int & min_transfers,
        const bool &minimise_transfers)
{
    bool update = false;

    if (minimise_transfers)
    {

        update = (this_transfers < min_transfers);
        if (!update && (this_transfers == min_transfers))
            update = (this_initial > latest_initial);

    } else {

        update = (this_initial > latest_initial && this_transfers <= min_transfers);
        if (!update && this_transfers < min_transfers)
            update = (this_initial == latest_initial);

    }

    return update;
}


bool iso::is_transfer_connected (
        const Iso & iso,
        const size_t & station,
        const int & transfer_time
        )
{
    const bool res = (transfer_time <= iso.earliest_departure [station]);

    return res;
}

// Return a dummy value of 0 for stations which have not yet been reached, so
// they will be connected by transfer no matter what; otherwise return actual
// minimal journey time to that station.
bool iso::is_transfer_in_isochrone (
        Iso & iso,
        const size_t & station,
        const int & transfer_time
        )
{
    int journey = 0L;
    if (iso.earliest_departure [station] < INFINITE_INT)
        journey = transfer_time - iso.earliest_departure [station];

    return (journey <= iso.get_max_traveltime ());
}

bool iso::is_start_stn (
    const std::unordered_set <size_t> &start_stations_set,
    const size_t &stn)
{
    return start_stations_set.find (stn) != start_stations_set.end ();
}

// Is the arrival station already listed as a previous station of departure
// station?
//
// Example: A previous connection A -> B has already been read.
// On reading B -> A, first check that A (arrival_station) is not already a
// prior station of B (departure_station), so check over all connections for
// departure station (= B) to check that none of the listed "departure_station"
// -- NOT arrival_station -- values are A.
bool iso::arrival_already_visited (
        const Iso & iso,
        const size_t & departure_station,
        const size_t & arrival_station)
{
    bool check = false;
    for (auto st: iso.connections [departure_station].convec)
        if (st.prev_stn == arrival_station)
            check = true;

    return check;
}
