test_that("Plot Time Series and Images", {


    cerrado_ndvi <- sits_select(cerrado_2classes, "NDVI")

    p <- plot(cerrado_ndvi[1, ])
    expect_equal(p$labels$title, "location (-14.05, -54.23) - Cerrado")

    cerrado_ndvi_1class <- dplyr::filter(cerrado_ndvi, label == "Cerrado")
    p1 <- plot(cerrado_ndvi_1class)
    expect_equal(
        p1$labels$title,
        "Samples (400) for class Cerrado in band = NDVI"
    )

    p2 <- plot(sits_patterns(cerrado_2classes))
    expect_equal(p2$guides$colour$title, "Bands")
    expect_equal(p2$theme$legend.position, "bottom")

    samples_mt_ndvi <- sits_select(samples_modis_4bands, bands = "NDVI")
    point_ndvi <- sits_select(point_mt_6bands, bands = "NDVI")
    rfor_model <- sits_train(samples_mt_ndvi, ml_method = sits_rfor())
    point_class <- sits_classify(point_ndvi, rfor_model)
    p3 <- plot(point_class)
    expect_equal(p3[[1]]$labels$y, "Value")
    expect_equal(p3[[1]]$labels$x, "Time")
    expect_equal(p3[[1]]$theme$legend.position, "bottom")

    data_dir <- system.file("extdata/raster/mod13q1", package = "sits")
    sinop <- sits_cube(
        source = "BDC",
        collection = "MOD13Q1-6",
        data_dir = data_dir,
        parse_info = c("X1", "X2", "tile", "band", "date")
    )
    bbox <- sits_bbox(sinop)
    size_x <- bbox[["xmax"]] - bbox[["xmin"]]
    size_y <- bbox[["ymax"]] - bbox[["ymin"]]


    r_obj <- plot(sinop, band = "NDVI")

    expect_equal(terra::nlyr(r_obj), 3)
    expect_equal(terra::ncol(r_obj), 254)

    sinop_probs <- suppressMessages(
        sits_classify(
            sinop,
            ml_model = rfor_model,
            memsize = 2,
            multicores = 1,
            output_dir = tempdir()
        )
    )
    p_probs <- plot(sinop_probs)
    expect_equal(p_probs$adj, 0.5)
    expect_equal(p_probs$lend, "round")

    p_probs <- plot(sinop_probs, labels = "Forest")
    expect_equal(p_probs$adj, 0.5)
    expect_equal(p_probs$lend, "round")

    sinop_uncert <- sits_uncertainty(sinop_probs,
        output_dir = tempdir()
    )

    p_uncert <- plot(sinop_uncert)

    expect_equal(p_uncert$adj, 0.5)
    expect_equal(p_uncert$lend, "round")

    expect_equal(p_uncert$lty, "solid")

    sinop_labels <- sits_label_classification(sinop_probs,
        output_dir = tempdir()
    )

    p4 <- plot(sinop_labels, title = "Classified image")
    expect_equal(p4$labels$title, "Classified image")
    expect_equal(p4$layers[[1]]$geom_params$hjust, 0.5)
    expect_true(p4$layers[[1]]$inherit.aes)

    p5 <- plot(sinop_labels,
        title = "Classified image",
        legend = c(
            "Cerrado" = "#B9E3B2",
            "Forest" = "#68BE70",
            "Pasture" = "#EEF8EB",
            "Soy_Corn" = "#F17C1A"
        )
    )

    expect_equal(p5$labels$title, "Classified image")
    expect_equal(p5$layers[[1]]$geom_params$hjust, 0.5)
    expect_true(p5$layers[[1]]$inherit.aes)

    expect_true(all(file.remove(unlist(sinop_probs$file_info[[1]]$path))))
    expect_true(all(file.remove(unlist(sinop_labels$file_info[[1]]$path))))
})

test_that("Dendrogram Plot", {


    cluster_obj <- sits:::.sits_cluster_dendrogram(cerrado_2classes,
        bands = c("NDVI", "EVI")
    )
    cut.vec <- sits:::.sits_cluster_dendro_bestcut(
        cerrado_2classes,
        cluster_obj
    )

    dend <- sits:::.sits_plot_dendrogram(
        data = cerrado_2classes,
        cluster = cluster_obj,
        cutree_height = cut.vec["height"],
        palette = "RdYlGn"
    )
    expect_equal(class(dend), "dendrogram")
})

test_that("Plot torch model", {


    samples_ndvi <- sits_select(samples_modis_4bands,
        bands = c("NDVI")
    )
    model <- sits_train(
        samples_ndvi,
        sits_mlp(
            layers = c(128, 128),
            dropout_rates = c(0.5, 0.4),
            epochs = 50
        )
    )
    pk <- plot(model)
    expect_true(length(pk$layers) == 2)
    expect_true(pk$labels$colour == "data")
    expect_true(pk$labels$x == "epoch")
    expect_true(pk$labels$y == "value")
})

test_that("Plot series with NA", {
    cerrado_ndvi <- cerrado_2classes %>%
        sits_select(bands = "NDVI") %>%
        dplyr::filter(label == "Cerrado")
    cerrado_ndvi_1 <- cerrado_ndvi[1, ]
    ts <- cerrado_ndvi_1$time_series[[1]]
    ts[1, 2] <- NA
    ts[10, 2] <- NA
    cerrado_ndvi_1$time_series[[1]] <- ts
    pna <- suppressWarnings(plot(cerrado_ndvi_1))
    expect_true(pna$labels$x == "Index")
    expect_true(pna$labels$y == "value")
})

test_that("SOM map plot", {


    set.seed(1234)
    som_map <-
        suppressWarnings(sits_som_map(
            cerrado_2classes,
            grid_xdim = 5,
            grid_ydim = 5
        ))

    p <- suppressWarnings(plot(som_map))
    expect_true(all(names(p$rect) %in% c("w", "h", "left", "top")))

    pc <- plot(som_map, type = "mapping")
    expect_true(all(names(pc$rect) %in% c("w", "h", "left", "top")))
})

test_that("SOM evaluate cluster plot", {


    set.seed(1234)
    som_map <-
        suppressWarnings(sits_som_map(
            cerrado_2classes,
            grid_xdim = 5,
            grid_ydim = 5
        ))

    cluster_purity_tb <- sits_som_evaluate_cluster(som_map)

    p <- plot(cluster_purity_tb)
    expect_equal(p$labels$title, "Confusion by cluster")
    expect_equal(p$labels$y, "Percentage of mixture")
})
