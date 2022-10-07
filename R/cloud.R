update.packages(ask = FALSE, checkBuilt = TRUE)
if (!requireNamespace('remotes', quietly = TRUE)) install.packages('remotes')
remotes::install_github(c('r-lib/revdepcheck', commandArgs(TRUE)))
setwd('package')

revdepcheck::cloud_check(r_version = getRversion())
revdepcheck::cloud_status(update_interval = 60)

if (length(res <- revdepcheck::cloud_broken())) {
  print(revdepcheck::cloud_summary())
  revdepcheck::cloud_report()
  for (p in res) print(revdepcheck::cloud_details(revdep = p))
  fs = list.files(list.files('revdep/cloud.noindex', full.names = TRUE), full.names = TRUE)
  # only keep results from broken packages
  unlink(fs[!basename(fs) %in% c(res, paste0(res, '.tar.gz'))], recursive = TRUE)
  stop('Package(s) broken: ', paste(res, collapse = ' '))
}
