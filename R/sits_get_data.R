#' @title Get time series from data cubes and cloud services
#' @name sits_get_data
#' @author Gilberto Camara
#'
#' @description Retrieve a set of time series from a data cube or from
#' a time series service. Data cubes and puts it in a "sits tibble".
#' Sits tibbles are the main structures of sits package.
#' They contain both the satellite image time series and their metadata.
#'
#' @note
#' There are four ways of specifying data to be retrieved using the
#' "samples" parameter:
#' \itemize{
#' \item{CSV file: }{Provide a CSV file with columns
#' "longitude", "latitude", "start_date", "end_date" and "label" for
#' each sample}
#' \item{SHP file: }{Provide a shapefile in POINT or POLYGON geometry
#' containing the location of the samples and an attribute to be
#' used as label. Also, provide start and end date for the time series.}
#' \item{sits object: }{A sits tibble.}
#' \item{sf object: }{An "sf" object with POINT or POLYGON geometry.}
#' \item{data.frame: }{A data.frame with with mandatory columns
#' "longitude", "latitude".}
#' }
#
#' @param cube            Data cube from where data is to be retrieved.
#' @param samples         Samples location (sits, sf, or data.frame).
#' @param ...             Specific parameters for specific cases.
#' @param start_date      Start of the interval for the time series
#'                        in "YYYY-MM-DD" format (optional).
#' @param end_date        End of the interval for the time series in
#'                        "YYYY-MM-DD" format (optional).
#' @param label           Label to be assigned to the time series (optional).
#' @param bands           Bands to be retrieved (optional).
#' @param crs             A coordinate reference system of samples.
#'                        The provided crs could be a character
#'                        (e.g, "EPSG:4326" or "WGS84" or a proj4string), or a
#'                        a numeric with the EPSG code (e.g. 4326).
#'                        This parameter only works for 'csv' or data.frame'
#'                        samples. Default is 4326.
#' @param impute_fn       Imputation function for NA values.
#' @param label_attr      Attribute in the shapefile or sf object to be used
#'                        as a polygon label.
#' @param n_sam_pol       Number of samples per polygon to be read
#'                        (for POLYGON or MULTIPOLYGON shapefile).
#' @param pol_avg         Summarize samples for each polygon?
#' @param pol_id          ID attribute for polygons.
#' @param output_dir      Directory where the time series will be saved as rds.
#'                        Default is the current path.
#' @param multicores      Number of threads to process the time series.
#' @param progress        A logical value indicating if a progress bar
#'                        should be shown. Default is \code{FALSE}.
#'
#' @return A tibble with the metadata and data for each time series
#' <longitude, latitude, start_date, end_date, label, cube, time_series>.
#'
#' @note
#' Please refer to the sits documentation available in
#' <https://e-sensing.github.io/sitsbook/> for detailed examples.
#'
#' @examples
#' if (sits_run_examples()) {
#'     # reading a lat/long from a local cube
#'     # create a cube from local files
#'     data_dir <- system.file("extdata/raster/mod13q1", package = "sits")
#'     raster_cube <- sits_cube(
#'         source = "BDC",
#'         collection = "MOD13Q1-6",
#'         data_dir = data_dir,
#'         delim = "_",
#'         parse_info = c("X1", "X2", "tile", "band", "date")
#'     )
#'     samples <- tibble::tibble(longitude = -55.66738, latitude = -11.76990)
#'     point_ndvi <- sits_get_data(raster_cube, samples)
#'     #
#'     # reading samples from a cube based on a  CSV file
#'     csv_file <- system.file("extdata/samples/samples_sinop_crop.csv",
#'         package = "sits"
#'     )
#'     points <- sits_get_data(cube = raster_cube, samples = csv_file)
#'
#'     # reading a shapefile from BDC (Brazil Data Cube)
#'     # needs a BDC access key that can be obtained
#'     # for free by registering in the BDC website
#'     if (nchar(Sys.getenv("BDC_ACCESS_KEY")) > 0) {
#'         # create a data cube from the BDC
#'         bdc_cube <- sits_cube(
#'             source = "BDC",
#'             collection = "CB4_64_16D_STK-1",
#'             bands = c("NDVI", "EVI"),
#'             tiles = c("022024", "022025"),
#'             start_date = "2018-09-01",
#'             end_date = "2018-10-28"
#'         )
#'         # define a shapefile to be read from the cube
#'         shp_file <- system.file("extdata/shapefiles/bdc-test/samples.shp",
#'             package = "sits"
#'         )
#'         # get samples from the BDC based on the shapefile
#'         time_series_bdc <- sits_get_data(
#'             cube = bdc_cube,
#'             samples = shp_file)
#'     }
#' }
#'
#' @export
sits_get_data <- function(cube,
                          samples,
                          ...,
                          start_date = as.Date(sits_timeline(cube)[1]),
                          end_date = as.Date(
                              sits_timeline(cube)[length(sits_timeline(cube))]
                          ),
                          label = "NoClass",
                          bands = sits_bands(cube),
                          crs = 4326,
                          impute_fn = sits_impute_linear(),
                          label_attr = NULL,
                          n_sam_pol = 30,
                          pol_avg = FALSE,
                          pol_id = NULL,
                          multicores = 2,
                          output_dir = ".",
                          progress = FALSE) {

    # set caller to show in errors
    .check_set_caller("sits_get_data")
    # precondition - output_dir exists
    .check_that(
        dir.exists(output_dir),
        msg = "invalid output directory"
    )

    # pre-condition - all tiles have same bands
    .check_that(
        x = .cube_is_regular(cube),
        local_msg = "Please use sits_regularize()",
        msg = "sits can only get data from regular cubes"
    )

    if (is.character(samples)) {
        class(samples) <- c(tools::file_ext(samples), class(samples))
    }

    UseMethod("sits_get_data", samples)
}
#' @rdname sits_get_data
#'
#' @export
sits_get_data.default <- function(cube, samples, ...) {
    stop("Invalid samples parameter for sits_get_data")
}

#' @rdname sits_get_data
#'
#' @export
sits_get_data.csv <- function(cube,
                              samples,
                              ...,
                              bands = sits_bands(cube),
                              crs = 4326,
                              impute_fn = sits_impute_linear(),
                              multicores = 2,
                              output_dir = ".",
                              progress = FALSE) {
    samples <- .sits_get_samples_from_csv(samples)

    data <- .sits_get_ts(
        cube       = cube,
        samples    = samples,
        bands      = bands,
        crs        = crs,
        impute_fn  = impute_fn,
        multicores = multicores,
        output_dir = output_dir,
        progress   = progress
    )
    return(data)
}
#' @rdname sits_get_data
#'
#' @export
sits_get_data.shp <- function(cube,
                              samples,
                              ...,
                              label = "NoClass",
                              start_date = as.Date(sits_timeline(cube)[1]),
                              end_date = as.Date(sits_timeline(cube)
                              [length(sits_timeline(cube))]),
                              bands = sits_bands(cube),
                              impute_fn = sits_impute_linear(),
                              label_attr = NULL,
                              n_sam_pol = 30,
                              pol_avg = FALSE,
                              pol_id = NULL,
                              multicores = 2,
                              output_dir = ".",
                              progress = FALSE) {

    # pre-condition - shapefile should have an id parameter
    .check_that(
        !(pol_avg && purrr::is_null(pol_id)),
        msg = "invalid 'pol_id' parameter."
    )

    samples <- .sits_get_samples_from_shp(
        shp_file    = samples,
        label       = label,
        shp_attr    = label_attr,
        start_date  = start_date,
        end_date    = end_date,
        n_shp_pol   = n_sam_pol,
        shp_id      = pol_id
    )
    data <- .sits_get_ts(
        cube       = cube,
        samples    = samples,
        bands      = bands,
        impute_fn  = impute_fn,
        multicores = multicores,
        output_dir = output_dir,
        progress   = progress
    )
    if (pol_avg && "polygon_id" %in% colnames(data)) {
        data <- .sits_avg_polygon(data = data)
    }
    return(data)
}
#
#' @rdname sits_get_data
#'
#' @export
sits_get_data.sf <- function(cube,
                             samples,
                             ...,
                             bands = sits_bands(cube),
                             start_date = as.Date(sits_timeline(cube)[1]),
                             end_date = as.Date(sits_timeline(cube)
                             [length(sits_timeline(cube))]),
                             impute_fn = sits_impute_linear(),
                             label = "NoClass",
                             label_attr = NULL,
                             n_sam_pol = 30,
                             pol_avg = FALSE,
                             pol_id = NULL,
                             multicores = 2,
                             output_dir = ".",
                             progress = FALSE) {

    .check_that(
        !(pol_avg && purrr::is_null(pol_id)),
        msg = "invalid 'pol_id' parameter."
    )

    # check if sf object contains all the required columns
    samples <- .sits_get_samples_from_sf(
        sf_object     = samples,
        label         = label,
        label_attr    = label_attr,
        start_date    = start_date,
        end_date      = end_date,
        n_sam_pol     = n_sam_pol,
        pol_id        = pol_id
    )

    data <- .sits_get_ts(
        cube       = cube,
        samples    = samples,
        bands      = bands,
        impute_fn  = impute_fn,
        multicores = multicores,
        output_dir = output_dir,
        progress   = progress
    )
    if (pol_avg && "polygon_id" %in% colnames(data)) {
        data <- .sits_avg_polygon(data = data)
    }

    return(data)
}
#' @rdname sits_get_data
#'
#' @export
sits_get_data.sits <- function(cube,
                               samples,
                               ...,
                               bands = sits_bands(cube),
                               impute_fn = sits_impute_linear(),
                               multicores = 2,
                               output_dir = ".",
                               progress = FALSE) {
    # check if samples contains all the required columns
    .check_chr_contains(
        x = colnames(samples),
        contains = .config_get("df_sample_columns"),
        discriminator = "all_of",
        msg = "data input is not valid"
    )

    data <- .sits_get_ts(
        cube       = cube,
        samples    = samples,
        bands      = bands,
        impute_fn  = impute_fn,
        multicores = multicores,
        output_dir = output_dir,
        progress   = progress
    )
    return(data)
}
#' @rdname sits_get_data
#'
#' @export
#'
sits_get_data.data.frame <- function(cube,
                                     samples,
                                     ...,
                                     start_date = as.Date(
                                         sits_timeline(cube)[1]
                                     ),
                                     end_date = as.Date(
                                         sits_timeline(cube)[
                                             length(sits_timeline(cube))
                                         ]
                                     ),
                                     label = "NoClass",
                                     bands = sits_bands(cube),
                                     crs = 4326,
                                     impute_fn = sits_impute_linear(),
                                     multicores = 2,
                                     output_dir = ".",
                                     progress = FALSE) {


    # check if samples contains all the required columns
    .check_chr_contains(
        x = colnames(samples),
        contains = c("latitude", "longitude"),
        discriminator = "all_of",
        msg = "missing lat/long information in data frame"
    )
    # fill missing columns
    if (!("label" %in% colnames(samples))) {
        samples$label <- label
    }
    if (!("start_date" %in% colnames(samples))) {
        samples$start_date <- start_date
    }
    if (!("end_date" %in% colnames(samples))) {
        samples$end_date <- end_date
    }
    class(samples) <- c("sits", class(samples))

    data <- .sits_get_ts(
        cube       = cube,
        samples    = samples,
        bands      = bands,
        crs        = crs,
        impute_fn  = impute_fn,
        multicores = multicores,
        output_dir = output_dir,
        progress   = progress
    )
    return(data)
}
#' @title Dispatch function to get time series from data cubes and cloud
#' services
#' @name .sits_get_ts
#' @author Gilberto Camara
#' @keywords internal
#' @param cube            Data cube from where data is to be retrieved.
#' @param samples         Samples to be retrieved.
#' @param crs             A coordinate reference system of samples.
#'                        The provided crs could be a character
#'                        (e.g, "EPSG:4326" or "WGS84" or a proj4string), or a
#'                        a numeric with the EPSG code (e.g. 4326).
#'                        This parameter only works for 'csv' or data.frame'
#'                        samples. Default is 4326.
#' @param bands           Bands to be retrieved (optional).
#' @param impute_fn       Imputation function for NA values.
#' @param multicores      Number of threads to process the time series.
#' @param progress        A logical value indicating if a progress bar
#'                        should be shown. Default is \code{FALSE}.
#'
#' @return                A tibble with a set of time series retrieved
#'                        from a data cube.
#'
.sits_get_ts <- function(cube,
                         samples, ...,
                         bands = NULL,
                         impute_fn,
                         multicores,
                         output_dir,
                         progress) {

    # Dispatch
    UseMethod(".sits_get_ts", cube)
}

#' @name .sits_get_ts
#' @keywords internal
#' @export
.sits_get_ts.raster_cube <- function(cube,
                                     samples, ...,
                                     bands,
                                     crs = 4326,
                                     impute_fn,
                                     multicores,
                                     output_dir,
                                     progress) {

    samples <- .sits_transform_samples(samples = samples, crs = crs)

    # filter only tiles that intersects with samples
    cube <- .sits_filter_intersecting_tiles(
        cube = cube,
        samples = samples
    )

    # pre-condition - check bands
    if (is.null(bands)) {
        bands <- .cube_bands(cube)
    }

    .cube_bands_check(cube, bands = bands)

    # is the cloud band available?
    cld_band <- .source_cloud()

    if (cld_band %in% bands) {
        bands <- bands[bands != cld_band]
    } else {
        cld_band <- NULL
    }

    # get cubes timeline
    tl <- sits_timeline(cube)

    tiles_bands <- purrr::cross2(.cube_tiles(cube), bands)

    # prepare parallelization
    .sits_parallel_start(workers = multicores, log = FALSE)
    on.exit(.sits_parallel_stop(), add = TRUE)

    samples_tiles_bands <- .sits_parallel_map(tiles_bands, function(tile_band) {
        tile_id <- tile_band[[1]]
        band <- tile_band[[2]]

        tile <- sits_select(cube, bands = c(band, cld_band), tiles = tile_id)

        hash_bundle <- digest::digest(list(tile, samples), algo = "md5")

        filename <- .create_filename(
            "samples", hash_bundle,
            ext = ".rds",
            output_dir = output_dir
        )

        if (file.exists(filename)) {
            tryCatch(
                {
                    # ensuring that the file is not corrupted
                    timeseries <- readRDS(filename)

                    return(timeseries)
                },
                error = function(e) {
                    unlink(filename)
                    gc()
                }
            )
        }

        # get XY
        xy_tb <- .sits_proj_from_latlong(
            longitude = samples[["longitude"]],
            latitude  = samples[["latitude"]],
            crs       = .cube_crs(tile)
        )
        # join lat-long with XY values in a single tibble
        samples <- dplyr::bind_cols(samples, xy_tb)
        # filter the points inside the data cube space-time extent
        samples <- dplyr::filter(
            samples,
            .data[["X"]] > tile$xmin & .data[["X"]] < tile$xmax &
                .data[["Y"]] > tile$ymin & .data[["Y"]] < tile$ymax &
                .data[["start_date"]] <= as.Date(tl[length(tl)]) &
                .data[["end_date"]] >= as.Date(tl[1])
        )
        # are there points to be retrieved from the cube?
        if (nrow(samples) == 0) {
            return(NULL)
        }
        # create a matrix to extract the values
        xy <- matrix(
            c(samples[["X"]], samples[["Y"]]),
            nrow = nrow(samples),
            ncol = 2
        )
        colnames(xy) <- c("X", "Y")
        # build the sits tibble for the storing the points
        samples_tbl <- slider::slide_dfr(samples, function(point) {

            # get the valid timeline
            dates <- .sits_timeline_during(
                timeline   = tl,
                start_date = as.Date(point[["start_date"]]),
                end_date   = as.Date(point[["end_date"]])
            )
            sample <- tibble::tibble(
                longitude  = point[["longitude"]],
                latitude   = point[["latitude"]],
                start_date = dates[[1]],
                end_date   = dates[[length(dates)]],
                label      = point[["label"]],
                cube       = tile[["collection"]],
                polygon_id = point[["polygon_id"]]
            )
            # store them in the sample tibble
            sample$time_series <- list(tibble::tibble(Index = dates))
            # return valid row of time series
            return(sample)
        })
        ts <- .sits_raster_data_get_ts(
            tile = tile,
            points = samples_tbl,
            bands = band,
            xy = xy,
            cld_band = cld_band,
            impute_fn = impute_fn,
            output_dir = output_dir
        )

        ts[["tile"]] <- tile_id
        ts[["#..id"]] <- seq_len(nrow(ts))

        saveRDS(ts, filename)

        return(ts)
    }, progress = progress)

    ts_tbl <- samples_tiles_bands %>%
        dplyr::bind_rows() %>%
        tidyr::unnest(.data[["time_series"]]) %>%
        dplyr::group_by(
            .data[["longitude"]], .data[["latitude"]],
            .data[["start_date"]], .data[["end_date"]],
            .data[["label"]], .data[["cube"]],
            .data[["Index"]], .data[["tile"]], .data[["#..id"]]
        )

    if ("polygon_id" %in% colnames(ts_tbl)) {
        ts_tbl <- dplyr::group_by(ts_tbl, .data[["polygon_id"]], .add = TRUE)
    }

    ts_tbl <- ts_tbl %>%
        dplyr::summarise(dplyr::across(bands, stats::na.omit)) %>%
        dplyr::arrange(.data[["Index"]]) %>%
        dplyr::ungroup() %>%
        tidyr::nest(time_series = !!c("Index", bands)) %>%
        dplyr::select(-c("tile", "#..id"))

    # recreate hash values
    hash_bundle <- purrr::map_chr(tiles_bands, function(tile_band) {
        tile_id <- tile_band[[1]]
        band <- tile_band[[2]]
        tile <- sits_select(cube, bands = c(band, cld_band), tiles = tile_id)
        digest::digest(list(tile, samples), algo = "md5")
    })

    # recreate file names to delete them
    # samples will be recycled for each hash_bundle
    temp_timeseries <- .create_filename(
        "samples", hash_bundle,
        ext = "rds",
        output_dir = output_dir
    )

    # delete temporary rds
    unlink(temp_timeseries)
    gc()

    # check if data has been retrieved
    .sits_get_data_check(nrow(samples), nrow(ts_tbl))

    if (!inherits(ts_tbl, "sits")) {
        class(ts_tbl) <- c("sits", class(ts_tbl))
    }

    return(ts_tbl)
}

#' @title Check if all points have been retrieved
#' @name .sits_get_data_check
#' @keywords internal
#' @param n_rows_input     Number of rows in input.
#' @param n_rows_output    Number of rows in output.
#'
#' @return No return value, called for side effects.
#'
.sits_get_data_check <- function(n_rows_input, n_rows_output) {

    # Have all input rows being read?
    if (n_rows_output == 0) {
        message("No points have been retrieved")
        return(invisible(FALSE))
    }

    if (n_rows_output < n_rows_input) {
        message("Some points could not be retrieved")
    } else {
        message("All points have been retrieved")
    }
}

#' @title Extracts the time series average by polygon.
#' @name .sits_avg_polygon
#' @keywords internal
#' @description This function extracts the average of the automatically
#' generated points for each polygon in a shapefile.
#'
#' @param data A sits tibble with points time series.
#'
#' @return A sits tibble with the average of all points by each polygon.
.sits_avg_polygon <- function(data) {
    bands <- sits_bands(data)
    columns_to_avg <- c(bands, "latitude", "longitude")

    data_avg <- data %>%
        tidyr::unnest(cols = "time_series") %>%
        dplyr::group_by(
            .data[["Index"]],
            .data[["start_date"]],
            .data[["end_date"]],
            .data[["label"]],
            .data[["cube"]],
            .data[["polygon_id"]]
        ) %>%
        dplyr::summarise(dplyr::across(!!columns_to_avg, mean, na.rm = TRUE),
            .groups = "drop"
        ) %>%
        tidyr::nest("time_series" = c("Index", bands)) %>%
        dplyr::select(!!colnames(data))

    class(data_avg) <- class(data)

    return(data_avg)
}
