update.packages(ask = FALSE, checkBuilt = TRUE)
if (!requireNamespace('remotes', quietly = TRUE)) install.packages('remotes')
a = commandArgs(TRUE)
remotes::install_github(c('r-lib/revdepcheck', 'yihui/xfun', if (length(a)) a[1]), dependencies = TRUE)
if (dir.exists('package')) {
  setwd('package')
  xfun:::cloud_check(if (length(a) > 1) a[-1])
}
