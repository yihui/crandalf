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
  jobs = broken = crashed = NULL
  job_pkgs = list()  # map each job id to the packages checked in it
  rver = format(getRversion())
  check = function() {
    # make sure to check at least 2 packages
    if (length(pkgs) == 1) pkgs = c(pkgs, if (length(broken)) broken[1] else pkgs)
    batch = head(pkgs, batch_size)
    try_check = function() {
      sM(revdepcheck::cloud_check(
        tarball = tgz, r_version = rver, revdep_packages = batch
      ))
    }
    job = tryCatch(
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
    )
    jobs <<- c(jobs, job)
    job_pkgs[[job]] <<- batch
    pkgs <<- tail(pkgs, -batch_size)
    message(max(N - length(pkgs), 0), '... ', appendLF = FALSE)
  }
  # if there are more than batch_size revdeps, submit one batch at one time
  message('Checking ', N, ' packages: ', appendLF = FALSE)
  while (length(pkgs) > 0) check()
  message('All jobs submitted.')
  # persist job ids: fetching results below can segfault (see below), and a
  # segfault kills R without running on.exit, so save them first to make results
  # recoverable (the file is also uploaded in the failure artifact)
  dir.create('revdep', showWarnings = FALSE)
  writeLines(jobs, 'revdep/cloud-jobs.txt')

  for (job in jobs) {
    revdepcheck::cloud_status(job, update_interval = 300)
  }

  # cloud_broken()/cloud_report()/cloud_details() download results via a curl
  # multi handle, which has been observed to segfault (multi_run -> SIGSEGV).
  # A segfault cannot be caught by tryCatch (it aborts the R process), so run
  # each job's summary in a separate R session via xfun::Rscript_call(): a crash
  # there returns a nonzero exit code (turned into a catchable error) instead of
  # killing the whole run at the very end after all packages were checked.
  summarize_job = function(job) {
    res = revdepcheck::cloud_broken(job)
    if (length(res)) {
      revdepcheck::cloud_report(job)
      for (p in res) print(revdepcheck::cloud_details(job, revdep = p))
      fs = list.files(file.path('revdep/cloud.noindex', job), full.names = TRUE)
      # only keep results from broken packages
      unlink(fs[!basename(fs) %in% c(res, paste0(res, '.tar.gz'))], recursive = TRUE)
    }
    res
  }
  for (job in jobs) {
    ok = FALSE
    for (i in 1:3) {  # retry twice in case the crash/error was transient
      res = tryCatch(
        list(val = xfun::Rscript_call(summarize_job, list(job))),
        error = function(e) {
          message('Failed to fetch results for job ', job, ' (attempt ', i, '): ',
                  conditionMessage(e))
          NULL
        }
      )
      if (!is.null(res)) { ok = TRUE; break }
    }
    if (ok) {
      if (length(res$val)) broken = unique(c(res$val, broken))
    } else {
      # summary crashed for this job: we don't know which of its packages are
      # broken, so mark them all for a later recheck
      crashed = unique(c(crashed, job_pkgs[[job]]))
    }
  }
  # record packages to recheck later: confirmed-broken plus those from jobs whose
  # results could not be fetched (status unknown). the recheck job reads this.
  recheck = union(broken, crashed)
  writeLines(recheck, 'revdep/recheck.txt')
  if (length(crashed)) message(
    'Could not fetch results for ', length(crashed),
    ' package(s); marked for recheck: ', paste(sort(crashed), collapse = ' ')
  )
  if (length(broken)) {
    stop('Package(s) broken: ', paste(sort(broken), collapse = ' '), call. = FALSE)
  } else if (length(crashed)) {
    stop('Result fetch failed for package(s): ', paste(sort(crashed), collapse = ' '),
         call. = FALSE)
  } else {
    message('All reverse dependencies are good!')
  }
}

if (dir.exists('package')) {
  setwd('package')
  cloud_check(gsub('[, ]', '', commandArgs(TRUE)))
}
