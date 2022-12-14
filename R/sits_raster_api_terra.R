#' @keywords internal
#' @export
.raster_check_package.terra <- function() {

    # package namespace
    pkg_name <- "terra"

    # check if terra package is available
    .check_require_packages(pkg_name)

    class(pkg_name) <- pkg_name

    return(invisible(pkg_name))
}

#' @keywords internal
#' @export
.raster_data_type.terra <- function(data_type, ...) {
    return(data_type)
}

#' @keywords internal
#' @export
.raster_resampling.terra <- function(method, ...) {
    return(method)
}

#' @keywords internal
#' @export
.raster_get_values.terra <- function(r_obj, ...) {

    # read values and close connection
    terra::readStart(x = r_obj)
    res <- terra::readValues(x = r_obj, mat = TRUE, ...)
    terra::readStop(x = r_obj)

    return(res)
}

#' @keywords internal
#' @export
.raster_set_values.terra <- function(r_obj, values, ...) {
    terra::values(x = r_obj) <- as.matrix(values)

    return(r_obj)
}

#' @keywords internal
#' @export
.raster_extract.terra <- function(r_obj, xy, ...) {
    terra::extract(x = r_obj, y = xy, ...)
}

#' @keywords internal
#' @export
.raster_rast.terra <- function(r_obj, nlayers = 1, ...) {
    suppressWarnings(
        terra::rast(x = r_obj, nlyrs = nlayers, ...)
    )
}

#' @keywords internal
#' @export
.raster_open_rast.terra <- function(file, ...) {
    suppressWarnings(
        terra::rast(x = file, ...)
    )
}

#' @keywords internal
#' @export
.raster_write_rast.terra <- function(r_obj,
                                     file,
                                     format,
                                     data_type,
                                     gdal_options,
                                     overwrite, ...,
                                     missing_value = NA) {

    # set caller to show in errors
    .check_set_caller(".raster_write_rast.terra")

    suppressWarnings(
        terra::writeRaster(
            x = r_obj,
            filename = file,
            wopt = list(
                filetype = format,
                datatype = data_type,
                gdal = gdal_options
            ),
            NAflag = missing_value,
            overwrite = overwrite, ...
        )
    )

    # was the file written correctly?
    .check_file(
        x = file,
        msg = "unable to write raster object"
    )

    return(invisible(NULL))
}

#' @keywords internal
#' @export
.raster_new_rast.terra <- function(nrows,
                                   ncols,
                                   xmin,
                                   xmax,
                                   ymin,
                                   ymax,
                                   nlayers,
                                   crs, ...,
                                   xres = NULL,
                                   yres = NULL) {

    # prepare resolution
    resolution <- c(xres, yres)

    if (is.null(resolution)) {

        # create a raster object
        r_obj <- suppressWarnings(
            terra::rast(
                nrows = nrows,
                ncols = ncols,
                nlyrs = nlayers,
                xmin  = xmin,
                xmax  = xmax,
                ymin  = ymin,
                ymax  = ymax,
                crs   = crs
            )
        )
    } else {

        # create a raster object
        r_obj <- suppressWarnings(
            terra::rast(
                nlyrs = nlayers,
                xmin = xmin,
                xmax = xmax,
                ymin = ymin,
                ymax = ymax,
                crs = crs,
                resolution = resolution
            )
        )
    }

    return(r_obj)
}

#' @keywords internal
#' @export
.raster_open_stack.terra <- function(files, ...) {
    suppressWarnings(
        terra::rast(files, ...)
    )
}

#' @keywords internal
#' @export
.raster_read_stack.terra <- function(files, ...,
                                     block = NULL,
                                     out_size = NULL,
                                     method = "bilinear") {

    # convert the method to the actual package
    method <- .raster_resampling(method = method)

    # create raster objects
    r_obj <- .raster_open_stack.terra(files = files, ...)

    # get raster size
    in_size <- .raster_size(r_obj)

    # do resample
    if (!is.null(out_size) &&
        (in_size[["nrows"]] != out_size[["nrows"]] ||
            in_size[["ncols"]] != out_size[["ncols"]])) {
        bbox <- .raster_bbox(r_obj, block = block)

        out_r_obj <- .raster_new_rast(
            nrows = out_size[["nrows"]],
            ncols = out_size[["ncols"]],
            xmin = bbox[["xmin"]],
            xmax = bbox[["xmax"]],
            ymin = bbox[["ymin"]],
            ymax = bbox[["ymax"]],
            nlayers = .raster_nlayers(r_obj),
            crs = .raster_crs(r_obj)
        )

        out_r_obj <- terra::resample(r_obj, out_r_obj, method = method)

        # read values
        terra::readStart(out_r_obj)
        values <- terra::readValues(
            x   = out_r_obj,
            mat = TRUE
        )
        # close file descriptor
        terra::readStop(out_r_obj)
    } else {

        # start read
        if (purrr::is_null(block)) {

            # read values
            terra::readStart(r_obj)
            values <- terra::readValues(
                x   = r_obj,
                mat = TRUE
            )
            # close file descriptor
            terra::readStop(r_obj)
        } else {

            # read values
            terra::readStart(r_obj)
            values <- terra::readValues(
                x      = r_obj,
                row    = block[["first_row"]],
                nrows  = block[["nrows"]],
                col    = block[["first_col"]],
                ncols  = block[["ncols"]],
                mat    = TRUE
            )
            # close file descriptor
            terra::readStop(r_obj)
        }
    }

    return(values)
}

#' @keywords internal
#' @export
.raster_crop.terra <- function(r_obj,
                               file,
                               format,
                               data_type,
                               gdal_options,
                               overwrite,
                               block,
                               missing_value = NA) {

    # obtain coordinates from columns and rows
    # get extent
    xmin <- terra::xFromCol(
        object = r_obj,
        col    = block[["first_col"]]
    )
    xmax <- terra::xFromCol(
        object = r_obj,
        col    = block[["first_col"]] + block[["ncols"]] - 1
    )
    ymax <- terra::yFromRow(
        object = r_obj,
        row    = block[["first_row"]]
    )
    ymin <- terra::yFromRow(
        object = r_obj,
        row    = block[["first_row"]] + block[["nrows"]] - 1
    )

    # xmin, xmax, ymin, ymax
    extent <- terra::ext(x = c(xmin, xmax, ymin, ymax))

    # crop raster
    suppressWarnings(
        terra::crop(
            x = r_obj,
            y = extent,
            snap = "out",
            filename = file,
            wopt = list(
                filetype = format,
                datatype = data_type,
                gdal = gdal_options
            ),
            NAflag = missing_value,
            overwrite = overwrite
        )
    )
}

#' @keywords internal
#' @export
.raster_crop_metadata.terra <- function(r_obj, ...,
                                        block = NULL,
                                        bbox = NULL) {

    # obtain coordinates from columns and rows
    if (!is.null(block)) {

        # get extent
        xmin <- terra::xFromCol(
            object = r_obj,
            col    = block[["first_col"]]
        )
        xmax <- terra::xFromCol(
            object = r_obj,
            col    = block[["first_col"]] + block[["ncols"]] - 1
        )
        ymax <- terra::yFromRow(
            object = r_obj,
            row    = block[["first_row"]]
        )
        ymin <- terra::yFromRow(
            object = r_obj,
            row    = block[["first_row"]] + block[["nrows"]] - 1
        )
    } else if (!is.null(bbox)) {
        xmin <- bbox[["xmin"]]
        xmax <- bbox[["xmax"]]
        ymin <- bbox[["ymin"]]
        ymax <- bbox[["ymax"]]
    }

    # xmin, xmax, ymin, ymax
    extent <- terra::ext(x = c(xmin, xmax, ymin, ymax))

    # crop raster
    suppressWarnings(
        terra::crop(x = r_obj, y = extent, snap = "out")
    )
}

#' @keywords internal
#' @export
.raster_nrows.terra <- function(r_obj, ...) {
    terra::nrow(x = r_obj)
}

#' @keywords internal
#' @export
.raster_ncols.terra <- function(r_obj, ...) {
    terra::ncol(x = r_obj)
}

#' @keywords internal
#' @export
.raster_nlayers.terra <- function(r_obj, ...) {
    terra::nlyr(x = r_obj)
}

#' @keywords internal
#' @export
.raster_xmax.terra <- function(r_obj, ...) {
    terra::xmax(x = r_obj)
}

#' @keywords internal
#' @export
.raster_xmin.terra <- function(r_obj, ...) {
    terra::xmin(x = r_obj)
}

#' @keywords internal
#' @export
.raster_ymax.terra <- function(r_obj, ...) {
    terra::ymax(x = r_obj)
}

#' @keywords internal
#' @export
.raster_ymin.terra <- function(r_obj, ...) {
    terra::ymin(x = r_obj)
}

#' @keywords internal
#' @export
.raster_xres.terra <- function(r_obj, ...) {
    terra::xres(x = r_obj)
}

#' @keywords internal
#' @export
.raster_yres.terra <- function(r_obj, ...) {
    terra::yres(x = r_obj)
}

#' @keywords internal
#' @export
.raster_crs.terra <- function(r_obj, ...) {
    crs <- suppressWarnings(
        terra::crs(x = r_obj, describe = TRUE)
    )

    if (!is.na(crs[["code"]])) {
        return(c(crs = paste(crs[["authority"]], crs[["code"]], sep = ":")))
    }

    suppressWarnings(
        c(crs = as.character(terra::crs(x = r_obj)))
    )
}

#' @keywords internal
#' @export
#'
.raster_freq.terra <- function(r_obj, ...) {
    terra::freq(x = r_obj, bylayer = TRUE)
}

#' @keywords internal
#' @export
.raster_col.terra <- function(r_obj, x) {
    terra::colFromX(r_obj, x)
}


#' @keywords internal
#' @export
.raster_row.terra <- function(r_obj, y) {
    terra::rowFromY(r_obj, y)
}
