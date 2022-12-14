% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sits_source_api.R, R/sits_source_api_stac.R
\name{source_cube}
\alias{source_cube}
\alias{.source_cube}
\alias{.source_item_get_date}
\alias{.source_item_get_hrefs}
\alias{.source_item_get_cloud_cover}
\alias{.source_item_get_bands}
\alias{.source_items_new}
\alias{.source_items_bands_select}
\alias{.source_items_fid}
\alias{.source_items_file_info}
\alias{.source_items_tile}
\alias{.source_collection_sensor}
\alias{.source_collection_satellite}
\alias{.source_tile_get_bbox}
\alias{.source_items_cube}
\alias{.source_tile_get_bbox.stac_cube}
\title{Functions to instantiate a new cube from a source}
\usage{
.source_cube(source, collection, ...)

.source_item_get_date(source, item, ..., collection = NULL)

.source_item_get_hrefs(source, item, ..., collection = NULL)

.source_item_get_cloud_cover(source, ..., item, collection = NULL)

.source_item_get_bands(source, item, ..., collection = NULL)

.source_items_new(source, ..., collection = NULL)

.source_items_bands_select(source, items, bands, ..., collection = NULL)

.source_items_fid(source, items, ..., collection = NULL)

.source_items_file_info(source, items, ..., collection = NULL)

.source_items_tile(source, items, ..., collection = NULL)

.source_collection_sensor(source, collection)

.source_collection_satellite(source, collection)

.source_tile_get_bbox(source, ..., file_info, collection = NULL)

.source_items_cube(source, collection, items, ...)

\method{.source_tile_get_bbox}{stac_cube}(source, file_info, ..., collection = NULL)
}
\arguments{
\item{source}{Data source.}

\item{collection}{Image collection.}

\item{...}{Additional parameters.}

\item{items}{Images that compose a cube.}

\item{bands}{Bands to be selected in the collection.}

\item{file_info}{A \code{tibble} that organizes the metadata about each
file in the tile: date, band, resolution, and path (or URL).}

\item{asset}{A \code{raster} object to retrieve information.}

\item{data_dir}{Directory where local files are stored}
}
\value{
The values returned by each function are described as follows.

\code{.source_cube()} returns a sits \code{tibble} with cube
metadata.

\code{.source_item_get_date()} returns a \code{Date} value.

\code{.source_item_get_hrefs()} returns a \code{character} vector
containing paths to each image band of an item.

\code{.source_item_get_cloud_cover()} returns a \code{numeric} vector
containing the percentage of cloud cover to each image band of an item.

\code{.source_item_get_bands()} returns a \code{character} vector
containing bands name of an item.

\code{.source_items_new()} returns any object referring the images
of a sits cube.

\code{.source_items_bands_select()} returns the same object as
\code{items} with selected bands.

\code{.source_items_fid()} returns a \code{character} vector.

\code{.source_items_file_info()} returns a \code{tibble} containing
sits cube.

\code{.source_items_tile()} returns a \code{list} of
items.

\code{.source_items_get_sensor()} returns a \code{character} value.

\code{.source_items_get_satellite()} returns a \code{character}
value.

\code{.source_tile_get_bbox()} returns a \code{numeric}
vector with 4 elements (xmin, ymin, xmax, ymax).

\code{.source_items_cube()} returns a \code{tibble} containing a sits
cube tile (one row).

\code{.source_tile_get_bbox()} returns a \code{list}
vector with 4 elements (xmin, ymin, xmax, ymax).
}
\description{
These functions provide an API to instantiate a new cube object and
access/retrieve information from services or local files to fill
cube attributes.

A cube is formed by images (items) organized in tiles. To create a sits
cube object (a \code{tibble}), a set of functions are called in order
to retrieve metadata.

\code{.source_cube()} is called to start the cube creation
from a source.

\code{.source_item_get_date()} retrieves the date of an item
(a set of images from different bands that forms a scene).

\code{.source_item_get_hrefs()} retrieves the paths or URLs of
each file bands of an item.

\code{.source_item_get_cloud_cover()} retrieves the percentage
of cloud cover of an image.

\code{.source_item_get_bands()} retrieves the bands present
in an item.

\code{.source_items_new()} this function is called to create
an items object. In case of Web services, this function is responsible for
making the Web requests to the server.

\code{.source_items_fid()} retrieves the feature id of
all items.

\code{.source_items_file_info()} creates the \code{fileinfo}
specification from items object.

\code{.source_items_tile()} organizes items by tiles
and arrange items in each tile by date.

\code{.source_items_get_sensor()} retrieves the sensor from
items object.

\code{.source_items_get_satellite()} retrieves the satellite
name (platform) from items object.

\code{.source_tile_get_bbox()} retrieves the bounding
box from items of a tile.

\code{.source_items_cube()} is called to create a data cubes
tile, that is, a row in sits data cube.

\code{.source_tile_get_bbox()} retrieves the bounding
box from items of a tile.
}
\keyword{internal}
