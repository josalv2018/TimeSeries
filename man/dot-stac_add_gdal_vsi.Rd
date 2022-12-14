% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sits_stac.R
\name{.stac_add_gdal_vsi}
\alias{.stac_add_gdal_vsi}
\alias{.stac_add_gdal_fs}
\title{Add href locator to gdal file}
\usage{
.stac_add_gdal_fs(href)
}
\arguments{
\item{href}{Link to the asset object.}
}
\value{
a \code{character} with the signed href.
}
\description{
Currently, HTTP, S3 (AWS), and google storage (gs)
 links are supported.
}
\keyword{internal}
