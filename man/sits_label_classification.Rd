% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sits_classification.R
\name{sits_label_classification}
\alias{sits_label_classification}
\title{Post-process a classified data raster probs to obtain a labelled image}
\usage{
sits_label_classification(cube, smoothing = "none", window = matrix(1,
  nrow = 3, ncol = 3, byrow = TRUE), variance = 20, output_dir = "./")
}
\arguments{
\item{cube}{Classified image data cube.}

\item{smoothing}{(optional) smoothing method to be applied ("none", "bayesian", "majority")}

\item{window}{A matrix with the neighborhood window to compute bayesian smooth.
The central element index (i, j) is given by
i = floor(nrows(window)/2)+1 and j = floor(ncols(window)/2)+1.
Elements '0' are excluded from window.}

\item{variance}{Estimated variance of logit of class_probs (Bayesian smoothing parameter).}

\item{output_dir}{Output directory where to out the file}
}
\value{
A tibble with metadata about the output RasterLayer objects.
}
\description{
Takes a set of classified raster layers with probabilities, whose metadata is
             described by tibble (created by \code{\link[sits]{sits_cube}}),
             and label them, with an optional bayesian smoothing process.
}
\examples{
\donttest{
# Retrieve the samples for Mato Grosso
# Install the inSitu library
# devtools::install_github("e-sensing/inSitu")
# library(inSitu)

samples <- inSitu::br_mt_1_8K_9classes_6bands

# select the bands "ndvi", "evi"

samples_2bands <- sits_select_bands(samples, ndvi, evi)

#select a random forest model
rfor_model <- sits_train(samples_2bands, ml_method = sits_rfor())

# Classify a raster file with 23 instances for one year
# select the bands "ndvi", "evi" from the "inSitu" package
evi_file <- system.file("extdata/Sinop", "Sinop_evi_2014.tif", package = "inSitu")
ndvi_file <- system.file("extdata/Sinop", "Sinop_ndvi_2014.tif", package = "inSitu")

files <- c(ndvi_file, evi_file)

# define the timeline for the files
time_file <- system.file("extdata/Sinop", "timeline_2014.txt", package = "inSitu")
timeline_2013_2014 <- scan(time_file, character())

# create a data cube based on the information about the files
raster.tb <- sits_cube(name = "Sinop", timeline = timeline_2013_2014,
                       bands = c("ndvi", "evi"), files = files)

# classify the raster image and generate a probability file
raster_probs.tb <- sits_classify(raster.tb, ml_model = rfor_model, memsize = 4, multicores = 2)

# label the probability (no smoothing applied by default)
raster_class.tb <- sits_label_classification(raster_probs.tb)

# plot the raster image
sits_plot_raster(raster_class.tb, time = 1, title = "Sinop-2013-2014")

# smooth the result with a bayesian filter
raster_class_bayes.tb <- sits_label_classification(raster_probs.tb, smoothing = "bayesian")

# plot the smoothened image
sits_plot_raster(raster_class_bayes.tb, time = 1, title = "Sinop-smooth")
}
}
\author{
Rolf Simoes, \email{rolf.simoes@inpe.br}
}