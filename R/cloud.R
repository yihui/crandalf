install.packages('remotes')
remotes::install_github(c('r-lib/revdepcheck', commandArgs(TRUE)))
setwd('package')

revdepcheck::cloud_check()
revdepcheck::cloud_status()

if (length(res <- revdepcheck::cloud_broken())) {
  revdepcheck::cloud_summary()
  revdepcheck::cloud_report()
  stop('Package(s) broken: ', paste(res, collapse = ' '))
}
