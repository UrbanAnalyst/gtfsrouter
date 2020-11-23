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
                arrival_time [i], isochrone_val, is_start_stn, csa_iso);

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
                            trans_duration, isochrone_val, csa_iso);
                }

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
                bool update = same_trip = (st.trip == prev_trip);
                if (!same_trip)
                {
                    update = (st.initial_depart > latest_initial);
                    if (!update && st.ntransfers < ntransfers)
                        update = (st.initial_depart == latest_initial);
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
            bool update = (st.initial_depart > latest_initial);
            if (!update && st.ntransfers < ntransfers)
                update = (st.initial_depart == latest_initial);

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

            prev_index = csaiso::trace_back_prev_index (csa_iso, stn, departure_time, this_trip);

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

// Trace back first connection from terminal station, which is simply the first
// equal shortest connection to that stn
size_t csaiso::trace_back_first (
        const CSA_Iso & csa_iso,
        const size_t & stn
        )
{
    int latest_initial = -1L;
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
        const int & trip_id
        )
{
    int latest = -1L;
    size_t prev_index = INFINITE_INT;
    int ntransfers = INFINITE_INT;
    int shortest_journey = INFINITE_INT;

    int this_trip = trip_id;

    int index = 0;
    for (auto st: csa_iso.connections [stn].convec)
    {
        if (st.arrival_time <= departure_time)
        {
            const int journey = departure_time - st.initial_depart;

            bool update = (st.trip == trip_id);
            if (!update)
                update = (journey < shortest_journey);
            if (!update && st.ntransfers < ntransfers)
                update = (journey <= shortest_journey);

            if (update)
            {
                prev_index = index;
                latest = st.initial_depart;
                ntransfers = st.ntransfers;
                this_trip = st.trip;
                shortest_journey = journey;
            }
        }
        index++;
    }

    return (prev_index);
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
