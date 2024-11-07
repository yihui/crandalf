update.packages(ask = FALSE, checkBuilt = TRUE, quiet = TRUE)
if (!requireNamespace('remotes', quietly = TRUE)) install.packages('remotes', quiet = TRUE)
remotes::install_github('r-lib/revdepcheck', quiet = TRUE)

sM = suppressMessages

# run revdepcheck::cloud_check()
cloud_check = function(pkgs = NULL, batch_size = Sys.getenv('CLOUD_BATCH_SIZE', 200)) {
  batch_size = as.integer(batch_size)
  tools::Rcmd(c('build', '.'))
  tgz = Sys.glob('*_*.tar.gz')  # tarball
  if (length(tgz) != 1) stop('Failed to build or find the source package ', tgz)
  pkg = gsub('_.*$', '', tgz)
  if (length(pkgs) == 0) pkgs = revdepcheck::cran_revdeps(pkg, bioc = TRUE)
  pkgs = setdiff(pkgs, pkg)
  N = length(pkgs)
  jobs = broken = NULL
  rver = format(getRversion())
  check = function() {
    # make sure to check at least 2 packages
    if (length(pkgs) == 1) pkgs = c(pkgs, if (length(broken)) broken[1] else pkgs)
    try_check = function() {
      sM(revdepcheck::cloud_check(
        tarball = tgz, r_version = rver, revdep_packages = head(pkgs, batch_size)
      ))
    }
    jobs <<- c(jobs, tryCatch(
      try_check(),
      error = function(e) {
        if (getRversion() != rver) stop(e)  # already tried a different version
        # if the current R version doesn't work, use the highest supported version
        r = ".*?\\[(('([0-9.]+)'(,\\s+)?)+)].*"
        x = grep(r, e$message, value = TRUE)
        x = gsub(r, '\\1', x)
        v = unlist(strsplit(x, "('|,\\s+)"))
        v = v[v != ''][1]
        if (length(v) != 1 || is.na(v)) stop(e)
        rver <<- v
        try_check()
      }
    ))
    pkgs <<- tail(pkgs, -batch_size)
    message(max(N - length(pkgs), 0), '... ', appendLF = FALSE)
  }
  # if there are more than batch_size revdeps, submit one batch at one time
  message('Checking ', N, ' packages: ', appendLF = FALSE)
  while (length(pkgs) > 0) check()
  message('All jobs submitted.')
  for (job in jobs) {
    revdepcheck::cloud_status(job, update_interval = 300)
  }
  for (job in jobs) {
    if (length(res <- sM(revdepcheck::cloud_broken(job)))) {
      sM(revdepcheck::cloud_report(job))
      for (p in res) print(revdepcheck::cloud_details(job, revdep = p))
      fs = list.files(file.path('revdep/cloud.noindex', job), full.names = TRUE)
      # only keep results from broken packages
      unlink(fs[!basename(fs) %in% c(res, paste0(res, '.tar.gz'))], recursive = TRUE)
      broken = unique(c(res, broken))
    }
  }
  if (length(broken)) {
    stop('Package(s) broken: ', paste(broken, collapse = ' '), call. = FALSE)
  } else {
    message('All reverse dependencies are good!')
  }
}

if (dir.exists('package')) {
  setwd('package')
  remotes::install_local(dependencies = TRUE, quiet = TRUE)
  cloud_check(gsub('[, ]', '', commandArgs(TRUE)))
}
