sM = suppressMessages

# submit one round of checks for `pkgs` (in batches) and fetch the results;
# returns list(broken, crashed) where `crashed` are packages whose results could
# not be fetched (e.g. the summary stage segfaulted)
cloud_run = function(pkgs, tgz, batch_size) {
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
  # record job ids: fetching results below can segfault (see below), and a
  # segfault kills R without running on.exit, so save them to make results
  # recoverable (the file is also uploaded in the failure artifact)
  dir.create('revdep', showWarnings = FALSE)
  cat(jobs, sep = '\n', file = 'revdep/cloud-jobs.txt', append = TRUE)

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
      # broken, so mark them all to be rechecked
      crashed = unique(c(crashed, job_pkgs[[job]]))
    }
  }
  list(broken = broken, crashed = crashed)
}

# run revdepcheck::cloud_check(), rechecking (in the same session, to avoid
# re-setting up the toolchain) packages whose results could not be fetched
cloud_check = function(pkgs = NULL, batch_size = Sys.getenv('CLOUD_BATCH_SIZE', 200)) {
  batch_size = as.integer(batch_size)
  tools::Rcmd(c('build', '.'))
  tgz = Sys.glob('*_*.tar.gz')  # tarball
  if (length(tgz) != 1) stop('Failed to build or find the source package ', tgz)
  pkg = gsub('_.*$', '', tgz)
  if (length(pkgs) == 0) pkgs = revdepcheck::cran_revdeps(pkg, bioc = TRUE)
  pkgs = setdiff(pkgs, pkg)

  dir.create('revdep', showWarnings = FALSE)
  unlink('revdep/cloud-jobs.txt')  # start a fresh record of job ids
  broken = crashed = NULL
  # keep rechecking crashed packages (whose status is unknown) until none remain
  # or we hit the round limit; confirmed-broken packages are not rechecked, as
  # that would just repeat a known failure
  for (round in 1:3) {
    res = cloud_run(pkgs, tgz, batch_size)
    broken = unique(c(broken, res$broken))
    crashed = res$crashed
    if (length(crashed) == 0) break
    if (round < 3) message(
      'Could not fetch results for ', length(crashed),
      ' package(s); rechecking them: ', paste(sort(crashed), collapse = ' ')
    )
    pkgs = crashed
  }

  # record packages to recheck later: confirmed-broken plus any still-unfetched
  # (in case you want to re-dispatch the workflow with this list)
  xfun::write_utf8(union(broken, crashed), 'revdep/recheck.txt')

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
