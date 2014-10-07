\name{apt_get}
\alias{apt_get}
\title{A wrapper for \command{apt-get} on Ubuntu/Debian}
\usage{
apt_get(pkgs, command = "install", R = TRUE)
}
\arguments{
\item{pkgs}{a character vector of packages}

\item{command}{the command for \command{apt-get}}

\item{R}{whether to treat \code{pkgs} as R packages}
}
\description{
This function installs or builds dependencies for R packages if the relevant
Debian packages exist.
}
