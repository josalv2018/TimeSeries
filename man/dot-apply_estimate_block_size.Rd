% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sits_apply.R
\name{.apply_estimate_block_size}
\alias{.apply_estimate_block_size}
\title{Estimate the number of blocks}
\usage{
.apply_estimate_block_size(cube, multicores, memsize)
}
\arguments{
\item{cube}{input data cube}

\item{multicores}{number of processes to split up the data}

\item{memsize}{maximum overall memory size (in GB)}
}
\value{
returns a list with following information:
            - multicores theoretical upper bound;
            - block x_size (horizontal) and y_size (vertical)
}
\description{
Estimate the number of blocks
}
\keyword{internal}
