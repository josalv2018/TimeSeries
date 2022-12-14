% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sits_classify_ts.R
\name{.sits_tibble_prediction}
\alias{.sits_tibble_prediction}
\title{Create an empty tibble to store the results of predictions}
\usage{
.sits_tibble_prediction(data, class_info, prediction)
}
\arguments{
\item{data}{Tibble with the input data.}

\item{class_info}{Tibble with the information on classification.}

\item{prediction}{Matrix with the result of the classification
(one class per column and one row per interval).}
}
\value{
Tibble storing the predictions.
}
\description{
Create a tibble to store the results of predictions.
}
\author{
Gilberto Camara, \email{gilberto.camara@inpe.br}

Rolf Simoes, \email{rolf.simoes@inpe.br}
}
\keyword{internal}
