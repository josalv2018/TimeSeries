#' @keywords internal
#' @export
.source_access_test.stac_cube <- function(source, collection, ..., bands) {

    # require package
    if (!requireNamespace("rstac", quietly = TRUE)) {
        stop(paste("Please install package rstac from CRAN:",
                   "install.packages('rstac')"), call. = FALSE
        )
    }

    items_query <- .stac_items_query(source = source,
                                     collection = collection,
                                     limit = 1, ...)

    # assert that service is online
    tryCatch({
        items <- rstac::post_request(items_query)
    }, error = function(e) {
        stop(paste(".source_access_test.stac_cube: service is unreachable\n",
                   e$message), call. = FALSE)
    })

    items <- .source_items_bands_select(source = source,
                                        collection = collection,
                                        items = items,
                                        bands = bands[[1]], ...)

    href <- .source_item_get_hrefs(source = source,
                                   item = items$feature[[1]], ...,
                                   collection = collection)

    # assert that token and/or href is valid
    tryCatch({
        .raster_open_rast(href)
    }, error = function(e) {
        stop(paste(".source_access_test.stac_cube: cannot open url\n",
                   href, "\n", e$message), call. = FALSE)
    })

    return(invisible(NULL))
}

#' @keywords internal
#' @export
.source_cube.stac_cube <- function(source, ...,
                                   collection,
                                   name,
                                   bands,
                                   tiles,
                                   bbox,
                                   start_date,
                                   end_date) {

    items_query <- .stac_items_query(source = source,
                                     collection = collection,
                                     name = name,
                                     bands = bands,
                                     bbox = bbox,
                                     start_date = start_date,
                                     end_date = end_date, ...)

    items <- .source_items_new(source = source,
                               collection = collection, ...,
                               stac_query = items_query,
                               tiles = tiles)

    items <- .source_items_bands_select(source = source,
                                        collection = collection,
                                        items = items,
                                        bands = bands, ...)

    items_lst <- .source_items_tiles_group(source = source,
                                           items = items)

    cube <- purrr::map_dfr(items_lst, function(tile) {

        file_info <- .source_items_fileinfo(source = source,
                                            items = tile, ...,
                                            collection = collection)

        tile_cube <- .source_items_cube(source = source,
                                        collection = collection,
                                        name = name,
                                        items = tile,
                                        file_info = file_info, ...)

        return(tile_cube)
    })

    class(cube) <- c("raster_cube", class(cube))

    return(cube)
}

#' @keywords internal
#' @export
.source_items_bands_select.stac_cube <- function(source,
                                                 collection,
                                                 items,
                                                 bands, ...) {

    items <- .stac_bands_select(
        items = items,
        bands_source = .source_bands_to_source(source, collection, bands),
        bands_sits = .source_bands_to_sits(source, collection, bands)
    )

    return(items)
}

#' @keywords internal
#' @export
.source_items_fileinfo.stac_cube <- function(source,
                                             items, ...,
                                             collection = NULL) {

    file_info <- purrr::map_dfr(items$features, function(item){

        date <- suppressWarnings(
            lubridate::as_date(.source_item_get_date(source = source,
                                                     item = item, ...,
                                                     collection = collection))
        )

        bands <- .source_item_get_bands(source = source,
                                        item = item, ...,
                                        collection = collection)

        res <- .source_item_get_resolutions(source = source,
                                            item = item, ...,
                                            collection = collection)

        paths <- .source_item_get_hrefs(source = source,
                                        item = item, ...,
                                        collection = collection)

        assertthat::assert_that(
            !is.na(date),
            msg = ".source_cube: invalid date format."
        )

        assertthat::assert_that(
            is.character(bands),
            msg = ".source_cube: invalid band format."
        )

        assertthat::assert_that(
            is.numeric(res),
            msg = ".source_cube: invalid res format."
        )

        assertthat::assert_that(
            is.character(paths),
            msg = ".source_cube: invalid path format."
        )

        tidyr::unnest(
            tibble::tibble(
                date = date,
                band = list(bands),
                res = list(res),
                path = list(paths)
            ), cols = c("band", "res", "path")
        )
    }) %>% dplyr::arrange(date)

    return(file_info)
}

#' @keywords internal
#' @export
.source_items_cube.stac_cube <- function(source,
                                         collection,
                                         name,
                                         items,
                                         file_info, ...) {


    t_bbox <- .source_items_tile_get_bbox(source = source,
                                          tile_items = items, ...,
                                          collection = collection)

    assertthat::assert_that(
        all(names(t_bbox) %in% c("xmin", "ymin", "xmax", "ymax")),
        msg = paste(".source_items_cube.stac_cube: bbox must be have",
                    "'xmin', 'ymin', 'xmax', and 'ymax' names.")
    )

    assertthat::assert_that(
        is.numeric(t_bbox),
        msg = ".source_items_cube.stac_cube: bbox must be numeric."
    )

    t_size <- .source_items_tile_get_size(source = source,
                                          tile_items = items, ...,
                                          collection = collection)

    assertthat::assert_that(
        all(names(t_size) %in% c("nrows", "ncols")),
        msg = paste(".source_items_cube.stac_cube: size must be have",
                    "'nrows' and 'ncols' names.")
    )

    assertthat::assert_that(
        is.numeric(t_size),
        msg = ".source_items_cube.stac_cube: size must be numeric."
    )

    # tile name
    t_name <- .source_items_tile_get_name(source = source,
                                          tile_items = items, ...,
                                          collection = collection)

    assertthat::assert_that(
        is.character(t_name),
        msg = paste(".source_items_cube.stac_cube: name must be a",
                    "character value.")
    )

    t_crs <- .source_items_tile_get_crs(source = source,
                                        tile_items = items, ...,
                                        collection = collection)
    assertthat::assert_that(
        is.character(t_crs) || is.numeric(t_crs),
        msg = paste(".source_items_cube.stac_cube: name must be a",
                    "character or numeric value.")
    )

    t_sat <- .source_items_get_satellite(source = source,
                                         items = items, ...,
                                         collection = collection)

    assertthat::assert_that(
        is.character(t_sat),
        msg = paste(".source_items_cube.stac_cube: satellite name must be",
                    "a character value.")
    )

    t_sensor <- .source_items_get_sensor(source = source,
                                         items = items, ...,
                                         collection = collection)

    assertthat::assert_that(
        is.character(t_sensor),
        msg = paste(".source_items_cube.stac_cube: sensor name must be a",
                    "character value.")
    )

    tile <- .sits_cube_create(
        name       = name[[1]],
        source     = source[[1]],
        collection = collection[[1]],
        satellite  = t_sat[[1]],
        sensor     = t_sensor[[1]],
        tile       = t_name[[1]],
        bands      = unique(file_info[["band"]]),
        nrows      = t_size[["nrows"]],
        ncols      = t_size[["ncols"]],
        xmin       = t_bbox[["xmin"]],
        xmax       = t_bbox[["xmax"]],
        ymin       = t_bbox[["ymin"]],
        ymax       = t_bbox[["ymax"]],
        xres       = min(file_info[["res"]]),
        yres       = min(file_info[["res"]]),
        crs        = t_crs[[1]],
        file_info  = file_info)

    return(tile)
}