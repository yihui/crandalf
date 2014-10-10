\name{fix_R2}
\alias{fix_R2}
\title{Re-install packages that were built with R < 3.0.0}
\usage{
fix_R2(lib = .libPaths()[-1])
}
\arguments{
\item{lib}{the library locations}
}
\description{
Some Debian R packages were built with R 2.x, and such packages are not
loadable in R 3.x, so we need to find and reinstall them under R 3.x.
}
