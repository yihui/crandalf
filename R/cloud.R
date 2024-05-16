update.packages(ask = FALSE, checkBuilt = TRUE)
if (!requireNamespace('remotes', quietly = TRUE)) install.packages('remotes')
remotes::install_github(c('r-lib/revdepcheck', 'yihui/xfun'))
if (dir.exists('package')) {
  setwd('package')
  remotes::install_local(dependencies = TRUE)
  xfun:::cloud_check(gsub('[, ]', '', commandArgs(TRUE)))
}
