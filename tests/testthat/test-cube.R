test_that("Reading a raster cube", {
    data_dir <- system.file("extdata/raster/mod13q1", package = "sits")

    raster_cube <- tryCatch(
        {
            sits_cube(
                source = "BDC",
                collection = "MOD13Q1-6",
                data_dir = data_dir,
                delim = "_",
                parse_info = c("X1", "X2", "tile", "band", "date"),
                multicores = 2
            )
        },
        error = function(e) {
            return(NULL)
        }
    )

    testthat::skip_if(purrr::is_null(raster_cube),
        message = "LOCAL cube not found"
    )

    # get bands names
    bands <- sits_bands(raster_cube)
    expect_true(all(bands %in% c("NDVI", "EVI")))

    params <- .raster_params_file(raster_cube$file_info[[1]]$path)
    expect_true(params$nrows == 144)
    expect_true(params$ncols == 254)
    expect_true(params$xres >= 231.5)
})

test_that("Creating cubes from BDC", {


    # check "BDC_ACCESS_KEY" - mandatory one per user
    bdc_access_key <- Sys.getenv("BDC_ACCESS_KEY")

    testthat::skip_if(nchar(bdc_access_key) == 0,
        message = "No BDC_ACCESS_KEY defined in environment."
    )

    # create a raster cube file based on the information about the files
    expect_message(
        object = (cbers_cube <-
            tryCatch(
                {
                    sits_cube(
                        source = "BDC",
                        collection = "CB4_64_16D_STK-1",
                        tile = c("022024", "022023"),
                        start_date = "2018-09-01",
                        end_date = "2019-08-29"
                    )
                },
                error = function(e) {
                    return(NULL)
                }
            )
        ),
        regexp = "please use tiles instead of tile as parameter"
    )

    testthat::skip_if(purrr::is_null(cbers_cube),
        message = "BDC is not accessible"
    )

    expect_true(all(sits_bands(cbers_cube) %in%
        c("NDVI", "EVI", "B13", "B14", "B15", "B16", "CLOUD")))
    bbox <- sits_bbox(cbers_cube)
    int_bbox <- sits:::.sits_bbox_intersect(bbox, cbers_cube[1, ])
    expect_true(all(int_bbox == sits_bbox(cbers_cube[1, ])))

    timeline <- sits_timeline(cbers_cube)
    expect_true(timeline[1] <= as.Date("2018-09-01"))
    expect_true(timeline[length(timeline)] <= as.Date("2019-08-29"))

    r_obj <- sits:::.raster_open_rast(cbers_cube$file_info[[1]]$path[1])
    expect_error(sits:::.cube_size(cbers_cube), "process one tile at a time")

    cube_nrows <- sits:::.cube_size(cbers_cube[1, ])[["nrows"]]
    expect_true(terra::nrow(r_obj) == cube_nrows)
})

test_that("Creating cubes from BDC - based on ROI with shapefile", {


    # check "BDC_ACCESS_KEY" - mandatory one per user
    bdc_access_key <- Sys.getenv("BDC_ACCESS_KEY")

    testthat::skip_if(nchar(bdc_access_key) == 0,
        message = "No BDC_ACCESS_KEY defined in environment."
    )

    shp_file <- system.file(
        "extdata/shapefiles/brazilian_legal_amazon/brazilian_legal_amazon.shp",
        package = "sits"
    )
    sf_bla <- sf::read_sf(shp_file)

    # create a raster cube file based on the information about the files
    expect_message(
        object = (modis_cube <-
            tryCatch(
                {
                    sits_cube(
                        source = "BDC",
                        collection = "MOD13Q1-6",
                        bands = c("NDVI", "EVI"),
                        roi = sf_bla,
                        start_date = "2018-09-01",
                        end_date = "2019-08-29"
                    )
                },
                error = function(e) {
                    return(NULL)
                }
            )
        ),
        regexp = "The supplied roi will be transformed to the WGS 84."
    )

    testthat::skip_if(purrr::is_null(modis_cube),
        message = "BDC is not accessible"
    )

    expect_true(all(sits_bands(modis_cube) %in% c("NDVI", "EVI")))
    bbox <- sits_bbox(modis_cube, wgs84 = TRUE)
    bbox_shp <- sf::st_bbox(sf_bla)

    expect_lt(bbox["xmin"], bbox_shp["xmin"])
    expect_lt(bbox["ymin"], bbox_shp["ymin"])
    expect_gt(bbox["xmax"], bbox_shp["xmax"])
    expect_gt(bbox["ymax"], bbox_shp["ymax"])
    intersects <- slider::slide_lgl(modis_cube, function(tile) {
        sits:::.sits_raster_sub_image_intersects(tile, sf_bla)
    })
    expect_true(all(intersects))
})

test_that("Creating cubes from BDC - invalid roi", {


    # check "BDC_ACCESS_KEY" - mandatory one per user
    bdc_access_key <- Sys.getenv("BDC_ACCESS_KEY")

    testthat::skip_if(nchar(bdc_access_key) == 0,
        message = "No BDC_ACCESS_KEY defined in environment."
    )

    expect_error(
        object = sits_cube(
            source = "BDC",
            collection = "MOD13Q1-6",
            bands = c("NDVI", "EVI"),
            roi = c(TRUE, FALSE),
            start_date = "2018-09-01",
            end_date = "2019-08-29"
        )
    )

    expect_error(
        object = sits_cube(
            source = "BDC",
            collection = "MOD13Q1-6",
            bands = c("NDVI", "EVI"),
            roi = c(
                lon_min = -55.20997,
                lat_min = 15.40554,
                lon_max = -55.19883,
                lat_max = -15.39179
            ),
            tiles = "012010",
            start_date = "2018-09-01",
            end_date = "2019-08-29"
        )
    )
})

test_that("Creating cubes from DEA", {


    dea_cube <- tryCatch(
        {
            sits_cube(
                source = "DEAFRICA",
                collection = "s2_l2a",
                bands = c("B01", "B04", "B05"),
                roi = c(
                    lon_min = 17.379,
                    lat_min = 1.1573,
                    lon_max = 17.410,
                    lat_max = 1.1910
                ),
                start_date = "2019-01-01",
                end_date = "2019-10-28"
            )
        },
        error = function(e) {
            return(NULL)
        }
    )
    testthat::skip_if(purrr::is_null(dea_cube),
        message = "DEAFRICA is not accessible"
    )

    expect_true(all(sits_bands(dea_cube) %in% c("B01", "B04", "B05")))

    file_info <- dea_cube$file_info[[1]]
    r <- .raster_open_rast(file_info$path[[1]])

    expect_equal(dea_cube$xmax[[1]], .raster_xmax(r), tolerance = 1)
    expect_equal(dea_cube$xmin[[1]], .raster_xmin(r), tolerance = 1)
})

test_that("Creating cubes from DEA - error using tiles", {


    expect_error(
        dea_cube <-
            sits_cube(
                source = "DEAFRICA",
                collection = "s2_l2a",
                bands = c("B01", "B04", "B05"),
                tiles = "37MEP",
                start_date = "2019-01-01",
                end_date = "2019-10-28"
            ),
        "DEAFRICA cubes do not support searching for tiles"
    )
})

test_that("Regularizing cubes from AWS, and extracting samples from them", {
    s2_cube_open <- tryCatch(
        {
            sits_cube(
                source = "AWS",
                collection = "SENTINEL-S2-L2A-COGS",
                tiles = c("20LKP", "20LLP"),
                bands = c("B8A", "SCL"),
                start_date = "2018-10-01",
                end_date = "2018-11-01"
            )
        },
        error = function(e) {
            return(NULL)
        }
    )
    testthat::skip_if(
        purrr::is_null(s2_cube_open),
        "AWS is not accessible"
    )
    expect_false(.cube_is_regular(s2_cube_open))
    expect_true(all(sits_bands(s2_cube_open) %in% c("B8A", "CLOUD")))

    expect_error(.cube_size(s2_cube_open))
    expect_error(.cube_resolution(s2_cube_open))
    expect_error(.file_info_nrows(s2_cube_open))

    dir_images <- paste0(tempdir(), "/images2/")
    if (!dir.exists(dir_images)) {
        suppressWarnings(dir.create(dir_images))
    }

    rg_cube <- sits_regularize(
        cube = s2_cube_open[1, ],
        output_dir = dir_images,
        res = 240,
        period = "P16D",
        multicores = 1
    )

    tile_size <- .cube_size(rg_cube[1, ])
    tile_bbox <- .cube_tile_bbox(rg_cube[1, ])

    expect_equal(tile_size[["nrows"]], 458)
    expect_equal(tile_size[["ncols"]], 458)
    expect_equal(tile_bbox$xmax, 309780, tolerance = 1e-1)
    expect_equal(tile_bbox$xmin, 199980, tolerance = 1e-1)

    tile_fileinfo <- .file_info(rg_cube[1, ])

    expect_equal(nrow(tile_fileinfo), 2)

    csv_file <- system.file("extdata/samples/samples_amazonia_sentinel2.csv",
        package = "sits"
    )

    # read sample information from CSV file and put it in a tibble
    samples <- tibble::as_tibble(utils::read.csv(csv_file))
    expect_equal(nrow(samples), 1202)
    samples <- dplyr::sample_n(samples, size = 10, replace = FALSE)

    ts <- sits_get_data(
        cube = rg_cube,
        samples = samples,
        output_dir = dir_images
    )

    vls <- unlist(sits_values(ts))
    expect_true(all(vls > 0 & vls < 1.))
    expect_equal(sits_bands(ts), sits_bands(rg_cube))
    expect_equal(sits_timeline(ts), sits_timeline(rg_cube))
})

test_that("Creating cubes from USGS", {
    # check "AWS_ACCESS_KEY_ID" - mandatory one per user
    aws_access_key_id <- Sys.getenv("AWS_ACCESS_KEY_ID")

    # check "AWS_SECRET_ACCESS_KEY" - mandatory one per user
    aws_secret_access_key <- Sys.getenv("AWS_SECRET_ACCESS_KEY")

    testthat::skip_if(
        nchar(aws_access_key_id) == 0,
        message = "No AWS_ACCESS_KEY_ID defined in environment."
    )

    testthat::skip_if(
        nchar(aws_secret_access_key) == 0,
        message = "No AWS_SECRET_ACCESS_KEY defined in environment."
    )

    Sys.unsetenv("AWS_DEFAULT_REGION")
    Sys.unsetenv("AWS_S3_ENDPOINT")
    Sys.unsetenv("AWS_REQUEST_PAYER")

    usgs_cube_1 <- tryCatch(
        {
            sits_cube(
                source = "USGS",
                collection = "landsat-c2l2-sr",
                bands = c("GREEN", "CLOUD"),
                roi = c(
                    "xmin" = 17.379,
                    "ymin" = 1.1573,
                    "xmax" = 17.410,
                    "ymax" = 1.1910
                ),
                start_date = "2019-01-01",
                end_date = "2019-02-01"
            )
        },
        error = function(e) {
            return(NULL)
        }
    )
    testthat::skip_if(
        purrr::is_null(usgs_cube_1),
        "USGS is not accessible"
    )
    expect_true(all(sits_bands(usgs_cube_1) %in% c("GREEN", "CLOUD")))

    expect_equal(class(.cube_resolution(usgs_cube_1)), "numeric")

    file_info <- usgs_cube_1$file_info[[1]]
    r <- .raster_open_rast(file_info$path[[1]])

    expect_equal(usgs_cube_1$xmax[[1]], .raster_xmax(r), tolerance = 1)
    expect_equal(usgs_cube_1$xmin[[1]], .raster_xmin(r), tolerance = 1)

    usgs_cube_2 <- tryCatch(
        {
            sits_cube(
                source = "USGS",
                collection = "landsat-c2l2-sr",
                bands = c("GREEN", "CLOUD"),
                tiles = "223067",
                start_date = "2019-01-01",
                end_date = "2019-10-28"
            )
        },
        error = function(e) {
            return(NULL)
        }
    )

    testthat::skip_if(
        purrr::is_null(usgs_cube_2),
        "USGS is not accessible"
    )

    expect_true(all(sits_bands(usgs_cube_2) %in% c("GREEN", "CLOUD")))

    expect_equal(class(.cube_resolution(usgs_cube_2)), "numeric")

    file_info <- usgs_cube_2$file_info[[1]]
    r <- .raster_open_rast(file_info$path[[1]])

    expect_equal(usgs_cube_2$xmax[[1]], .raster_xmax(r), tolerance = 1)
    expect_equal(usgs_cube_2$xmin[[1]], .raster_xmin(r), tolerance = 1)
})

test_that("Creating Sentinel cubes from MPC", {


    s2_cube <- tryCatch(
        {
            sits_cube(
                source = "MPC",
                collection = "SENTINEL-2-L2A",
                tiles = "20LKP",
                bands = c("B05", "CLOUD"),
                start_date = as.Date("2018-07-18"),
                end_date = as.Date("2018-08-23")
            )
        },
        error = function(e) {
            return(NULL)
        }
    )

    testthat::skip_if(
        purrr::is_null(s2_cube),
        "MPC is not accessible"
    )

    expect_true(all(sits_bands(s2_cube) %in% c("B05", "CLOUD")))

    expect_equal(class(.cube_size(s2_cube)), "numeric")
    expect_equal(class(.cube_resolution(s2_cube)), "numeric")

    file_info <- s2_cube$file_info[[1]]
    r <- .raster_open_rast(file_info$path[[1]])

    expect_equal(s2_cube$xmax[[1]], .raster_xmax(r), tolerance = 1)
    expect_equal(s2_cube$xmin[[1]], .raster_xmin(r), tolerance = 1)
})

test_that("Creating Sentinel cubes from MPC with ROI", {


    shp_file <- system.file("extdata/shapefiles/df_bsb/df_bsb.shp",
        package = "sits"
    )
    sf_bsb <- sf::read_sf(shp_file)

    s2_cube <- tryCatch(
        {
            sits_cube(
                source = "MPC",
                collection = "SENTINEL-2-L2A",
                roi = sf_bsb,
                bands = c("B05", "CLOUD"),
                start_date = as.Date("2018-07-18"),
                end_date = as.Date("2018-08-23")
            )
        },
        error = function(e) {
            return(NULL)
        }
    )

    testthat::skip_if(purrr::is_null(s2_cube), "MPC is not accessible")

    expect_true(all(sits_bands(s2_cube) %in% c("B05", "CLOUD")))

    expect_equal(class(sits:::.cube_size(s2_cube[1, ])), "numeric")
    expect_equal(class(sits:::.cube_resolution(s2_cube[1, ])), "numeric")

    file_info <- s2_cube$file_info[[1]]
    r <- sits:::.raster_open_rast(file_info$path[[1]])

    expect_equal(nrow(s2_cube), 3)
    expect_warning(sits_bbox(s2_cube), "cube has more than one projection")

    bbox_cube <- sits_bbox(s2_cube, wgs84 = TRUE)
    bbox_cube_1 <- sits_bbox(s2_cube[1, ], wgs84 = TRUE)
    expect_true(bbox_cube["xmax"] >= bbox_cube_1["xmax"])
    expect_true(bbox_cube["ymax"] >= bbox_cube_1["ymax"])

    expect_warning(
        object = sits_timeline(s2_cube),
        regexp = "Cube is not regular. Returning all timelines"
    )
})

test_that("Creating Landsat cubes from MPC", {

    shp_file <- system.file("extdata/shapefiles/df_bsb/df_bsb.shp",
                            package = "sits"
    )
    sf_bsb <- sf::read_sf(shp_file)

    landsat_cube <- tryCatch(
        {
            sits_cube(
                source = "MPC",
                collection = "LANDSAT-C2-L2",
                roi = sf_bsb,
                bands = c("NIR08", "CLOUD"),
                start_date = as.Date("2008-07-18"),
                end_date = as.Date("2008-10-23")
            )
        },
        error = function(e) {
            return(NULL)
        }
    )

    testthat::skip_if(purrr::is_null(landsat_cube), "MPC is not accessible")

    expect_true(all(sits_bands(landsat_cube) %in% c("NIR08", "CLOUD")))
    expect_false(.cube_is_regular(landsat_cube))
    expect_equal(class(.file_info_xres(landsat_cube[1,])), "numeric")
    expect_true(any(grepl("LT05", landsat_cube$file_info[[1]]$fid)))
    expect_true(any(grepl("LE07", landsat_cube$file_info[[1]]$fid)))

    file_info <- landsat_cube$file_info[[1]]
    r <- .raster_open_rast(file_info$path[[1]])

    expect_equal(landsat_cube$xmax[[1]], .raster_xmax(r), tolerance = 1)
    expect_equal(landsat_cube$xmin[[1]], .raster_xmin(r), tolerance = 1)

    output_dir <- paste0(tempdir(), "/images")
    if (!dir.exists(output_dir)) {
        dir.create(output_dir)
    }

    rg_landsat <- sits_regularize(
        cube        = landsat_cube,
        output_dir  = output_dir,
        res         = 240,
        period      = "P30D",
        multicores  = 4
    )

    size <- .cube_size(rg_landsat[1,])

    expect_equal(size[["nrows"]], 856)
    expect_equal(size[["ncols"]], 967)

    expect_true(.cube_is_regular(rg_landsat))

    l5_cube <- tryCatch(
        {
            sits_cube(
                source = "MPC",
                collection = "LANDSAT-C2-L2",
                platform = "LANDSAT-5",
                roi = sf_bsb,
                bands = c("NIR08", "CLOUD"),
                start_date = as.Date("2008-07-18"),
                end_date = as.Date("2008-10-23")
            )
        },
        error = function(e) {
            return(NULL)
        }
    )
    expect_true(any(grepl("LT05", l5_cube$file_info[[1]]$fid)))
    expect_false(any(grepl("LE07", l5_cube$file_info[[1]]$fid)))

    expect_error(sits_cube(
                source = "MPC",
                collection = "LANDSAT-C2-L2",
                bands = c("NIR08", "CLOUD"),
                tiles = "220071",
                start_date = "2019-01-01",
                end_date = "2019-10-28"
            )
    )
})

test_that("Creating a raster stack cube with BDC band names", {
    # Create a raster cube based on CBERS data
    data_dir <- system.file("extdata/raster/bdc", package = "sits")

    # create a raster cube file based on the information about the files
    cbers_cube_bdc <- tryCatch(
        {
            sits_cube(
                source = "BDC",
                collection = "CB4_64-1",
                data_dir = data_dir,
                parse_info = c(
                    "X1", "X2", "X3", "X4", "X5", "tile",
                    "date", "X6", "band"
                ),
                multicores = 2
            )
        },
        error = function(e) {
            return(NULL)
        }
    )

    testthat::skip_if(purrr::is_null(cbers_cube_bdc),
        message = "LOCAL cube not found"
    )

    expect_true(all(sits_bands(cbers_cube_bdc) %in%
        c("B16")))
})
