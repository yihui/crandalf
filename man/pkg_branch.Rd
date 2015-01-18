% Please edit documentation in R/crandalf.R
\name{pkg_branch}
\alias{pkg_branch}
\alias{pkg_commit}
\title{Get the package name of which the reverse dependencies are to be checked}
\usage{
pkg_branch()

pkg_commit()
}
\value{
The package name, or \code{NULL} if failed to find one.
}
\description{
For \code{pkg_branch()}, the package name is obtained from the environment
variable \code{TRAVIS_BRANCH}; if it is empty, the current GIT branch name is
used, and the branch name must be of the form \code{pkg/name}, i.e. the
package name with the \code{pkg/} prefix.

For \code{pkg_commit()}, the package named is detected from the
  current commit message, which should contain a character string of the form
  \code{[crandalf pkg@user/repo]}, where \code{user/repo} is a repository on
  Github.
}
