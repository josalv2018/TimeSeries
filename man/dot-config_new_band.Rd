% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sits_config.R
\name{.config_new_band}
\alias{.config_new_band}
\title{Include a new band in the configuration}
\usage{
.config_new_band(
  missing_value,
  minimum_value,
  maximum_value,
  scale_factor,
  offset_value,
  band_name,
  resolution,
  ...
)
}
\arguments{
\item{missing_value}{missing value}

\item{minimum_value}{minimum value}

\item{maximum_value}{maximum_value}

\item{scale_factor}{scale_factor associated with the data}

\item{offset_value}{offset_value for the band}

\item{band_name}{name of the band}

\item{resolution}{spatial resolution (in meters)}

\item{...}{other relevant parameters}
}
\value{
list with the configuration associated to the new band
}
\description{
creates a description associated to a new band
}
\keyword{internal}
