% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sits_machine_learning.R
\name{.sits_ml_normalize_data}
\alias{.sits_ml_normalize_data}
\title{Normalize the time series in the given sits_tibble}
\usage{
.sits_ml_normalize_data(data, stats)
}
\arguments{
\item{data}{Time series.}

\item{stats}{Statistics for normalization.}
}
\value{
Normalized time series.
}
\description{
This function normalizes the time series using the mean and
standard deviation of all the time series.
}
\author{
Alber Sanchez, \email{alber.ipia@inpe.br}
}
\keyword{internal}
