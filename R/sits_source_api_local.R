#' @keywords internal
#' @export
.source_access_test.local_cube <- function(source, collection, ...) {

    assertthat::assert_that(
        collection %in% .config_collections(source = source),
        msg = paste(".source_access_test.local_cube: satellite or sensor not",
                    "found.\nPlease, check sits config with ?sits_config",
                    "command.")
    )

    return(invisible(NULL))
}

#' @keywords internal
#' @export
.source_cube.local_cube <- function(source, ...,
                                    collection,
                                    name,
                                    data_dir,
                                    parse_info,
                                    delim,
                                    bands,
                                    start_date,
                                    end_date) {


    file_info <- .source_items_fileinfo(source = source,
                                        items = data_dir, ...,
                                        collection = collection,
                                        parse_info = parse_info,
                                        delim = delim,
                                        bands = bands,
                                        start_date = start_date,
                                        end_date = end_date)

    # get the tiles
    tiles <- unique(file_info$tile)

    cube <- purrr::map_dfr(tiles, function(t){
        # get the files for a given tile
        row_file_info <- dplyr::filter(file_info, tile == t)

        # get the bands
        bands <- unique(row_file_info$band)
        # get the parameters from the raster object of one of the layers
        # the assumptions is that all layers are consistent
        params <- .raster_params_file(row_file_info$path[1])

        # create a tibble to store the metadata
        row <- .sits_cube_create(
            name = name,
            source = "LOCAL",
            satellite = strsplit(collection, "/")[[1]][[1]],
            sensor = strsplit(collection, "/")[[1]][[2]],
            collection = collection,
            tile = t,
            bands = bands,
            nrows = params$nrows,
            ncols = params$ncols,
            xmin = params$xmin,
            xmax = params$xmax,
            ymin = params$ymin,
            ymax = params$ymax,
            xres = params$xres,
            yres = params$yres,
            crs = params$crs,
            file_info = row_file_info
        )
    })


    class(cube) <- c("raster_cube", class(cube))

    return(cube)
}

.source_items_fileinfo.local_cube <- function(source,
                                              items, ...,
                                              collection,
                                              parse_info,
                                              delim,
                                              bands,
                                              start_date,
                                              end_date) {

    file_info <- purrr::map_dfr(items, function(data_dir_row) {

        # how many of those files are images?
        # retrieve the known file extensions
        file_ext <- .config_local_file_extensions()

        # list the files in the data directory
        img_files <- list.files(
            path = data_dir_row,
            pattern = paste0(
                "\\.(",
                paste0(.config_local_file_extensions(), collapse = "|"),
                ")$")
        )

        assertthat::assert_that(
            length(img_files) > 0,
            msg = paste(".source_items_fileinfo.local_cube: no file found in",
                        "provided directory.")
        )

        # remove the extension
        img_files_noext <- tools::file_path_sans_ext(img_files)

        # split the file names
        img_files_lst <- strsplit(img_files_noext, split = delim)

        # bind rows
        img_files_mx <- do.call(rbind, img_files_lst)

        # read the image files into a tibble with added parse info
        colnames(img_files_mx) <- parse_info

        # joint the list into a tibble and convert bands name to upper case
        img_files_tb <- tibble::as_tibble(
            img_files_mx,
            .name_repair = "minimal"
        ) %>% dplyr::mutate(band = toupper(band))

        # get the information on the required bands, dates and path
        file_info <- img_files_tb %>%
            # select the relevant parts
            dplyr::select(tile, date, band) %>%
            # check the date format
            .sits_timeline_date_format() %>%
            # include path in the tibble
            dplyr::mutate(path = paste0(data_dir_row, "/", img_files)) %>%
            # filter to remove duplicate combinations of file and band
            dplyr::distinct(tile, band, date, .keep_all = TRUE) %>%
            # order by dates
            dplyr::arrange(date)

        # extract the band names
        bands_files <- unique(file_info$band)

        # convert the band names to SITS bands
        file_info <- dplyr::mutate(
            file_info,
            band = .source_bands_to_sits(source = "LOCAL",
                                         collection = collection,
                                         bands = band))

        # filter bands
        if (!purrr::is_null(bands)) {

            # get the bands of the cube
            bands_info <- dplyr::pull(dplyr::distinct(file_info, band))

            # verify that the requested bands exist
            assertthat::assert_that(
                all(bands %in% bands_info),
                msg = paste(".sits_raster_stack_info: requested bands not",
                            "available in cube")
            )

            # select the requested bands
            file_info <- dplyr::filter(file_info, band %in% bands)
        }

        # filter start and end dates
        if (!purrr::is_null(start_date))
            file_info <- dplyr::filter(file_info,
                                       date >= start_date)

        if (!purrr::is_null(end_date))
            file_info <- dplyr::filter(file_info,
                                       date <= end_date)

        assertthat::assert_that(
            nrow(file_info) > 0,
            msg = paste(".source_items_fileinfo.local_cube: no files in the",
                        "provided time interval")
        )

        params <- .raster_params_file(file_info$path[1])
        resolution <- params$xres
        file_info <- dplyr::mutate(file_info,
                                   res = resolution, .before = path)

        # post condition
        assertthat::assert_that(
            nrow(file_info) > 0,
            msg = paste(".sits_raster_stack_info: no file was found for the",
                        "requested local cube. Please, verify the 'start_date'",
                        "and 'end_date' and check if the provided directory is",
                        "valid.")
        )

        file_info
    })

    return(file_info)
}