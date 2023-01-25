update.packages(ask = FALSE, checkBuilt = TRUE)
if (!requireNamespace('remotes', quietly = TRUE)) install.packages('remotes')
remotes::install_github(c('r-lib/revdepcheck', commandArgs(TRUE)), dependencies = TRUE)
install.packages('xfun', repos = 'https://yihui.r-universe.dev')
if (dir.exists('package')) {
  setwd('package')
  xfun:::cloud_check()
}
