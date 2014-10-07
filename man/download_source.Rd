\name{download_source}
\alias{download_source}
\title{Download a source package from CRAN}
\usage{
download_source(pkg)
}
\arguments{
\item{pkg}{the package name}
}
\description{
This function tries to download a source package from CRAN for at most 5
times, and if the RStudio mirror fails, the main CRAN site will be used.
}
