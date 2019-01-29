#' get_transfer_schedules
#'
#' Get list of transfer schedules from each node of the network
#'
#' @param stop_times `data.frame` of stop times
#' @return List of transfer schedules
#'
#' @noRd 
get_transfer_schedules <- function (stop_times)
{
    rcpp_transfer_times (stop_times)
}

