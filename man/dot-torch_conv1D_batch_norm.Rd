% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sits_torch_conv1d.R
\name{.torch_conv1D_batch_norm}
\alias{.torch_conv1D_batch_norm}
\title{Torch module for Conv1D + Batch Norm}
\usage{
.torch_conv1D_batch_norm(input_dim, output_dim, kernel_size, padding = 0)
}
\arguments{
\item{input_dim}{Input dimension of neural net.}

\item{output_dim}{Output dimension of neural net.}

\item{kernel_size}{Size of 1D convolutional kernel.}

\item{padding}{Padding added to both sides of the input.}
}
\value{
A conv1D tensor block.
}
\description{
Defines a torch conv1d module composed of:
(a) 1d convolution; (b) batch normalization.
}
\author{
Charlotte Pelletier, \email{charlotte.pelletier@univ-ubs.fr}

Gilberto Camara, \email{gilberto.camara@inpe.br}

Rolf Simoes, \email{rolf.simoes@inpe.br}

Felipe Souza, \email{lipecaso@gmail.com}
}
\keyword{internal}
