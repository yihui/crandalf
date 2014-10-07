\docType{data}
\name{recipes}
\alias{pkg_db}
\alias{recipes}
\title{Datasets for the package info on CRAN and R package recipes in \pkg{crandalf}}
\format{Data frames.}
\description{
The data frame \code{pkg_db} is read from
\url{http://cran.rstudio.com/web/packages/packages.rds}, and \code{recipes}
is from the file \file{RECIPES} under the \file{config} directory of the
\pkg{crandalf} package.
}
\examples{
str(recipes)
str(pkg_db)
}
\keyword{datasets}
