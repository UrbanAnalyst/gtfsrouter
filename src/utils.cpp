#include "utils.h"

//' rcpp_transfer_times
//'
//' Works with a "transfer_map" which is a map between each transfer node and
//' all connecting nodes and departure times at those nodes.
//'
//' @noRd
// [[Rcpp::export]]
Rcpp::List rcpp_transfer_times (const Rcpp::DataFrame stop_times)
{
    std::vector <int> trip_id = stop_times ["trip_id"];
    std::vector <std::string> arrival_time = stop_times ["arrival_time"],
        departure_time = stop_times ["departure_time"],
        stop_id = stop_times ["stop_id"];

    str_vec2_t trips_by_id;
    group_trips_by_id (stop_times, trips_by_id);

    transfer_time_map_t transfer_map;

    for (int i = 0; i < trips_by_id.size (); i++)
    {
        int n = floor (trips_by_id [i].size () / 2);
        for (int j = 1; j < n; j++)
        {
            std::vector <std::string> times;
            if (transfer_map.find (trips_by_id [i] [j - 1]) ==
                    transfer_map.end ())
            {
                times.resize (1);
                times [0] = trips_by_id [i] [j + n];
                transfer_map.emplace (trips_by_id [i] [j - 1], times);
            } else
            {
                times = transfer_map.at (trips_by_id [i] [j - 1]);
                times.push_back (trips_by_id [i] [j + n]);
                transfer_map [trips_by_id [i] [j - 1] ] = times;
            }
        }
    }

    // Then convert those maps back into std::vectors to return as items of
    // Rcpp::List
    Rcpp::List res (transfer_map.size ());
    std::vector <std::string> names (transfer_map.size ());
    int count = 0;
    for (auto i: transfer_map)
    {
        names [count] = i.first;
        res [count] = i.second;
        count++;
    }
    res.attr ("names") = names;
    
    return res;
}

void group_trips_by_id (const Rcpp::DataFrame stop_times,
        str_vec2_t &trips_by_id)
{
    // First get lengths of trip_id vectors
    std::vector <int> trip_id = stop_times ["trip_id"];
    std::unordered_set <int> trip_id_set;
    for (int i = 0; i < trip_id.size (); i++)
        trip_id_set.emplace (trip_id [i]);
    std::vector <int> trip_lengths (trip_id_set.size (), 0);
    std::vector <int> trip_id_vec (trip_id_set.size ());
    int this_trip = trip_id [0];
    int trip_num = 0;
    for (int i = 0; i < trip_id.size (); i++)
    {
        if (trip_id [i] != this_trip)
        {
            this_trip = trip_id [i];
            trip_num++;
        }
        trip_lengths [trip_num]++;
        trip_id_vec [trip_num] = trip_id [i];
    }

    // Then fill the list with the actual id vectors
    //str_vec2_t res (trip_lengths.size () - 1);
    trips_by_id.resize (trip_lengths.size () - 1);
    std::vector <std::string> stop_ids = stop_times ["stop_id"],
        departure_time = stop_times ["departure_time"];
    std::vector <std::string> res_i;

    // result is single vector of stop_ids then departure_times
    res_i.resize (trip_lengths [0] * 2);

    this_trip = trip_id [0];
    trip_num = 0;
    int j = 0;
    for (int i = 0; i < trip_id.size (); i++)
    {
        if (trip_id [i] != this_trip)
        {
            //res [trip_num++] = res_i;
            trips_by_id [trip_num++] = res_i;
            this_trip = trip_id [i];
            res_i.resize (trip_lengths [trip_num] * 2);
            j = 0;
        }
        res_i [j] = stop_ids [i];
        res_i [trip_lengths [trip_num] + j++] = departure_time [i];
    }
}
