#' @title Images arrangement in sits cube
#' @name .gc_arrange_images
#'
#' @keywords internal
#'
#' @param cube       Data cube.
#' @param timeline   Timeline of regularized cube
#' @param period     Period of interval to aggregate images
#'
#' @param ...        Additional parameters.
#'
#' @return           Data cube with the images arranged by cloud.
.gc_arrange_images <- function(cube, timeline, period, ...) {

    # include the end of last interval
    timeline <- c(
        timeline,
        timeline[[length(timeline)]] %m+% lubridate::period(period)
    )

    # filter and change image order according to cloud coverage
    cube <- .sits_fast_apply(cube, "file_info", function(x) {
        x <- dplyr::filter(
            x, .data[["date"]] >= timeline[[1]],
            .data[["date"]] < timeline[[length(timeline)]]
        )

        x <- dplyr::group_by(
            x,
            interval = cut(.data[["date"]], timeline, labels = FALSE),
            .add = TRUE
        )

        x <- dplyr::arrange(
            x, .data[["cloud_cover"]],
            .by_group = TRUE
        )

        x <- dplyr::select(dplyr::ungroup(x), -.data[["interval"]])

        return(x)
    })

    return(cube)
}

#' @title Create a cube_view object
#' @name .gc_create_cube_view
#' @keywords internal
#'
#' @param tile       Data cube tile
#' @param period     Period of time in which it is desired to apply in the cube,
#'                   must be provided based on ISO8601, where 1 number and a
#'                   unit are provided, for example "P16D".
#' @param res        Spatial resolution of the image that
#'                   will be aggregated.
#' @param roi        Region of interest.
#' @param toi        Timeline of intersection.
#' @param agg_method Aggregation method.
#' @param resampling Resampling method.
#'                   Options: \code{near}, \code{bilinear}, \code{bicubic} or
#'                   others supported by gdalwarp
#'                   (see https://gdal.org/programs/gdalwarp.html).
#'                   Default is "bilinear".
#'
#' @return           \code{Cube_view} object from gdalcubes.
.gc_create_cube_view <- function(tile,
                                 period,
                                 res,
                                 roi,
                                 date,
                                 agg_method,
                                 resampling) {

    # set caller to show in errors
    .check_set_caller(".gc_create_cube_view")

    # pre-conditions
    .check_that(nrow(tile) == 1,
        msg = "tile must have only one row."
    )

    .check_null(period,
        msg = "the parameter 'period' must be provided."
    )

    .check_num(res,
        allow_null = TRUE, len_max = 1,
        msg = "the parameter 'res' is invalid."
    )

    # get bbox roi
    bbox_roi <- sits_bbox(tile)
    if (!is.null(roi)) {
        bbox_roi <- .sits_roi_bbox(roi, tile)
    }

    # create a gdalcubes extent
    extent <- list(
        left   = bbox_roi[["xmin"]],
        right  = bbox_roi[["xmax"]],
        bottom = bbox_roi[["ymin"]],
        top    = bbox_roi[["ymax"]],
        t0     = format(date, "%Y-%m-%d"),
        t1     = format(date, "%Y-%m-%d")
    )

    # create a list of cube view
    cv <- suppressMessages(
        gdalcubes::cube_view(
            extent = extent,
            srs = .cube_crs(tile),
            dt = period,
            dx = res,
            dy = res,
            aggregation = agg_method,
            resampling = resampling
        )
    )

    return(cv)
}

#' @title Create an gdalcubes::image_mask object
#' @name .gc_create_cloud_mask
#' @keywords internal
#'
#' @param cube  Data cube.
#'
#' @return      \code{gdalcubes::image_mask} with information about mask band.
.gc_create_cloud_mask <- function(cube) {

    # set caller to show in errors
    .check_set_caller(".gc_create_cloud_mask")

    # create a image mask object
    mask_values <- gdalcubes::image_mask(
        band = .source_cloud(),
        values = .source_cloud_interp_values(
            source = .cube_source(cube = cube),
            collection = .cube_collection(cube = cube)
        )
    )

    # is this a bit mask cloud?
    if (.source_cloud_bit_mask(
        source = .cube_source(cube = cube),
        collection = .cube_collection(cube = cube)
    )) {
        mask_values <- list(
            band = .source_cloud(),
            min = 1,
            max = 2^16,
            bits = mask_values$values,
            values = NULL,
            invert = FALSE
        )
    }

    class(mask_values) <- "image_mask"

    return(mask_values)
}

#' @title Create an image_collection object
#' @name .gc_create_database_stac
#'
#' @keywords internal
#'
#' @param cube      Data cube from where data is to be retrieved.
#' @param path_db   Path and name for gdalcubes database.
#' @return          Image_collection containing information on the
#'                  images metadata.
.gc_create_database_stac <- function(cube, path_db) {

    # deleting the existing database to avoid errors in the stac database
    if (file.exists(path_db)) {
        unlink(path_db)
    }

    file_info <- dplyr::select(
        cube, .data[["file_info"]],
        .data[["crs"]]
    ) %>%
        tidyr::unnest(cols = c("file_info")) %>%
        dplyr::transmute(
            fid = .data[["fid"]],
            xmin = .data[["xmin"]],
            ymin = .data[["ymin"]],
            xmax = .data[["xmax"]],
            ymax = .data[["ymax"]],
            href = .data[["path"]],
            datetime = as.character(.data[["date"]]),
            band = .data[["band"]],
            `proj:epsg` = gsub("^EPSG:", "", .data[["crs"]])
        )

    features <- dplyr::mutate(file_info, id = .data[["fid"]]) %>%
        tidyr::nest(features = -.data[["fid"]])

    features <- slider::slide_dfr(features, function(feat) {
        bbox <- .sits_coords_to_bbox_wgs84(
            xmin = feat$features[[1]][["xmin"]][[1]],
            xmax = feat$features[[1]][["xmax"]][[1]],
            ymin = feat$features[[1]][["ymin"]][[1]],
            ymax = feat$features[[1]][["ymax"]][[1]],
            crs = as.numeric(feat$features[[1]][["proj:epsg"]][[1]])
        )

        feat$features[[1]] <- dplyr::mutate(feat$features[[1]],
            xmin = bbox[["xmin"]],
            xmax = bbox[["xmax"]],
            ymin = bbox[["ymin"]],
            ymax = bbox[["ymax"]]
        )

        feat
    })

    gc_data <- purrr::map(features[["features"]], function(feature) {
        feature <- feature %>%
            tidyr::nest(assets = c(.data[["href"]], .data[["band"]])) %>%
            tidyr::nest(properties = c(
                .data[["datetime"]],
                .data[["proj:epsg"]]
            )) %>%
            tidyr::nest(bbox = c(
                .data[["xmin"]], .data[["ymin"]],
                .data[["xmax"]], .data[["ymax"]]
            ))

        feature[["assets"]] <- purrr::map(feature[["assets"]], function(asset) {
            asset %>%
                tidyr::pivot_wider(
                    names_from = .data[["band"]],
                    values_from = .data[["href"]]
                ) %>%
                purrr::map(
                    function(x) list(href = x, `eo:bands` = list(NULL))
                )
        })

        feature <- unlist(feature, recursive = FALSE)
        feature[["properties"]] <- c(feature[["properties"]])
        feature[["bbox"]] <- unlist(feature[["bbox"]])
        feature
    })

    ic_cube <- gdalcubes::stac_image_collection(
        s = gc_data,
        out_file = path_db,
        url_fun = identity
    )

    return(ic_cube)
}

#' @title Create a gdalcubes::pack object
#' @name .gc_create_pack
#' @keywords internal
#'
#' @param cube   a sits cube object
#' @param band   a \code{character} band name
#'
#' @return an \code{gdalcube::pack} object.
.gc_create_pack <- function(cube, band) {

    # set caller to show in errors
    .check_set_caller(".gc_create_pack")

    pack <- list(
        type = .config_get("gdalcubes_type_format"),
        nodata = .cube_band_missing_value(cube = cube, band = band),
        scale = 1,
        offset = 0
    )

    return(pack)
}

#' @title Create an gdalcubes::raster_cube object
#' @name .gc_create_raster_cube
#' @keywords internal
#'
#' @param cube_view    \code{gdalcubes::cube_view} object.
#' @param path_db      Path to a gdalcubes database.
#' @param band         Band name to be generated
#' @param mask_band    \code{gdalcubes::image_mask} object with metadata
#'                      about the band to be used to mask clouds.
#' @return             \code{gdalcubes::image_mask} with info on mask band.
#'
.gc_create_raster_cube <- function(cube_view, path_db, band, mask_band) {

    # set caller to show in errors
    .check_set_caller(".gc_create_raster_cube")

    # open db in each process
    img_col <- gdalcubes::image_collection(path = path_db)

    # create a gdalcubes::raster_cube object
    raster_cube <- gdalcubes::raster_cube(
        image_collection = img_col,
        view = cube_view,
        mask = mask_band,
        chunking = .config_get("gdalcubes_chunk_size")
    )

    # filter band of raster_cube
    raster_cube <- gdalcubes::select_bands(
        cube = raster_cube,
        bands = band
    )

    return(raster_cube)
}

#' @title Get the timeline of intersection in all tiles
#' @name .gc_get_valid_timeline
#'
#' @keywords internal
#'
#' @param cube       Data cube.
#' @param period     ISO8601 time period.
#'
#' @return a \code{vector} with all timeline values.
.gc_get_valid_timeline <- function(cube, period) {

    # set caller to show in errors
    .check_set_caller(".gc_get_valid_timeline")

    # pre-condition
    .check_chr(period,
        allow_empty = FALSE,
        len_min = 1, len_max = 1,
        msg = "invalid 'period' parameter"
    )

    # start date - maximum of all minimums
    max_min_date <- do.call(
        what = max,
        args = purrr::map(cube[["file_info"]], function(file_info) {
            return(min(file_info[["date"]]))
        })
    )

    # end date - minimum of all maximums
    min_max_date <- do.call(
        what = min,
        args = purrr::map(cube[["file_info"]], function(file_info) {
            return(max(file_info[["date"]]))
        })
    )

    # check if all timeline of tiles intersects
    .check_that(
        x = max_min_date <= min_max_date,
        msg = "the timeline of the cube tiles do not intersect."
    )

    if (substr(period, 3, 3) == "M") {
        max_min_date <- lubridate::date(paste(
            lubridate::year(max_min_date),
            lubridate::month(max_min_date),
            "01",
            sep = "-"
        ))
    } else if (substr(period, 3, 3) == "Y") {
        max_min_date <- lubridate::date(paste(
            lubridate::year(max_min_date),
            "01", "01",
            sep = "-"
        ))
    }

    # generate timeline
    date <- lubridate::ymd(max_min_date)
    min_max_date <- lubridate::ymd(min_max_date)
    tl <- date
    while (TRUE) {
        date <- lubridate::ymd(date) %m+% lubridate::period(period)
        if (date > min_max_date) break
        tl <- c(tl, date)
    }

    # timeline cube
    tiles_tl <- suppressWarnings(sits_timeline(cube))

    if (!is.list(tiles_tl)) {
        tiles_tl <- list(tiles_tl)
    }

    return(tl)
}

#' @title Saves the images of a raster cube.
#' @name .gc_save_raster_cube
#' @keywords internal
#'
#' @param raster_cube  \code{gdalcubes::raster_cube} object.
#' @param pack         \code{gdalcubes::pack} object.
#' @param output_dir   Directory where the aggregated images will be written.
#' @param files_prefix File names prefix.
#' @param ...          Additional parameters that can be included. See
#'                     '?gdalcubes::write_tif'.
#'
#' @return  A list of generated images.
#'
.gc_save_raster_cube <- function(raster_cube,
                                 pack,
                                 output_dir,
                                 files_prefix, ...) {

    # set caller to show in errors
    .check_set_caller(".gc_save_raster_cube")

    # convert sits gtiff options to gdalcubes format
    gtiff_options <- strsplit(.config_gtiff_default_options(), split = "=")
    gdalcubes_co <- purrr::map(gtiff_options, `[[`, 2)
    names(gdalcubes_co) <- purrr::map_chr(gtiff_options, `[[`, 1)

    # get cog config parameters
    generate_cog <- .config_get("gdalcubes_cog_generate")
    cog_overview <- .config_get("gdalcubes_cog_resample_overview")

    # write the aggregated cubes
    img_paths <- gdalcubes::write_tif(
        x = raster_cube,
        dir = output_dir,
        prefix = files_prefix,
        creation_options = gdalcubes_co,
        pack = pack,
        COG = generate_cog,
        rsmpl_overview = cog_overview, ...
    )

    # post-condition
    .check_length(img_paths,
        len_min = 1,
        msg = "no image was created"
    )

    return(img_paths)
}

#' @title Build a regular data cube from an irregular one
#'
#' @name .gc_regularize
#' @keywords internal
#' @description Creates cubes with regular time intervals
#'  using the gdalcubes package.
#'
#' @references Appel, Marius; Pebesma, Edzer. On-demand processing of data cubes
#'  from satellite image collections with the gdalcubes library. Data, v. 4,
#'  n. 3, p. 92, 2019. DOI: 10.3390/data4030092.
#'
#'
#' @param cube       Data cube whose spacing of observation
#'                   times is not constant and will be regularized
#'                   by the \code{gdalcubes} package.
#' @param output_dir Valid directory where the
#'                   regularized images will be written.
#' @param period     ISO8601 time period for regular data cubes
#'                   with number and unit, e.g., "P16D" for 16 days.
#'                   Use "D", "M" and "Y" for days, month and year.
#' @param res        Spatial resolution of the regularized images.
#' @param roi        A named \code{numeric} vector with a region of interest.
#' @param multicores Number of cores used for regularization.
#' @param progress   Show progress bar?
#'
#' @return             Data cube with aggregated images.
.gc_regularize <- function(cube,
                           period,
                           res,
                           roi,
                           output_dir,
                           multicores = 1,
                           progress = TRUE) {

    # set caller to show in errors
    .check_set_caller(".gc_regularize")

    # check documentation mode
    progress <- .check_documentation(progress)

    # require gdalcubes package
    .check_require_packages("gdalcubes")

    # precondition - test if provided object is a raster cube
    .check_that(
        x = inherits(cube, "raster_cube"),
        msg = paste(
            "provided cube is invalid,",
            "please provide a 'raster_cube' object.",
            "see '?sits_cube' for more information."
        )
    )

    # precondition - check output dir fix
    output_dir <- normalizePath(output_dir)

    # verifies the path to save the images
    .check_that(
        x = dir.exists(output_dir),
        msg = "invalid 'output_dir' parameter."
    )

    # precondition - is the period valid?
    .check_na(lubridate::duration(period),
        msg = "invalid period specified"
    )

    # precondition - is the resolution valid?
    .check_num(
        x = res,
        exclusive_min = 0,
        len_min = 1,
        len_max = 1,
        msg = "invalid 'res' parameter"
    )

    # pre-condition - cube contains cloud band?
    .check_that(
        .source_cloud() %in% sits_bands(cube),
        local_msg = "cube does not have cloud band",
        msg = "invalid cube"
    )

    # precondition - is the multicores valid?
    .check_num(
        x = multicores,
        min = 1,
        len_min = 1,
        len_max = 1,
        is_integer = TRUE,
        msg = "invalid 'multicores' parameter"
    )

    # filter only intersecting tiles
    intersects <- slider::slide_lgl(
        cube, .sits_raster_sub_image_intersects, roi
    )

    # retrieve only intersecting tiles
    cube <- cube[intersects, ]

    # timeline of intersection
    timeline <- .gc_get_valid_timeline(cube, period = period)

    # least_cc_first requires images ordered based on cloud cover
    cube <- .gc_arrange_images(
        cube = cube,
        timeline = timeline,
        period = period
    )

    # each process will start two threads
    multicores <- max(1, round(multicores / 2))

    # start processes
    .sits_parallel_start(multicores, log = FALSE)
    on.exit(.sits_parallel_stop())

    # does a local cube exist
    local_cube <- tryCatch(
        {
            sits_cube(
                source = .cube_source(cube),
                collection = .cube_collection(cube),
                data_dir = output_dir,
                parse_info = c("x1", "tile", "band", "date"),
                multicores = multicores,
                progress = progress
            )
        },
        error = function(e) {
            return(NULL)
        }
    )

    # find the tiles that have not been processed yet
    jobs <- .gc_missing_tiles(
        cube = cube,
        local_cube = local_cube,
        timeline = timeline
    )

    # recovery mode
    finished <- length(jobs) == 0

    while (!finished) {

        # for cubes that have a time limit to expire - mpc cubes only
        cube <- .cube_token_generator(cube)

        # process bands and tiles in parallel
        .sits_parallel_map(jobs, function(job) {

            # get parameters from each job
            tile_name <- job[[1]]
            band <- job[[2]]
            date <- job[[3]]

            # filter tile
            tile <- dplyr::filter(cube, .data[["tile"]] == !!tile_name)

            # for cubes that have a time limit to expire - mpc cubes only
            tile <- .cube_token_generator(tile)

            # post-condition
            .check_that(
                nrow(tile) == 1,
                local_msg = paste0("no tile '", tile_name, "' found"),
                msg = "invalid tile"
            )

            # append gdalcubes path
            path_db <- tempfile(pattern = "gc", fileext = ".db")

            # create an image collection
            .gc_create_database_stac(cube = tile, path_db = path_db)

            # create a gdalcubes::cube_view
            cube_view <- .gc_create_cube_view(
                tile = tile,
                period = period,
                roi = roi,
                res = res,
                date = date,
                agg_method = "first",
                resampling = "bilinear"
            )

            # create a gdalcubes::raster_cube object
            raster_cube <- .gc_create_raster_cube(
                cube_view = cube_view,
                path_db = path_db,
                band = band,
                mask_band = .gc_create_cloud_mask(cube = tile)
            )

            # files prefix
            prefix <- paste("cube", .cube_tiles(tile), band, "", sep = "_")

            # setting threads to process
            gdalcubes::gdalcubes_options(parallel = 2)

            # create of the aggregate cubes
            tryCatch(
                {
                    .gc_save_raster_cube(
                        raster_cube = raster_cube,
                        pack = .gc_create_pack(cube = tile, band = band),
                        output_dir = output_dir,
                        files_prefix = prefix
                    )
                },
                error = function(e) {
                    return(NULL)
                }
            )
        }, progress = progress)

        # create local cube from files in output directory
        local_cube <- tryCatch(
            {
                sits_cube(
                    source = .cube_source(cube),
                    collection = .cube_collection(cube),
                    data_dir = output_dir,
                    parse_info = c("x1", "tile", "band", "date"),
                    multicores = multicores,
                    progress = progress
                )
            },
            error = function(e) {
                return(NULL)
            }
        )

        # find if there are missing tiles
        jobs <- .gc_missing_tiles(
            cube = cube,
            local_cube = local_cube,
            timeline = timeline
        )

        # have we finished?
        finished <- length(jobs) == 0

        # inform the user
        if (!finished) {

            # convert list of missing tiles and bands to a list of vectors
            tiles_bands <- purrr::transpose(jobs)
            tiles_bands <- purrr::map(tiles_bands, unlist)

            # get missing tiles
            bad_tiles <- unique(tiles_bands[[1]])

            # get missing bands per missing tile
            msg <- paste(
                bad_tiles,
                purrr::map_chr(bad_tiles, function(tile) {
                    paste0(
                        "(",
                        paste0(unique(
                            tiles_bands[[2]][tiles_bands[[1]] == tile]
                        ),
                        collapse = ", "
                        ),
                        ")"
                    )
                }),
                collapse = ", "
            )

            # show message
            message(paste(
                "Tiles", msg, "are missing or malformed",
                "and will be reprocessed."
            ))

            # remove cache
            .sits_parallel_stop()
            .sits_parallel_start(multicores, log = FALSE)
        }
    }

    return(local_cube)
}

#' @title Finds the missing tiles in a regularized cube
#'
#' @name .gc_missing_tiles
#' @keywords internal
#'
#' @param cube     Original cube to be regularized.
#' @param gc_cube  Regularized cube (may be missing tiles).
#' @param timeline Timeline used by gdalcubes for regularized cube
#' @param period   Period of timeline regularization.
#'
#' @return         Tiles that are missing from the regularized cube.
#'
.gc_missing_tiles <- function(cube, local_cube, timeline) {

    # do a cross product on tiles and bands
    tiles_bands_times <- unlist(slider::slide(cube, function(tile) {
        bands <- .cube_bands(tile, add_cloud = FALSE)
        purrr::cross3(.cube_tiles(tile), bands, timeline)
    }), recursive = FALSE)

    # if regularized cube does not exist, return all tiles from original cube
    if (is.null(local_cube)) {
        return(tiles_bands_times)
    }

    # do a cross product on tiles and bands
    gc_tiles_bands_times <- unlist(slider::slide(local_cube, function(tile) {
        bands <- .cube_bands(tile, add_cloud = FALSE)
        purrr::cross3(.cube_tiles(tile), bands, timeline)
    }), recursive = FALSE)

    # first, include tiles and bands that have not been processed
    miss_tiles_bands_times <-
        tiles_bands_times[!tiles_bands_times %in% gc_tiles_bands_times]

    # second, include tiles and bands that have been processed
    proc_tiles_bands_times <-
        tiles_bands_times[tiles_bands_times %in% gc_tiles_bands_times]

    # do all tiles and bands in local_cube have the same timeline as
    # the original cube?
    bad_timeline <- purrr::pmap_lgl(
        purrr::transpose(proc_tiles_bands_times),
        function(tile, band, date) {
            tile <- local_cube[local_cube[["tile"]] == tile, ]
            tile <- sits_select(tile, bands = band)
            return(!date %in% sits_timeline(tile))
        }
    )

    # update malformed processed tiles and bands
    proc_tiles_bands_times <- proc_tiles_bands_times[bad_timeline]

    # return all tiles from the original cube
    # that have not been processed or regularized correctly
    miss_tiles_bands_times <-
        unique(c(miss_tiles_bands_times, proc_tiles_bands_times))

    return(miss_tiles_bands_times)
}
