% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sits_validate.R
\name{sits_validate}
\alias{sits_validate}
\title{Validate time series samples}
\usage{
sits_validate(
  samples,
  samples_validation = NULL,
  validation_split = 0.2,
  ml_method = sits_rfor()
)
}
\arguments{
\item{samples}{Time series set to be validated.}

\item{samples_validation}{Time series set used for validation.}

\item{validation_split}{Percent of original time series set to be used
for validation (if samples_validation is NULL)}

\item{ml_method}{Machine learning method.}
}
\value{
A \code{caret::confusionMatrix} object to be used for
        validation assessment.
}
\description{
One round of cross-validation involves partitioning a sample of data
into complementary subsets, performing the analysis on one subset
(called the training set), and validating the analysis on the other subset
(called the validation set or testing set).

The function takes two arguments: a set of time series
with a machine learning model and another set with validation samples.
If the validation sample set is not provided,
The sample dataset is split into two parts, as defined by the parameter
validation_split. The accuracy is determined by the result of
the validation test set.

This function returns the confusion matrix, and Kappa values.
}
\examples{
if (sits_run_examples()){
   conf_matrix <- sits_validate(cerrado_2classes)
}
}
\author{
Rolf Simoes, \email{rolf.simoes@inpe.br}

Gilberto Camara, \email{gilberto.camara@inpe.br}
}
