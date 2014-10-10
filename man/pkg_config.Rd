\docType{data}
\name{pkg_config}
\alias{pkg_config}
\title{The configuration for packages}
\format{A character matrix.}
\description{
The file \file{config/PACKAGES} in this package stores some configuration
information for packages of which the reverse dependencies are to be checked,
such as the package name, the Github repo, and the number of jobs in a build
matrix, etc.
}
\examples{
str(pkg_config)
}
\keyword{datasets}
