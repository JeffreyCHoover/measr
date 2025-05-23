% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/utils.R
\name{get_parameters}
\alias{get_parameters}
\title{Get a list of possible parameters}
\usage{
get_parameters(
  qmatrix,
  item_id = NULL,
  rename_att = FALSE,
  rename_item = FALSE,
  type = c("lcdm", "dina", "dino", "crum"),
  attribute_structure = c("unconstrained", "independent")
)
}
\arguments{
\item{qmatrix}{The Q-matrix. A data frame with 1 row per item and 1 column
per attribute. All cells should be either 0 (item does not measure the
attribute) or 1 (item does measure the attribute).}

\item{item_id}{Optional. Variable name of a column in \code{qmatrix} that contains
item identifiers. \code{NULL} (the default) indicates that no identifiers are
present in the Q-matrix.}

\item{rename_att}{Should attribute names from the \code{qmatrix} be replaced with
generic, but consistent names (e.g., "att1", "att2", "att3").}

\item{rename_item}{Should item names from the \code{qmatrix} be replaced with
generic, but consistent names (e.g., 1, 2, 3).}

\item{type}{Type of \acronym{DCM} to estimate. Must be one of
lcdm, dina, dino, or crum.}

\item{attribute_structure}{Structural model specification. Must be one of
unconstrained, or independent.
\code{unconstrained} makes no assumptions about the relationships between
attributes, whereas \code{independent} assumes that proficiency statuses on
attributes are independent of each other.}
}
\value{
A \link[tibble:tibble-package]{tibble} with one row per parameter.
}
\description{
When specifying prior distributions, it is often useful to see which
parameters are included in a given model. Using the Q-matrix and type of
diagnostic model to estimated, we can create a list of all included
parameters for which a prior can be specified.
}
\examples{
get_parameters(ecpe_qmatrix, item_id = "item_id", type = "lcdm")

get_parameters(ecpe_qmatrix, item_id = "item_id", type = "lcdm",
               rename_att = TRUE)
}
