
# https://developers.google.com/transit/gtfs/reference

gtfs_reference_fields <- function () {

    "agency" <- c ("agency_id"          = "id",             # cond. required
                   "agency_name"        = "text",           # required
                   "agency_url"         = "url",            # required
                   "agency_timezone"    = "timezone",       # required
                   "agency_lang"        = "language_code",  # optional
                   "agency_phone"       = "phone_number",   # optional
                   "agency_fare_url"    = "url",            # optional
                   "agency_email"       = "email")          # optional

    "calendar" <- c ("service_idi"  = "id",     # required
                     "mondayi"      = "enum",   # required
                     "tuesdayi"     = "enum",   # required
                     "wednesdayi"   = "enum",   # required
                     "thursdayi"    = "enum",   # required
                     "fridayi"      = "enum",   # required
                     "saturdayi"    = "enum",   # required
                     "sundayi"      = "enum",   # required
                     "start_datei"  = "date",   # required
                     "end_datei"    = "date")   # required

    "calendar_dates" <- c ("service_id"     = "id",     # required
                           "date"           = "date",   # required
                           "exception_type" = "enum")   # required

    "fare_attributes" <- c ("fare_id"           = "id",             # required
                            "price"             = "float",          # required
                            "currency_type"     = "currency_code",  # required
                            "payment_method"    = "enum",           # required
                            "transfers"         = "enum",           # required
                            "agency_id"         = "id",             # cond. req.
                            "transfer_duration" = "integer")        # optional

    "fare_rules" <- c ("fare_id"        = "id",     # required
                       "route_id"       = "id",     # optional
                       "origin_id"      = "id",     # optional
                       "destination_id" = "id",     # optional
                       "containsid"     = "id")     # optional

    "feed_info" <- c ("feed_publisher_name"     = "text",           # required
                      "feed_publisher_url"      = "url",            # required
                      "feed_lang"               = "language_code",  # required
                      "default_lang"            = "language_code",  # optional
                      "feed_start_date"         = "date",           # optional
                      "feed_end_date"           = "date",           # optional
                      "feed_version"            = "text",           # optional
                      "feed_contact_email"      = "email",          # optional
                      "feed_contact_url"        = "url")            # optional

    "routes" <- c ("route_id"           = "id",         # required
                   "agency_id"          = "id",         # cond. required
                   "route_short_name"   = "text",       # cond. required
                   "route_long_name"    = "text",       # cond. required
                   "route_desc"         = "text",       # optional
                   "route_type"         = "enum",       # required
                   "route_url"          = "url",        # optional
                   "route_color"        = "color",      # optional
                   "route_text_color"   = "color",      # optional
                   "route_sort_order"   = "integer",    # optional
                   "continuous_pickup"  = "enum",       # optional
                   "continuous_dropoff" = "enum")       # optional

    "shapes" <- c ("shape_id"               = "id",         # required
                   "shape_pt_lat"           = "latitude",   # required
                   "shape_pt_lon"           = "longitude",  # required
                   "shape_pt_sequence"      = "integer",    # required
                   "shape_dist_travelled"   = "float")      # optional

    "stops" <- c ("stop_id"                 = "id",         # required
                  "stop_code"               = "text",       # optional
                  "stop_name"               = "text",       # cond. required
                  "stop_desc"               = "text",       # optional
                  "stop_lat"                = "latitude",   # cond. required
                  "stop_lon"                = "longitude",  # cond. required
                  "zone_id"                 = "id",         # cond. required
                  "stop_url"                = "url",        # optional
                  "location_type"           = "enum",       # optional
                  "parent_station"          = "id",         # cond. required
                  "stop_timezone"           = "timezone",   # optional
                  "wheelchair_boarding"     = "enum",       # optional
                  "level_id"                = "id",         # optional
                  "platform_code"           = "text")       # optional

    "stop_times" <- c ("trip_id"                = "id",      # required
                       "arrival_time"           = "time",    # cond. required
                       "departure_time"         = "time",    # cond. required
                       "stop_id"                = "id",      # required
                       "stop_sequence"          = "integer", # required
                       "stop_headsign"          = "text",    # optional
                       "pickup_type"            = "enum",    # optional
                       "drop_off_type"          = "enum",    # optional
                       "continuous_pickup"      = "enum",    # optional
                       "continuous_drop_off"    = "enum",    # optional
                       "shape_dist_traveled"    = "float",   # optional
                       "timepoint"              = "enum")    # optional

    "trips" <- c ("route_id"                = "id",     # required
                  "service_id"              = "id",     # required
                  "trip_id"                 = "id",     # required
                  "trip_headsign"           = "text",   # optional
                  "trip_short_name"         = "text",   # optional
                  "direction_id"            = "enum",   # optional
                  "block_id"                = "id",     # optional
                  "shape_id"                = "id",     # cond. required
                  "wheelchair_accessible"   = "enum",   # optional
                  "bikes_allowed"           = "enum")   # optional

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
