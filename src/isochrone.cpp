#include "iso.h"

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


//' Translate one timetable line into values at arrival station
//'
//' The trace_back function requires each connection to have a corresponding
//' initial departure time and number of transfers. For each connection from a
//' departure to an arrival station, these have to be worked out by looping over
//' all connections to the departure station, and finding the best previous
//' connection in order to copy respective values across.
//'
//' @noRd
bool csaiso::fill_one_csa_iso (
        const size_t &departure_station,
        const size_t &arrival_station,
        const size_t &trip_id,
        const int &departure_time,
        const int &arrival_time,
        const int &isochrone,
        const bool &is_start_stn,
        const bool &minimise_transfers,
        CSA_Iso &csa_iso) {

    bool fill_vals = false, is_end_stn = false, same_trip = false;
    int prev_trip = -1L;
    int ntransfers = INFINITE_INT;
    int latest_initial = -1L;

    if (is_start_stn)
    {
        fill_vals = true;
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
        for (auto st: csa_iso.connections [departure_station].convec)
        {
            bool fill_here = (st.arrival_time <= departure_time) &&
                ((arrival_time - st.initial_depart) <= isochrone);

            if (fill_here)
                not_end_stn = true;
            else if (!not_end_stn)
                is_end_stn = is_end_stn || ((departure_time - st.initial_depart) <= isochrone);
            
            if (fill_here || is_end_stn)
            {
                bool update = same_trip = (st.trip == trip_id);
                if (!same_trip)
                {
                    update = csaiso::update_best_connection (st.initial_depart,
                            latest_initial, st.ntransfers, ntransfers,
                            minimise_transfers);
                }

                if (update)
                {
                    latest_initial = st.initial_depart;
                    prev_trip = st.trip;
                    ntransfers = st.ntransfers;
                }
            }

            // fill_vals will remain true whenever any single fill_here is true,
            // while is_end_stn = true must imply that fill_vals is false.
            fill_vals = fill_vals || fill_here;

            if (same_trip)
                break;
        }

        is_end_stn = is_end_stn && !not_end_stn;

        if (is_end_stn)
        {
            csa_iso.is_end_stn [departure_station] = true;
        } else
        {
            csa_iso.is_end_stn [departure_station] = false;
            csa_iso.is_end_stn [arrival_station] = false;
        }

    }

    if (!fill_vals)
        return false;

    const size_t s = csa_iso.extend (arrival_station) - 1;

    csa_iso.connections [arrival_station].convec [s].prev_stn = departure_station;
    csa_iso.connections [arrival_station].convec [s].departure_time = departure_time;
    csa_iso.connections [arrival_station].convec [s].arrival_time = arrival_time;
    csa_iso.connections [arrival_station].convec [s].trip = trip_id;

    if (csa_iso.earliest_departure [arrival_station] > arrival_time)
        csa_iso.earliest_departure [arrival_station] = arrival_time;

    if (is_start_stn)
    {
        csa_iso.connections [arrival_station].convec [s].ntransfers = 0L;
        csa_iso.connections [arrival_station].convec [s].initial_depart = departure_time;
        csa_iso.earliest_departure [departure_station] = departure_time;
        csa_iso.earliest_departure [arrival_station] = departure_time;
    } else
    {
        // Trip changes happen here mostly when services departing before the
        // nominated start time catch up with other services, so fastest trips
        // change services at same stop.
        if (!same_trip)
            ntransfers++;

        csa_iso.connections [arrival_station].convec [s].ntransfers = ntransfers;
        csa_iso.connections [arrival_station].convec [s].initial_depart = latest_initial;
    }

    return fill_vals;
}


void csaiso::fill_one_csa_transfer (
        const size_t &departure_station,
        const size_t &arrival_station,
        const int &arrival_time,
        const size_t &trans_dest,
        const int &trans_duration,
        const int &isochrone,
        const bool &minimise_transfers,
        CSA_Iso &csa_iso)
{
    const int trans_time = arrival_time + trans_duration;

    // Bunch of AND conditions separated for easy reading:
    bool insert_transfer = (trans_dest != departure_station); // can happen
    if (insert_transfer)
        insert_transfer = csaiso::is_transfer_connected (
                csa_iso, trans_dest, trans_time);
    if (insert_transfer)
        insert_transfer = csaiso::is_transfer_in_isochrone (
                csa_iso, arrival_station, trans_time, isochrone);

    if (!insert_transfer)
        return;

    csa_iso.earliest_departure [trans_dest] = trans_time;

    const size_t s = csa_iso.extend (trans_dest) - 1;

    csa_iso.connections [trans_dest].convec [s].prev_stn = arrival_station;
    csa_iso.connections [trans_dest].convec [s].departure_time = arrival_time;
    csa_iso.connections [trans_dest].convec [s].arrival_time = trans_time;

    // Find the latest initial departure time for all services
    // connecting to arrival station:
    int latest_initial = -1L;
    int ntransfers = INFINITE_INT;

    for (auto st: csa_iso.connections [arrival_station].convec)
    {
        bool fill_here = (st.arrival_time <= arrival_time) &&
            ((arrival_time - st.initial_depart) <= isochrone);
        if (fill_here)
        {
            const bool update = csaiso::update_best_connection (st.initial_depart,
                    latest_initial, st.ntransfers, ntransfers,
                    minimise_transfers);

            if (update)
            {
                ntransfers = st.ntransfers;
                latest_initial = st.initial_depart;
            }
        }
    }

    csa_iso.connections [trans_dest].convec [s].ntransfers = ntransfers + 1;
    csa_iso.connections [trans_dest].convec [s].initial_depart = latest_initial;
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

// Trace back first connection from terminal station, which is simply the first
// equal shortest connection to that stn
size_t csaiso::trace_back_first (
        const CSA_Iso & csa_iso,
        const size_t & stn
        )
{
    size_t prev_index = INFINITE_INT;
    int shortest_journey = INFINITE_INT;

    int index = 0;
    for (auto st: csa_iso.connections [stn].convec)
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

size_t csaiso::trace_back_prev_index (
        const CSA_Iso & csa_iso,
        const size_t & stn,
        const size_t & departure_time,
        const int & trip_id,
        const bool &minimise_transfers
        )
{
    size_t prev_index = INFINITE_INT;
    int ntransfers = INFINITE_INT;
    int latest_initial = -1l;

    bool same_trip = false;

    int index = 0;
    for (auto st: csa_iso.connections [stn].convec)
    {
        if (st.arrival_time <= departure_time)
        {
            bool update = same_trip = (st.trip == trip_id);
            if (!update)
            {
                update = csaiso::update_best_connection (st.initial_depart,
                        latest_initial, st.ntransfers, ntransfers,
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

bool csaiso::update_best_connection (
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

        update = (this_initial > latest_initial);
        if (!update && this_transfers < min_transfers)
            update = (this_initial == latest_initial);

    }

    return update;
}


const bool csaiso::is_transfer_connected (
        const CSA_Iso & csa_iso,
        const size_t & station,
        const int & transfer_time
        )
{
    const bool res = (transfer_time <= csa_iso.earliest_departure [station]);

    return res;
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

const bool csaiso::is_start_stn (
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
const bool csaiso::arrival_already_visited (
        const CSA_Iso & csa_iso,
        const size_t & departure_station,
        const size_t & arrival_station)
{
    bool check = false;
    for (auto st: csa_iso.connections [departure_station].convec)
        if (st.prev_stn == arrival_station)
            check = true;

    return check;
}
