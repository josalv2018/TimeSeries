% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sits_plot.R
\name{.sits_plot_ggplot_together}
\alias{.sits_plot_ggplot_together}
\title{Plot many time series together using ggplot}
\usage{
.sits_plot_ggplot_together(melted, means, plot_title)
}
\arguments{
\item{melted}{tibble with the time series (already melted).}

\item{means}{means and std deviations of the time series.}

\item{plot_title}{title for the plot.}
}
\value{
A plot object produced by the ggplot2 package
                      each time series associated to one band
                      and one label.
}
\description{
Plots a set of  time series together.
}
\keyword{internal}
