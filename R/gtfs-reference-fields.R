
# https://developers.google.com/transit/gtfs/reference

gtfs_reference_fields <- function () {

    "agency" <- list ("agency_id"       = c ("id",              "cond"),
                      "agency_name"     = c ("text",            "required"),
                      "agency_url"      = c ("url",             "required"),
                      "agency_timezone" = c ("timezone",        "required"),
                      "agency_lang"     = c ("language_code",   "optional"),
                      "agency_phone"    = c ("phone_number",    "optional"),
                      "agency_fare_url" = c ("url",             "optional"),
                      "agency_email"    = c ("email",           "optional"))

    "calendar" <- list ("service_idi"  = c ("id",       "required"),
                        "mondayi"      = c ("enum",     "required"),
                        "tuesdayi"     = c ("enum",     "required"),
                        "wednesdayi"   = c ("enum",     "required"),
                        "thursdayi"    = c ("enum",     "required"),
                        "fridayi"      = c ("enum",     "required"),
                        "saturdayi"    = c ("enum",     "required"),
                        "sundayi"      = c ("enum",     "required"),
                        "start_datei"  = c ("date",     "required"),
                        "end_datei"    = c ("date",     "required"))

    "calendar_dates" <- list ("service_id"     = c ("id",       "required"),
                              "date"           = c ("date",     "required"),
                              "exception_type" = c ("enum",     "required"))

    # nolint start (lots of lines > 80 characters)
    "fare_attributes" <- list ("fare_id"           = c ("id",               "required"),
                               "price"             = c ("float",            "required"),
                               "currency_type"     = c ("currency_code",    "required"),
                               "payment_method"    = c ("enum",             "required"),
                               "transfers"         = c ("enum",             "required"),
                               "agency_id"         = c ("id",               "conditional"),
                               "transfer_duration" = c ("integer",          "optional"))

    "fare_rules" <- list ("fare_id"        = c ("id",   "required"),
                          "route_id"       = c ("id",   "optional"),
                          "origin_id"      = c ("id",   "optional"),
                          "destination_id" = c ("id",   "optional"),
                          "containsid"     = c ("id",   "optional"))

    "feed_info" <- list ("feed_publisher_name"     = c ("text",             "required"),
                         "feed_publisher_url"      = c ("url",              "required"),
                         "feed_lang"               = c ("language_code",    "required"),
                         "default_lang"            = c ("language_code",    "optional"),
                         "feed_start_date"         = c ("date",             "optional"),
                         "feed_end_date"           = c ("date",             "optional"),
                         "feed_version"            = c ("text",             "optional"),
                         "feed_contact_email"      = c ("email",            "optional"),
                         "feed_contact_url"        = c ("url",              "optional"))

    "routes" <- list ("route_id"           = c ("id",       "required"),
                      "agency_id"          = c ("id",       "conditional"),
                      "route_short_name"   = c ("text",     "conditional"),
                      "route_long_name"    = c ("text",     "conditional"),
                      "route_desc"         = c ("text",     "optional"),
                      "route_type"         = c ("enum",     "required"),
                      "route_url"          = c ("url",      "optional"),
                      "route_color"        = c ("color",    "optional"),
                      "route_text_color"   = c ("color",    "optional"),
                      "route_sort_order"   = c ("integer",  "optional"),
                      "continuous_pickup"  = c ("enum",     "optional"),
                      "continuous_dropoff" = c ("enum",     "optional"))

    "shapes" <- list ("shape_id"               = c ("id",           "required"),
                      "shape_pt_lat"           = c ("latitude",     "required"),
                      "shape_pt_lon"           = c ("longitude",    "required"),
                      "shape_pt_sequence"      = c ("integer",      "required"),
                      "shape_dist_travelled"   = c ("float",        "optional"))

    "stops" <- list ("stop_id"                 = c ("id",           "required"),
                     "stop_code"               = c ("text",         "optional"),
                     "stop_name"               = c ("text",         "conditional"),
                     "stop_desc"               = c ("text",         "optional"),
                     "stop_lat"                = c ("latitude",     "conditional"),
                     "stop_lon"                = c ("longitude",    "conditional"),
                     "zone_id"                 = c ("id",           "conditional"),
                     "stop_url"                = c ("url",          "optional"),
                     "location_type"           = c ("enum",         "optional"),
                     "parent_station"          = c ("id",           "conditional"),
                     "stop_timezone"           = c ("timezone",     "optional"),
                     "wheelchair_boarding"     = c ("enum",         "optional"),
                     "level_id"                = c ("id",           "optional"),
                     "platform_code"           = c ("text",         "optional"))

    "stop_times" <- list ("trip_id"                = c ("id",           "required"),
                          "arrival_time"           = c ("time",         "conditional"),
                          "departure_time"         = c ("time",         "conditional"),
                          "stop_id"                = c ("id",           "required"),
                          "stop_sequence"          = c ("integer",      "required"),
                          "stop_headsign"          = c ("text",         "optional"),
                          "pickup_type"            = c ("enum",         "optional"),
                          "drop_off_type"          = c ("enum",         "optional"),
                          "continuous_pickup"      = c ("enum",         "optional"),
                          "continuous_drop_off"    = c ("enum",         "optional"),
                          "shape_dist_traveled"    = c ("float",        "optional"),
                          "timepoint"              = c ("enum",         "optional"))
    # nolint end

    "trips" <- list ("route_id"                = c ("id",       "required"),
                     "service_id"              = c ("id",       "required"),
                     "trip_id"                 = c ("id",       "required"),
                     "trip_headsign"           = c ("text",     "optional"),
                     "trip_short_name"         = c ("text",     "optional"),
                     "direction_id"            = c ("enum",     "optional"),
                     "block_id"                = c ("id",       "optional"),
                     "shape_id"                = c ("id",       "conditional"),
                     "wheelchair_accessible"   = c ("enum",     "optional"),
                     "bikes_allowed"           = c ("enum",     "optional"))

    return (list (agency = agency,
                  calendar = calendar,
                  calendar_dates = calendar_dates,
                  fare_attributes = fare_attributes,
                  fare_rules = fare_rules,
                  feed_info = feed_info,
                  routes = routes,
                  shapes = shapes,
                  stops = stops,
                  stop_times = stop_times,
                  trips = trips))
}

# https://developers.google.com/transit/gtfs/reference#field_types
gtfs_reference_types <- function () {

    c ("color"          = "character",
       "currency_code"  = "character",
       "date"           = "integer",
       "email"          = "character",
       "enum"           = "integer",
       "id"             = "character",
       "integer"        = "integer",
       "language_code"  = "character",
       "latitude"       = "numeric",
       "longitude"      = "numeric",
       "float"          = "numeric",
       "phone_number"   = "character",
       "text"           = "character",
       "time"           = "character",
       "timezone"       = "character",
       "url"            = "character")
}
