#include "freq_to_stop_times.h"

//' rcpp_freq_to_stop_times
//'
//' @noRd
// [[Rcpp::export]]
Rcpp::DataFrame rcpp_freq_to_stop_times (Rcpp::DataFrame frequencies,
        Rcpp::DataFrame stop_times, const size_t nrows,
        const std::string sfx)
{
    const std::vector <std::string> f_trip_id = frequencies ["trip_id"];
    const std::vector <int> f_start_time = frequencies ["start_time"];
    // const std::vector <int> f_end_time = frequencies ["end_time"];
    const std::vector <int> f_headway = frequencies ["headway_secs"];
    const std::vector <int> f_nseq = frequencies ["nseq"];

    const size_t ntrips = static_cast <size_t> (frequencies.nrow ());

    const std::vector <std::string> st_trip_id = stop_times ["trip_id"];
    const std::vector <int> st_arrival_time = stop_times ["arrival_time"];
    const std::vector <int> st_departure_time = stop_times ["departure_time"];
    const std::vector <std::string> st_stop_id = stop_times ["stop_id"];
    const std::vector <int> st_stop_seq = stop_times ["stop_sequence"];

    std::vector <std::string> trip_id (nrows);
    std::vector <int> arrival_time (nrows);
    std::vector <int> departure_time (nrows);
    std::vector <std::string> stop_id (nrows);
    std::vector <int> stop_sequence (nrows);

    size_t row = 0;

    std::unordered_set <std::string> trip_id_set;

    for (size_t i = 0; i < ntrips; i++)
    {
        Rcpp::checkUserInterrupt ();

        const std::string trip_id_i = f_trip_id [i];
        const int headway_i = f_headway [i];
        const int start_time_i = f_start_time [i];

        const int nseq_i = f_nseq [i];

        // Get the base timetable
        size_t tt_start = INFINITE_INT, tt_end = 0;
        bool found = false;
        for (size_t j = 0; j < st_trip_id.size (); j++)
        {
            if (std::strcmp (st_trip_id [j].c_str (), trip_id_i.c_str ()) == 0L)
            {
                found = true;
                if (j < tt_start)
                {
                    tt_start = j;
                } else if (j > tt_end)
                {
                    tt_end = j;
                }
            } else if (found)
            {
                break;
            }
        }
        const size_t tt_len = tt_end - tt_start + 1L;
        std::vector <int> arrival_time_sub (tt_len);
        std::vector <int> departure_time_sub (tt_len);
        std::vector <std::string> stop_id_sub (tt_len);
        std::vector <int> stop_sequence_sub (tt_len);

        for (auto j = tt_start; j <= tt_end; j++)
        {
            arrival_time_sub [j - tt_start] = st_arrival_time [j] + start_time_i;
            departure_time_sub [j - tt_start] = st_departure_time [j] + start_time_i;
            stop_id_sub [j - tt_start] = st_stop_id [j];
            stop_sequence_sub [j - tt_start] = st_stop_seq [j];
        }

        for (int n = 0; n < nseq_i; n++) {

            int n_unique = n;
            std::string trip_id_n =
                static_cast <std::string> (trip_id_i) + sfx + std::to_string (n_unique);
            while (trip_id_set.find (trip_id_n) != trip_id_set.end ())
            {
                n_unique++;
                trip_id_n =
                    static_cast <std::string> (trip_id_i) + sfx + std::to_string (n_unique);
            }
            trip_id_set.emplace (trip_id_n);

            for (size_t j = 0; j < tt_len; j++)
            {
                trip_id [row] = trip_id_n;
                arrival_time [row] = arrival_time_sub [j] + headway_i * n;
                departure_time [row] = departure_time_sub [j] + headway_i * n;
                stop_id [row] = stop_id_sub [j];
                stop_sequence [row] = stop_sequence_sub [j];
                row++;
            }
        } // end for n over nseq_i
    } // end for i over ntrips

    Rcpp::DataFrame res = Rcpp::DataFrame::create (
            Rcpp::Named ("trip_id") = trip_id,
            Rcpp::Named ("arrival_time") = arrival_time,
            Rcpp::Named ("departure_time") = departure_time,
            Rcpp::Named ("stop_id") = stop_id,
            Rcpp::Named ("stop_sequence") = stop_sequence,
            Rcpp::_["stringsAsFactors"] = false);

    return res;
}
