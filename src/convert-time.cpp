#include "convert-time.h"

#include <iostream>

// ----------  Functions to convert start time: ----------

bool time_is_hhmmss (const std::string &hms) // "HH:MM:SS"
{
    bool check = false;
    if (hms.size () == 8 && std::count (hms.begin(), hms.end(), ':') == 2)
        check = true;
    return check;
}

bool time_is_hhmm (const std::string &hms) // "HH:MM"
{
    bool check = false;
    if (hms.size () == 5 && std::count (hms.begin(), hms.end(), ':') == 1)
        check = true;
    return check;
}

bool time_is_lubridate (const std::string &hms)
{
    // stardard is HH:MM:SS
    bool check = false;
    if (std::count (hms.begin (), hms.end (), 'H') == 1 &&
            std::count (hms.begin (), hms.end (), 'M') == 1 &&
            std::count (hms.begin (), hms.end (), 'S') == 1)
        check = true;
    return check;
}

int convert_time_hhmmss (std::string hms)
{
    const std::string delim = ":";
    unsigned int ipos = static_cast <unsigned int> (hms.find (delim.c_str ()));
    std::string h = hms.substr (0, ipos), m, s;
    hms = hms.substr (ipos + 1, hms.length () - ipos - 1);
    if (hms.find (delim.c_str ()) != std::string::npos) // has seconds
    {
        ipos = static_cast <unsigned int> (hms.find (delim.c_str ()));
        m = hms.substr (0, ipos);
        s = hms.substr (ipos + 1, hms.length () - ipos - 1);
    //} else // difftime objects always have seconds so this is not possible
    //{
    //    m = hms;
    //    s = "00";
    }
    return 3600 * atoi (h.c_str ()) +
        60 * atoi (m.c_str ()) +
        atoi (s.c_str ());
}

int convert_time_hhmm (std::string hms)
{
    const std::string delim = ":";
    unsigned int ipos = static_cast <unsigned int> (hms.find (delim.c_str ()));
    std::string h = hms.substr (0, ipos), m, s;
    hms = hms.substr (ipos + 1, hms.length () - ipos - 1);

    return 3600 * atoi (h.c_str ()) +
        60 * atoi (hms.c_str ());
}

// lubridate format is "00H 00M 00S"
int convert_time_lubridate (std::string hms)
{
    unsigned int ipos = static_cast <unsigned int> (hms.find ("H"));
    std::string h = hms.substr (0, ipos);
    hms = hms.substr (ipos + 2, hms.length () - ipos - 1);
    ipos = static_cast <unsigned int> (hms.find ("M"));
    std::string m = hms.substr (0, ipos);
    hms = hms.substr (ipos + 2, hms.length () - ipos - 1);
    ipos = static_cast <unsigned int> (hms.find ("S"));
    std::string s = hms.substr (0, ipos);
    return 3600 * atoi (h.c_str ()) +
        60 * atoi (m.c_str ()) +
        atoi (s.c_str ());
}

//' rcpp_convert_time
//'
//' @noRd
// [[Rcpp::export]]
int rcpp_convert_time (const std::string &hms)
{
    int time;
    std::string hms_cp = hms;

    if (time_is_hhmmss (hms_cp))
        time = convert_time_hhmmss (hms_cp);
    else if (time_is_hhmm (hms_cp))
        time = convert_time_hhmm (hms_cp);
    else if (time_is_lubridate (hms_cp))
        time = convert_time_lubridate (hms_cp);
    else // already checked in R before passing to this fn
        Rcpp::stop ("Unrecognized time format"); // # nocov

    return time;
}

// ----------  Vector conversion of GTFS times:  ----------

int convert_time_to_seconds (std::string hms)
{
    const std::string delim = ":";
    unsigned int ipos = static_cast <unsigned int> (hms.find (delim.c_str ()));
    int h = atoi (hms.substr (0, ipos).c_str ());
    hms = hms.substr (ipos + 1, hms.length () - ipos - 1);
    ipos = static_cast <unsigned int> (hms.find (delim.c_str ()));
    int m = atoi (hms.substr (0, ipos).c_str ());
    int s = atoi (hms.substr (ipos + 1, hms.length ()).c_str ());

    return 3600 * h + 60 * m + s;
}

//' rcpp_time_to_seconds
//'
//' Vectorize the above function
//'
//' @noRd
// [[Rcpp::export]]
Rcpp::IntegerVector rcpp_time_to_seconds (std::vector <std::string> times)
{
    Rcpp::IntegerVector res (times.size ());
    for (size_t i = 0; i < times.size (); i++)
    {
        res (i) = convert_time_to_seconds (times [i]);
    }
    return res;
}

