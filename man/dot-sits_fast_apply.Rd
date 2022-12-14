% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sits_tibble.R
\name{.sits_fast_apply}
\alias{.sits_fast_apply}
\title{Apply a function to one band of a time series}
\usage{
.sits_fast_apply(data, col, fn, ...)
}
\arguments{
\item{data}{Tibble.}

\item{col}{Column where function should be applied}

\item{fn}{Function to be applied.}
}
\value{
Tibble where function has been applied.
}
\description{
Apply a function to one band of a time series
}
\author{
Rolf Simoes, \email{rolf.simoes@inpe.br}
}
\keyword{internal}
