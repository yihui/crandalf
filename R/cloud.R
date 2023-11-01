update.packages(ask = FALSE, checkBuilt = TRUE)
if (!requireNamespace('remotes', quietly = TRUE)) install.packages('remotes')
remotes::install_github(c('r-lib/revdepcheck', 'yihui/xfun', commandArgs(TRUE)), dependencies = TRUE)
if (dir.exists('package')) {
  setwd('package')
  xfun:::cloud_check()
}
