% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sits_source_api.R
\name{source_collection}
\alias{source_collection}
\alias{.source_collections}
\alias{.source_collection_access_test}
\alias{.source_collection_access_vars_set}
\alias{.source_collection_check}
\alias{.source_collection_metadata_search}
\alias{.source_collection_name}
\alias{.source_collection_open_data}
\alias{.source_collection_open_data_token}
\alias{.source_collection_token_check}
\alias{.source_collection_tile_check}
\title{Source collection functions}
\usage{
.source_collections(source, ...)

.source_collection_access_test(source, collection, ...)

.source_collection_access_vars_set(source, collection)

.source_collection_check(source, collection)

.source_collection_metadata_search(source, collection)

.source_collection_name(source, collection)

.source_collection_open_data(source, collection)

.source_collection_open_data_token(source, collection)

.source_collection_token_check(source, collection)

.source_collection_tile_check(source, collection, tiles)
}
\arguments{
\item{source}{Data source.}

\item{collection}{Image collection.}

\item{tiles}{Tile names}

\item{start_date}{Start date.}

\item{end_date}{End date.}
}
\value{
The values returned by each function are described as follows.

\code{.source_collections()} returns a \code{character} vector
with all collection names of a given source.

\code{.source_collection_access_vars_set } returns \code{NULL} if
no error occurs.

\code{.source_collection_check()} returns \code{NULL} if
no error occurs.

\code{.source_collection_metadata_search()} returns a character
value with the metadata search strategy.

\code{.source_collection_name()} returns a \code{character}.

\code{.source_collection_open_data()} returns a \code{logical}.

\code{.source_collection_open_data_token()} returns a \code{logical}.

\code{.source_collection_token_check()} returns \code{NULL} if
no error occurs.

\code{.source_collection_tile_check()} returns \code{NULL} if
no error occurs.
}
\description{
These functions provide an API to handle/retrieve data from source's
collections.

\code{.source_collections()} lists all collections of a source.

\code{.source_collection_access_vars_set} sets
\code{access_vars} environment variables.

\code{.source_collection_check()} checks if a collection
is from a source.

\code{.source_collection_metadata_search()} retrieves the
metadata search strategy for a given source and collection.

\code{.source_collection_name()} returns the name of a
collection in its original source.

\code{.source_collection_open_data()} informs if a
collection is open data or not.

\code{.source_collection_open_data_token()} informs if a
collection requires a token to access.

\code{.source_collection_token_check()} checks if a collection
needs environmental variables.

\code{.source_collection_tile_check()} checks if a collection
requires tiles to be defined
}
\keyword{internal}
