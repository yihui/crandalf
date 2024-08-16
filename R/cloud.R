update.packages(ask = FALSE, checkBuilt = TRUE, quiet = TRUE)
if (!requireNamespace('remotes', quietly = TRUE)) install.packages('remotes', quiet = TRUE)
remotes::install_github(c('r-lib/revdepcheck', 'yihui/xfun'), quiet = TRUE)
if (dir.exists('package')) {
  setwd('package')
  remotes::install_local(dependencies = TRUE, quiet = TRUE)
  xfun:::cloud_check(gsub('[, ]', '', commandArgs(TRUE)))
}
