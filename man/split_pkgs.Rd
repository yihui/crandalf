\name{split_pkgs}
\alias{split_pkgs}
\title{Given a character string, split it by white spaces}
\usage{
split_pkgs(string)
}
\arguments{
\item{string}{a charactor string of length 1}
}
\value{
A character vector
}
\description{
This package often reads R package names as a character string from
environment variables or YAML, and we need to split the character string into
a character vector.
}
