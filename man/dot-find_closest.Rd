% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sits_geo_dist.R
\name{.find_closest}
\alias{.find_closest}
\title{Find the closest points.}
\usage{
.find_closest(x, y = x)
}
\arguments{
\item{x}{An `sf` object (points).}

\item{y}{An `sf` object (points).}
}
\value{
A data.frame with the columns from (row number in a), b
(row number in b), and distance (in meters).
}
\description{
For each point in x, find the closest point in y (and their distance).
}
\author{
Alber Sanchez, \email{alber.ipia@inpe.br}
}
\keyword{internal}
