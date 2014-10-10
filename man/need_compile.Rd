\name{need_compile}
\alias{need_compile}
\title{Whether a package needs to be compiled}
\usage{
need_compile(p)
}
\value{
\code{TRUE} or \code{FALSE}.
}
\description{
This function uses the column \code{NeedsCompilation} of the package database
on CRAN to check if a package needes to be compiled. When it contains
C/C++/Fortran code, it has to be compiled. For such packages, we might need
to install additional system dependencies (e.g. \pkg{libxml2-dev} for the
\pkg{XML} package).
}
