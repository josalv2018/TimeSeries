#' @title Sample a percentage of a time series
#' @name sits_sample
#' @author Rolf Simoes, \email{rolf.simoes@@inpe.br}
#'
#' @description Takes a sits tibble with different labels and
#'              returns a new tibble. For a given field as a group criterion,
#'              this new tibble contains a given number or percentage
#'              of the total number of samples per group.
#'              Parameter n: number of random samples.
#'              Parameter frac: a fraction of random samples.
#'              If n is greater than the number of samples for a given label,
#'              that label will be sampled with replacement. Also,
#'              if frac > 1 , all sampling will be done with replacement.
#'
#' @param  data       Input sits tibble.
#' @param  n          Number of samples to pick from each group of data.
#' @param  frac       Percentage of samples to pick from each group of data.
#' @param  oversample Oversample classes with small number of samples?
#' @return            A sits tibble with a fixed quantity of samples.
#' @examples
#' # Retrieve a set of time series with 2 classes
#' data(cerrado_2classes)
#' # Print the labels of the resulting tibble
#' sits_labels(cerrado_2classes)
#' # Samples the data set
#' data <- sits_sample(cerrado_2classes, n = 10)
#' # Print the labels of the resulting tibble
#' sits_labels(data)
#' @export
sits_sample <- function(data,
                        n = NULL,
                        frac = NULL,
                        oversample = TRUE) {

    # set caller to show in errors
    .check_set_caller("sits_sample")

    # verify if data is valid
    .sits_tibble_test(data)

    # verify if either n or frac is informed
    .check_that(
        x = !(purrr::is_null(n) & purrr::is_null(frac)),
        local_msg = "neither 'n' or 'frac' parameters were informed",
        msg = "invalid sample parameters"
    )

    groups <- by(data, data[["label"]], list)

    result_lst <- purrr::map(groups, function(class_samples) {

        if (!purrr::is_null(n)) {
            if (n > nrow(class_samples) && !oversample) {
                # should imbalanced class be oversampled?
                nrow <- nrow(class_samples)
            } else {
                nrow <- n
            }
            result <- dplyr::slice_sample(
                class_samples,
                n = nrow,
                replace = oversample
            )
        } else {
            result <- dplyr::slice_sample(
                class_samples,
                prop = frac,
                replace = oversample
            )
        }
        return(result)
    })

    result <- dplyr::bind_rows(result_lst)

    return(result)
}
#' @title Reduce imbalance in a set of samples
#' @name sits_reduce_imbalance
#' @author Gilberto Camara, \email{gilberto.camara@@inpe.br}
#'
#' @description Takes a sits tibble with different labels and
#'              returns a new tibble. Deals with class imbalance
#'              using the synthetic minority oversampling technique (SMOTE)
#'              for oversampling.
#'              Undersampling is done using the SOM methods available in
#'              the sits package.
#'
#'
#' @references
#' Oversampling uses the "oversample_smote" function
#' implemented in the "scutr" package developed by Keenan Ganz and
#' avaliable in https://github.com/s-kganz/scutr.
#'
#' The reference paper on SMOTE is
#' N. V. Chawla, K. W. Bowyer, L. O.Hall, W. P. Kegelmeyer,
#' “SMOTE: synthetic minority over-sampling technique,”
#' Journal of artificial intelligence research, 321-357, 2002.
#'
#' Undersampling uses the SOM map developed by Lorena Santos and co-workers
#' and used in the sits_som_map() function.
#' The SOM map technique is described in the paper:
#' Lorena Santos, Karine Ferreira, Gilberto Camara, Michelle Picoli,
#' Rolf Simoes, “Quality control and class noise reduction of satellite
#' image time series”. ISPRS Journal of Photogrammetry and Remote Sensing,
#' vol. 177, pp 75-88, 2021. https://doi.org/10.1016/j.isprsjprs.2021.04.014.
#'
#'
#' @param  samples              Sample set to rebalance
#' @param  n_samples_over       Number of samples to oversample
#'                              for classes with samples less than this number
#'                              (use n_samples_over = NULL to avoid
#'                              oversampling).
#' @param  n_samples_under      Number of samples to undersample
#'                              for classes with samples more than this number
#'                              (use n_samples_over = NULL to avoid
#'                              oversampling).
#'
#' @return A sits tibble with a fixed quantity of samples.
#' @examples
#' # Retrieve a set of time series with 2 classes
#' data(samples_modis_4bands)
#' # Print the labels of the resulting tibble
#' sits_labels_summary(samples_modis_4bands)
#' # Samples the data set
#' new_data <- sits_reduce_imbalance(samples_modis_4bands)
#' # Print the labels of the resulting tibble
#' sits_labels_summary(new_data)
#' @export
sits_reduce_imbalance <- function(
    samples,
    n_samples_over   = 200,
    n_samples_under  = 400) {

    # verifies if scutr package is installed
    if (!requireNamespace("scutr", quietly = TRUE)) {
        stop("Please install package scutr", call. = FALSE)
    }

    # set caller to show in errors
    .check_set_caller("sits_reduce_imbalance")
    # check if number of required samples are correctly entered
    if (!purrr::is_null(n_samples_over) || !purrr::is_null(n_samples_under)) {
        .check_that(
            x = n_samples_under >= n_samples_over,
            msg = paste0("number of samples to undersample for large classes",
                         " should be higher or equal to number of samples to ",
                         "oversample for small classes"
            )
        )
    }
    bands <- sits_bands(samples)
    labels <- sits_labels(samples)
    summary <- sits_labels_summary(samples)

    # params of output tibble
    lat <- 0.0
    long <- 0.0
    start_date <- samples$start_date[[1]]
    end_date   <- samples$end_date[[1]]
    cube <- samples$cube[[1]]
    timeline <- sits_timeline(samples)
    n_times <- length(timeline)

    if (!purrr::is_null(n_samples_under)) {
        classes_under <- samples %>%
            sits_labels_summary() %>%
            dplyr::filter(.data[["count"]] >= n_samples_under) %>%
            dplyr::pull(.data[["label"]])
    } else
        classes_under <- vector()

    if (!purrr::is_null(n_samples_over)) {
        classes_over <- samples %>%
            sits_labels_summary() %>%
            dplyr::filter(.data[["count"]] <= n_samples_over) %>%
            dplyr::pull(.data[["label"]])
    } else
        classes_over <- vector()

    classes_ok <- labels[!(labels %in% classes_under | labels %in% classes_over)]
    new_samples <- .sits_tibble()

    if (length(classes_under) > 0) {
        samples_under_new <- purrr::map_dfr(classes_under, function(cls){
            samples_cls <- dplyr::filter(samples, .data[["label"]] == cls)
            grid_dim <-  ceiling(sqrt(n_samples_under/4))

            som_map <- sits_som_map(samples_cls,
                                    grid_xdim = grid_dim,
                                    grid_ydim = grid_dim,
                                    rlen = 50
            )
            samples_under <- som_map$data %>%
                dplyr::group_by(.data[["id_neuron"]]) %>%
                dplyr::slice_sample(n = 4, replace = TRUE) %>%
                dplyr::ungroup()
            return(samples_under)
        })
        new_samples <- dplyr::bind_rows(new_samples,
                                        samples_under_new
        )
    }

    if (length(classes_over) > 0) {
        samples_over_new <- purrr::map_dfr(classes_over, function(cls){
            samples_bands <- purrr::map(bands, function(band){
                # selection of band
                dist_band <- samples %>%
                    sits_select(bands = band) %>%
                    dplyr::filter(.data[["label"]] == cls) %>%
                    .sits_distances() %>%
                    as.data.frame() %>%
                    .[-1]
                # oversampling of band for the class
                dist_over <- scutr::oversample_smote(
                    data = dist_band,
                    cls = cls,
                    cls_col = "reference",
                    m = n_samples_over
                )
                # put the oversampled data into a samples tibble
                samples_band <- slider::slide_dfr(dist_over, function(row){
                    time_series = tibble::tibble(
                        Index = as.Date(timeline),
                        values = unname(as.numeric(row[-1]))
                    )
                    colnames(time_series) <- c("Index", band)
                    tibble::tibble(
                        longitude = long,
                        latitude  = lat,
                        start_date = as.Date(start_date),
                        end_date = as.Date(end_date),
                        label = row[["reference"]],
                        cube = cube,
                        time_series = list(time_series)
                    )
                })
                class(samples_band) <- c("sits", class(samples_band))
                return(samples_band)
            })
            tb_class_new <- samples_bands[[1]]
            for (i in seq_along(samples_bands)[-1])
                tb_class_new <- sits_merge(tb_class_new, samples_bands[[i]])
            return(tb_class_new)
        })
        new_samples <- dplyr::bind_rows(new_samples,
                                        samples_over_new
        )
    }

    if (length(classes_ok) > 0) {
        samples_classes_ok <- dplyr::filter(samples,
                                            .data[["label"]] %in% classes_ok)
        new_samples <- dplyr::bind_rows(new_samples, samples_classes_ok)
    }
    return(new_samples)
}