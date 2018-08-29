% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sits_plot.R
\name{.sits_plot_together}
\alias{.sits_plot_together}
\title{Plot a set of time series for the same spatio-temporal reference}
\usage{
.sits_plot_together(data.tb, colors)
}
\arguments{
\item{data.tb}{tibble - a SITS table with the list of time series to be plotted}

\item{colors}{the color pallete to be used (default is "Set1")}
}
\value{
data.tb    tibble - the input SITS table (useful for chaining functions)
}
\description{
plots all time series for the same label together
This function is useful to find out the spread of the values of the time serie
for a given label
}