\name{pkg_install}
\alias{pkg_install}
\title{Install a package from Github using \pkg{devtools}}
\usage{
pkg_install(src)
}
\arguments{
\item{src}{passed to \code{\link[devtools]{install_github}()}}
}
\description{
This function will try at most 5 times to install a package from Github, and
the reason to retry is that sometimes downloading from Github might fail.
}
