% Please edit documentation in R/crandalf.R
\name{travis_fold}
\alias{travis_end}
\alias{travis_fold}
\alias{travis_start}
\title{Fold Travis logs into sections}
\usage{
travis_fold(job, code, ...)

travis_start(job, msg = paste("Running", job))

travis_end(job)
}
\arguments{
\item{job}{a character string as the section tag (job name)}

\item{code}{an R expression to run within a section}

\item{...}{passed to \code{travis_start()}}

\item{msg}{a character vector of messages to write for the log section}
}
\description{
Travis supports folding build logs to make navigation easier in the log
viewer. The function \code{travis_fold()} implemented this feature in R.
Additionally, the build time for each section will be written after the
section tag. You can use either \code{travis_start()} and \code{travis_end()}
separately (put R code in between), or a single \code{travis_fold()} call
when the R code is short enough.
}
\references{
\url{https://github.com/travis-ci/travis-build/blob/master/lib/travis/build/script/templates/header.sh}
}
