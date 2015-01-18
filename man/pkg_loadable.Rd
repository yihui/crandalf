% Please edit documentation in R/crandalf.R
\name{pkg_loadable}
\alias{pkg_loadable}
\title{Whether a package is loadable}
\usage{
pkg_loadable(p)
}
\arguments{
\item{p}{the package name (must be of length 1)}
}
\value{
\code{TRUE} or \code{FALSE}.
}
\description{
This function is like \code{\link{require}()}, but it does not load the
package in the current R session. Instead, it launches a new R session to
test if a package is loadable. The reason for that is it is not trivial to
remove all the side effects brought by \code{\link{library}()}, such as
DLL's. Instead of cleaning up everything, we just use a new R session to test
if a package is loadable.
}
