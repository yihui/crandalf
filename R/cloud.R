update.packages(ask = FALSE, checkBuilt = TRUE)
if (!requireNamespace('remotes', quietly = TRUE)) install.packages('remotes')
remotes::install_github(c('r-lib/revdepcheck', commandArgs(TRUE)))
setwd('package')

revdepcheck::cloud_check(r_version = getRversion())
revdepcheck::cloud_status(update_interval = 60)

if (length(res <- revdepcheck::cloud_broken())) {
  revdepcheck::cloud_summary()
  revdepcheck::cloud_report()
  stop('Package(s) broken: ', paste(res, collapse = ' '))
}
