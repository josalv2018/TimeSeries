#' @title Use time series values as distances for training patterns
#' @name .sits_distances
#' @keywords internal
#' @author Rolf Simoes, \email{rolf.simoes@@inpe.br}
#' @author Gilberto Camara, \email{gilberto.camara@@inpe.br}
#'
#' @description This function allows using a set of labelled time series as
#' input to the machine learning models. The attributes used to train the model
#' are the series themselves. It extracts the time series from a sits tibble
#' and "spreads" them in time to produce a tibble with distances.
#'
#' @param  data       Tibble with time series data and metadata.
#' @return            Data.table where columns have the reference label
#'                    and the time series values as distances.
#'
.sits_distances <- function(data) {

    # check the sits tibble
    .sits_tibble_test(data)

    # get bands order
    bands <- names(data$time_series[[1]][-1])

    # create a tibble with the time series transposed from columns to rows
    # and create original_row and reference columns as the first two
    # columns for training
    distances_tbl <- data %>%
        dplyr::mutate(
            original_row = seq_len(nrow(data)),
            reference = .data[["label"]]
        ) %>%
        tidyr::unnest("time_series") %>%
        dplyr::select("original_row", "reference", !!bands) %>%
        dplyr::group_by(.data[["original_row"]]) %>%
        dplyr::mutate(temp_index = seq_len(dplyr::n())) %>%
        dplyr::ungroup()

    if (length(bands) > 1) {
        distances_tbl <- tidyr::pivot_wider(distances_tbl,
            names_from = .data[["temp_index"]],
            values_from = !!bands,
            names_sep = ""
        )
    } else {
        distances_tbl <- tidyr::pivot_wider(distances_tbl,
            names_from = .data[["temp_index"]],
            values_from = !!bands,
            names_prefix = bands,
            names_sep = ""
        )
    }

    distances <- data.table::data.table(distances_tbl)

    return(distances)
}

#' @title Classify a distances tibble using machine learning models
#' @name .sits_distances_classify
#' @keywords internal
#' @author Gilberto Camara, \email{gilberto.camara@@inpe.br}
#'
#' @description Returns a sits tibble with the results of the ML classifier.
#'
#' @param  distances       data.table with distances.
#' @param  class_info      tibble with classification information.
#' @param  ml_model        model trained by \code{\link[sits]{sits_train}}.
#' @param  multicores      number of threads to process the time series.
#' @return A data.table with the predicted labels.
#'
.sits_distances_classify <- function(distances, class_info,
                                     ml_model, multicores) {

    # set caller to show in errors
    .check_set_caller(".sits_distances_classify")

    # torch-based models do their own arallelization
    if (inherits(ml_model, c("torch_model", "xgb_model"))) {
        multicores <- 1
    }
    # are we running on Windows?
    if (.Platform$OS.type != "unix") {
        multicores <- 1
    }

    # define the column names
    attr_names <- names(.sits_distances(.sits_ml_model_samples(ml_model)[1, ]))
    .check_that(
        x = length(attr_names) > 0,
        msg = "training data not available"
    )

    # select the data table indexes for each time index
    selected_idx <- .sits_timeline_dist_indexes(
        class_info,
        ncol(distances)
    )

    # classify a block of data
    classify_block <- function(block) {
        # create a list to store the data tables to be used for prediction
        rows <- purrr::map(selected_idx, function(sel_index) {
            block_sel <- block[, sel_index, with = FALSE]
            return(block_sel)
        })
        # create a set of distances to be classified
        dist_block <- data.table::rbindlist(rows, use.names = FALSE)
        # set the attribute names of the columns
        colnames(dist_block) <- attr_names

        # classify the subset data
        pred_block <- ml_model(dist_block)

        return(pred_block)
    }
    # if multicores > 1, break blocks for parallel processing
    if (multicores > 1) {
        n_rows_dist <- nrow(distances)
        blocks <- split.data.frame(
            distances,
            cut(1:n_rows_dist,
                multicores,
                labels = FALSE
            )
        )
        # apply parallel processing to the split data
        results <- parallel::mclapply(
            blocks,
            classify_block,
            mc.cores = multicores
        )
        # join blocks to get the result
        predicted <- do.call(rbind, results)
    }
    # sequential processing
    else {
        predicted <- classify_block(distances)
    }
    return(predicted)
}

#' @title Sample a percentage of a time series distance matrix
#' @name .sits_distances_sample
#' @keywords internal
#' @author Rolf Simoes, \email{rolf.simoes@@inpe.br}
#'
#' @description Takes a sits tibble with different labels and
#'              returns a new tibble. For a given field as a group criterion,
#'              this new table contains a given number or percentage
#'              of the total number of samples per group. Parameter n indicates
#'              the number of random samples with reposition.
#'              Parameter frac indicates a fraction of random samples
#'              without reposition. If frac > 1, no sampling is done.
#'
#' @param  distances       Distances associated to a time series.
#' @param  frac            Percentage of samples to pick.
#' @return                 Data.table with a fixed quantity of samples
#'                         of informed labels and all other.
.sits_distances_sample <- function(distances, frac) {
    # compute sampling
    reference <- NULL # to avoid setting global variable
    result <- distances[, .SD[sample(.N, round(frac * .N))], by = reference]

    return(result)
}
