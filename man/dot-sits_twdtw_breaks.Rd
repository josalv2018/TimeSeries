% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sits_twdtw.R
\name{.sits_twdtw_breaks}
\alias{.sits_twdtw_breaks}
\title{Classify a sits tibble using the matches found by the TWDTW methods}
\usage{
.sits_twdtw_breaks(
  matches,
  samples,
  start_date = NULL,
  end_date = NULL,
  interval = "12 month",
  overlap = 0.5
)
}
\arguments{
\item{matches}{A dtwSat S4 object with the matches
produced by the sits_TWDTW_matches function.}

\item{samples}{Input for the TWDTW matching function.}

\item{start_date}{The start date of the classification period.}

\item{end_date}{The end date of the classification period.}

\item{interval}{The period between two classifications.}

\item{overlap}{Minimum overlap between one match and
the interval of classification.}
}
\value{
A sits tibble with the information on matches for the data.
}
\description{
Returns a sits tibble with the results of the TWDTW classifier.
The TWDTW classifier uses the result of the sits_TWDTW_matches function to
find the best alignments of these matches in intervals chosen by the user
}
\references{
Maus V, Camara G, Cartaxo R, Sanchez A, Ramos FM, de Queiroz GR (2016).
A Time-Weighted Dynamic Time Warping Method for Land-Use and Land-Cover
Mapping. IEEE Journal of Selected Topics in Applied Earth Observations
and Remote Sensing, 9(8):3729-3739, August 2016.
ISSN 1939-1404. doi:10.1109/JSTARS.2016.2517118.
}
\author{
Victor Maus, \email{vwmaus1@gmail.com}

Gilberto Camara, \email{gilberto.camara@inpe.br}
}
\keyword{internal}
