% Please edit documentation in R/crandalf.R
\name{split_pkgs}
\alias{split_pkgs}
\title{Given a character string, split it by white spaces or a custom string}
\usage{
split_pkgs(string, split = "\\\\s+")
}
\arguments{
\item{string}{a charactor string of length 1}

\item{split}{a character string as the separator to split the string}
}
\value{
A character vector
}
\description{
This package often reads R package names as a character string from
environment variables or YAML, and we need to split the character string into
a character vector.
}
