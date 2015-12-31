% Please edit documentation in R/crandalf.R
\name{rev_check}
\alias{rev_check}
\title{Check the reversion dependencies of an R package on Github}
\usage{
rev_check(repo = "yihui/knitr", check_args = "--no-manual", 
    reverse = list(which = "all"), xvfb = TRUE, Ncpus = parallel::detectCores())
}
\arguments{
\item{repo}{the repository name of the form \samp{user/repo}}

\item{check_args}{a character vector with arguments to be passed to
    \command{R CMD check}, or a list of length two of such character
    vectors to be used for checking packages and reverse dependencies,
    respectively.}

\item{reverse}{a list with names partially matching \code{"repos"},
    \code{"which"}, or \code{"recursive"}, giving the repositories to
    use for locating reverse dependencies (default:
    \code{getOption("repos")}), the types of reverse dependencies
    (default: \code{c("Depends", "Imports", "LinkingTo")}, with
    shorthands \code{"most"} and \code{"all"} as for
    \code{\link{package_dependencies}}), and indicating whether to also
    check reverse dependencies of reverse dependencies and so on
    (default: \code{FALSE}), or \code{NULL} (default), in which case no
    reverse dependencies are checked.}

\item{xvfb}{a logical indicating whether to perform checking inside a
    virtual framebuffer X server (Unix only), or a character vector of
    Xvfb options for doing so.}

\item{Ncpus}{the number of parallel processes to use for parallel
    installation and checking.}
}
\description{
This function calls \code{tools::\link[tools]{check_packages_in_dir}()} to
check the reverse dependencies of an R package hosted on Github.
}
