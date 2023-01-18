update.packages(ask = FALSE, checkBuilt = TRUE)
if (!requireNamespace('remotes', quietly = TRUE)) install.packages('remotes')
remotes::install_github(c('r-lib/revdepcheck', commandArgs(TRUE)), dependencies = TRUE)
if (!dir.exists('package')) q('no')
setwd('package')

# if the current R version doesn't work, use the highest supported version
cloud_check = function(...) tryCatch(
  revdepcheck::cloud_check(r_version = format(getRversion()), ...),
  error = function(e) {
    r = ".*?\\[(('([0-9.]+)'(,\\s+)?)+)].*"
    x = grep(r, e$message, value = TRUE)
    x = gsub(r, '\\1', x)
    v = unlist(strsplit(x, "('|,\\s+)"))
    v = v[v != ''][1]
    if (is.na(v)) stop(e)
    revdepcheck::cloud_check(r_version = v, ...)
  }
)
cloud_check()
revdepcheck::cloud_status(update_interval = 60)

if (length(res <- revdepcheck::cloud_broken())) {
  revdepcheck::cloud_report()
  for (p in res) print(revdepcheck::cloud_details(revdep = p))
  fs = list.files(list.files('revdep/cloud.noindex', full.names = TRUE), full.names = TRUE)
  # only keep results from broken packages
  unlink(fs[!basename(fs) %in% c(res, paste0(res, '.tar.gz'))], recursive = TRUE)
  stop('Package(s) broken: ', paste(res, collapse = ' '))
}
