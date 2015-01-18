% Please edit documentation in R/crandalf.R
\name{install_deps}
\alias{install_deps}
\title{Install a package and its dependencies}
\usage{
install_deps(p)
}
\arguments{
\item{p}{the package name}
}
\description{
If a package is not loadable, install its system dependencies, then install
it from source. If the package cannot be found on CRAN, BioConductor will be
tried.
}
