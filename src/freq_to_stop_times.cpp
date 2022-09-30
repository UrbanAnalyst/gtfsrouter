#include "freq_to_stop_times.h"

//' rcpp_freq_to_stop_times
//'
//' @noRd
// [[Rcpp::export]]
Rcpp::List rcpp_freq_to_stop_times (Rcpp::DataFrame frequencies,
        Rcpp::List stop_times, const int n_timetables,
        const std::string sfx)
{
    const std::vector <std::string> f_trip_id = frequencies ["trip_id"];
    const std::vector <int> f_start_time = frequencies ["start_time"];
    const std::vector <int> f_end_time = frequencies ["end_time"];
    const std::vector <int> f_headway = frequencies ["headway_secs"];

    const size_t ntrips = static_cast <size_t> (frequencies.nrow ());

    Rcpp::List res (n_timetables);
    size_t count = 0;

    for (size_t i = 0; i < ntrips; i++)
    {
        Rcpp::checkUserInterrupt ();

        const int headway = f_headway [i];
        const int start_time = f_start_time [i];
        const int end_time = f_end_time [i];
        std::string trip_id = f_trip_id [i];

        const int nrpts = static_cast <int> (ceil ((end_time - start_time) / headway));

        for (int n = 0; n < nrpts; n++) {
        
            Rcpp::DataFrame st_i = Rcpp::as <Rcpp::DataFrame> (stop_times (i));
            // st_i is a pointer to the original 'stop_times', so must be
            // treated as const, and a new DF made instead.
            const int n_stop_entries = st_i.nrow ();

            const Rcpp::CharacterVector trip_id = st_i ["trip_id"];
            const Rcpp::IntegerVector arrival_time = st_i ["arrival_time"];
            const Rcpp::IntegerVector departure_time = st_i ["departure_time"];
            const Rcpp::CharacterVector stop_id = st_i ["stop_id"];
            const Rcpp::IntegerVector stop_sequence = st_i ["stop_sequence"];

            const std::string trip_id_n =
                static_cast <std::string> (trip_id [0]) + sfx + std::to_string (n);

            // Vectors to be modified:
            Rcpp::CharacterVector trip_id_new (n_stop_entries);
            Rcpp::IntegerVector arrival_time_new (n_stop_entries);
            Rcpp::IntegerVector departure_time_new (n_stop_entries);

            for (int j = 0; j < n_stop_entries; j++)
            {
                trip_id_new [j] = trip_id_n;
                arrival_time_new [j] = arrival_time [j] + start_time + n * headway;
                departure_time_new [j] = departure_time [j] + start_time + n * headway;
            }

            Rcpp::DataFrame new_stops = Rcpp::DataFrame::create (
                Rcpp::Named ("trip_id") = trip_id_new,
                Rcpp::Named ("arrival_time") = arrival_time_new,
                Rcpp::Named ("departure_time") = departure_time_new,
                Rcpp::Named ("stop_id") = stop_id,
                Rcpp::Named ("stop_sequence") = stop_sequence,
                Rcpp::_["stringsAsFactors"] = false);

            res (count++) = new_stops;
        }
        
    }

    return res;
}
