#' gtfs_route
#'
#' Calculate matrix of pair-wise distances between points.
#'
#' @param graph `data.frame` or equivalent object representing the network
#' graph (see Details)
#' @param from Vector or matrix of points **from** which route distances are to
#' be calculated (see Details)
#' @param to Vector or matrix of points **to** which route distances are to be
#' calculated (see Details)
#' @return square matrix of distances between nodes
#'
#' @export 
gtfs_route <- function (graph, from, to)
{
    vert_map <- make_vert_map (graph)

    index_id <- get_index_id_cols (graph, vert_map, from)
    from_index <- index_id$index - 1 # 0-based
    from_id <- index_id$id
    index_id <- get_index_id_cols (graph, vert_map, to)
    to_index <- index_id$index - 1 # 0-based
    to_id <- index_id$id

    graph <- graph [, c ("edge_id", "from_id", "to_id", "d", "transfer")]
    names (graph) <- c ("edge_id", "from", "to", "d", "transfer")
    graph$d <- ceiling (graph$d * 1000)

    d <- rcpp_get_sp_dists (graph, vert_map, from_index, to_index)

    if (!is.null (from_id))
        rownames (d) <- from_id
    else
        rownames (d) <- vert_map$vert
    if (!is.null (to_id))
        colnames (d) <- to_id
    else
        colnames (d) <- vert_map$vert

    return (d)
}

#' get_index_id_cols
#'
#' Get an index of `pts` matching `vert_map`, as well as the
#' corresonding names of those `pts`
#'
#' @return list of `index`, which is 0-based for C++, and corresponding
#' `id` values.
#' @noRd
get_index_id_cols <- function (graph, vert_map, pts)
{
    index <- -1
    id <- NULL
    if (!missing (pts))
    {
        index <- match (pts, vert_map$vert)
        id <- vert_map$vert [index] # from_index is 1-based
    }
    list (index = index, id = id)
}

#' make_vert_map
#'
#' Map unique vertex names to sequential numbers in matrix
#' @noRd
make_vert_map <- function (graph)
{
    verts <- c (paste0 (graph$from_id), paste0 (graph$to_id))
    indx <- which (!duplicated (verts))
    # Note id has to be 0-indexed:
    data.frame (vert = paste0 (verts [indx]), id = seq (indx) - 1,
                stringsAsFactors = FALSE)
}
