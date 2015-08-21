#' Update the GIT branches with the \code{pkg/} prefix
#'
#' The script \file{inst/scripts/branch-update} calls this function to update
#' \file{.travis.yml} and \file{README.md} in the \code{pkg/foo} branch based on
#' the config file \file{inst/config/PACKAGES}. Basically it divides packages to
#' be checked into groups for the Travis matrix.
#' @noRd
branch_update = function() {
  if (!file.exists('.travis.yml')) {
    warning('.travis.yml not found under ', getwd())
    return()
  }
  if (is.null(pkg <- pkg_branch())) return()
  config = pkg_config
  rownames(config) = config[, 'package']
  pkgs = pkg_deps(pkg, 'all', reverse = TRUE)[[1]]
  pkgs = setdiff(pkgs, split_pkgs(config[pkg, 'exclude']))
  pkgs_only = split_pkgs(config[pkg, 'only'])
  if (length(pkgs_only)) {
    pkgs = intersect(pkgs, pkgs_only)
  }
  if (length(pkgs) == 0) q('no')  # are you kidding?
  # packages that need to be checked in separate VM's
  pkgs2 = split_pkgs(config[pkg, 'separate'], '\\s*\\|\\s*')
  pkgs2 = unlist(lapply(pkgs2, function(x) {
    x = intersect(split_pkgs(x), pkgs)
    pkgs <<- setdiff(pkgs, x)
    x = paste(x, collapse = ' ')
    x[x != '']
  }))
  m = as.numeric(config[pkg, 'matrix'])
  if (is.na(m) || m == 0)
    m = ceiling(length(pkgs)/7)  # 7 packages per job by default
  if (m <= 0) m = 1
  items = sprintf(
    '    - R_CHECK_PACKAGES="%s"',
    c(
      if (length(pkgs))
        sapply(split(pkgs, sort(rep(1:m, length.out = length(pkgs)))),
               paste, collapse = ' '),
      pkgs2
    )
  )
  if (length(items) == 0) return()
  x = readLines('.travis.yml')
  i1 = which(x == '# matrix-start')
  i2 = which(x == '# matrix-end')
  writeLines(c(x[1:i1], items, x[i2:length(x)]), '.travis.yml')
  repo = 'https://travis-ci.org/yihui/crandalf'
  txt = readLines('README.md')[-(1:2)]
  txt[1] = sprintf(
    '# %s\n\n[![Build Status](%s.svg?branch=pkg/%s)](%s)', pkg,
    repo, pkg, repo
  )
  writeLines(txt, 'README.md')
}

#' Get the package name of which the reverse dependencies are to be checked
#'
#' For \code{pkg_branch()}, the package name is obtained from the environment
#' variable \code{TRAVIS_BRANCH}; if it is empty, the current GIT branch name is
#' used, and the branch name must be of the form \code{pkg/name}, i.e. the
#' package name with the \code{pkg/} prefix.
#' @return The package name, or \code{NULL} if failed to find one.
#' @export
pkg_branch = function() {
  pkg = Sys.getenv(
    'TRAVIS_BRANCH',
    system2('git', 'rev-parse --abbrev-ref HEAD', stdout = TRUE)
  )
  if (nchar(pkg) > 5 && substr(pkg, 1, 4) == 'pkg/') substr(pkg, 5, nchar(pkg))
}

#' @rdname pkg_branch
#' @description For \code{pkg_commit()}, the package named is detected from the
#'   current commit message, which should contain a character string of the form
#'   \code{[crandalf pkg@@user/repo]}, where \code{user/repo} is a repository on
#'   Github.
#' @export
pkg_commit = function() {
  msg = Sys.getenv('TRAVIS_COMMIT_MSG')
  reg = '.*\\[crandalf ([[:alpha:]][[:alnum:].]+)(@[-[:alnum:]/@]+)?\\].*'
  if (!grepl(reg, msg)) return()
  pkg = sub(reg, '\\1', msg)
  src = sub('^@', '', sub(reg, '\\2', msg))
  structure(pkg, src = src)
}

#' Datasets for the package info on CRAN and R package recipes in \pkg{crandalf}
#'
#' The data frame \code{pkg_db} is read from
#' \url{http://cran.rstudio.com/web/packages/packages.rds}, and \code{recipes}
#' is from the file \file{RECIPES} under the \file{config} directory of the
#' \pkg{crandalf} package.
#' @usage NULL
#' @format \code{pkg_db} is a data frame, and \code{recipes} is a character
#'   matrix.
#' @aliases pkg_db
#' @export recipes pkg_db
#' @examples str(recipes); str(pkg_db)
recipes = NULL
pkg_db  = NULL

#' The configuration for packages
#'
#' The file \file{config/PACKAGES} in this package stores some configuration
#' information for packages of which the reverse dependencies are to be checked,
#' such as the package name, the Github repo, and the number of jobs in a build
#' matrix, etc.
#' @usage NULL
#' @format A character matrix.
#' @export
#' @examples str(pkg_config)
pkg_config = NULL

pkg_path = function(...) {
  root = if (file.exists('DESCRIPTION')) '.' else '..'
  file.path(root, ...)
}
# create the recipes data during R CMD INSTALL but not roxygenize
if (!('roxygen2' %in% loadedNamespaces())) {
  recipes = read.dcf(pkg_path('inst/config/RECIPES'))
  rownames(recipes) = tolower(recipes[, 'package'])
  stopifnot(
    ncol(recipes) == 3,
    identical(sort(colnames(recipes)), sort(c('package', 'repo', 'deb')))
  )
  write.dcf(
    recipes[order(recipes[, 'package']), ],
    pkg_path('inst/config/RECIPES')
  )

  pkg_config = read.dcf(pkg_path('inst/config/PACKAGES'))
  write.dcf(
    pkg_config[order(pkg_config[, 'package']), ],
    pkg_path('inst/config/PACKAGES')
  )

  pkg_db = readRDS(gzcon(url('https://cran.rstudio.com/web/packages/packages.rds', 'rb')))
  rownames(pkg_db) = pkg_db[, 'Package']
}

pkg_recommended = c(na.omit(pkg_db[pkg_db[, 'Priority'] == 'recommended', 'Package']))
pkg_base = local({
  x = installed.packages()
  c(unname(na.omit(x[x[, 'Priority'] == 'base', 'Package'])))
})

#' Compute package dependencies
#'
#' This function is a wrapper for \code{\link[tools]{package_dependencies}()}.
#' @param ... passed to \code{\link[tools]{package_dependencies}()}
#' @export
#' @keywords internal
pkg_deps = function(...) tools::package_dependencies(..., db = pkg_db)

#' Install a package from Github using \pkg{devtools}
#'
#' This function will try at most 5 times to install a package from Github, and
#' the reason to retry is that sometimes downloading from Github might fail.
#' @param src passed to \code{\link[devtools]{install_github}()}
#' @export
pkg_install = function(src) {
  for (j in 1:5) {
    if (!inherits(try(
      devtools::install_github(src, quiet = TRUE)
    ), 'try-error')) break
    Sys.sleep(30)
  }
  if (j == 5) stop('Failed to install ', src, ' from Github')
}

#' Download a source package from CRAN
#'
#' This function tries to download a source package from CRAN for at most 5
#' times, and if the RStudio mirror fails, the main CRAN site will be used.
#' @param pkg the package name
#' @export
download_source = function(pkg) {
  acv = sprintf('%s_%s.tar.gz', pkg, pkg_db[pkg, 'Version'])
  download = function(mirror = 'http://cran.rstudio.com') {
    download.file(sprintf('%s/src/contrib/%s', mirror, acv), acv,
                  method = 'wget', mode = 'wb', quiet = TRUE)
  }
  for (j in 1:5) {
    if (download() == 0) break
    if (download('http://cran.r-project.org') == 0) break
    Sys.sleep(5)
  }
  if (j == 5) {
    message('Failed to download ', acv)
    writeLines('Download failed', sprintf('%s-00download', pkg))
    return()
  }
  acv
}

pkgs_deb = local({
  deb = NULL
  function() {
    if (!is.null(deb)) return(deb)
    deb <<- gsub(
      '^r-cran-', '', grep(
        '^r-cran-.+',
        system2('apt-cache', 'pkgnames', stdout = TRUE),
        value = TRUE
      )
    )
    deb
  }
})

#' A wrapper for \command{apt-get} on Ubuntu/Debian
#'
#' This function installs or builds dependencies for R packages if the relevant
#' Debian packages exist.
#' @param pkgs a character vector of packages
#' @param command the command for \command{apt-get}
#' @param R whether to treat \code{pkgs} as R packages
#' @export
apt_get = function(pkgs, command = 'install', R = TRUE) {
  if (length(pkgs) == 0) return()
  if (length(pkgs) == 1 && (is.na(pkgs) || pkgs == '')) return()
  if (R) {
    pkgs = unlist(lapply(pkgs, function(p) {
      if (command %in% c('install', 'build-dep'))
        if (pkg_loadable(p)) return()
      p
    }), use.names = FALSE)
    pkgs = tolower(pkgs)
    if (command %in% c('install', 'build-dep')) {
      for (p in intersect(pkgs, rownames(recipes))) {
        deb  = split_pkgs(recipes[p, 'deb'])
        repo = split_pkgs(recipes[p, 'repo'], ';')
        lapply(repo, function(r) {
          system2('sudo', c('apt-get apt-add-repository -y', r))
        })
        if (length(deb)) system2('sudo', c('apt-get -q install', deb))
      }
      pkgs = setdiff(pkgs, rownames(recipes))
    }
    pkgs = intersect(pkgs, pkgs_deb())
    if (length(pkgs) == 0) return()
    pkgs = sprintf('r-cran-%s', pkgs)
  }
  cmd = function(options = '') {
    system2('sudo', c(sprintf('apt-get -q %s %s', options, command), pkgs))
  }
  if (cmd() == 0) {
    return()
  }
  # current I see it is possible to get the error "Unable to correct problems,
  # you have held broken packages", so see if `apt-get -f install` can fix it
  warning('Failed to install ', paste(pkgs, collapse = ' '), immediate. = TRUE)
  system2('sudo', 'apt-get update -qq')
  system2('sudo', 'apt-get -f install')
  cmd('-f')
}

# do not use requireNamespace() because there is a limit on the number of dll's
# to be loaded in the system, and detach()/unloadNamespace() cannot unload them;
# I do not want to check the dark magic, either, so simply launch a new R
# session to test the package to keep the current session clean
require_ok = function(p) {
  system2(
    'Rscript', c('-e', shQuote(sprintf('library(%s)', p))),
    stdout = NULL, stderr = NULL
  ) == 0
}

#' Whether a package is loadable
#'
#' This function is like \code{\link{require}()}, but it does not load the
#' package in the current R session. Instead, it launches a new R session to
#' test if a package is loadable. The reason for that is it is not trivial to
#' remove all the side effects brought by \code{\link{library}()}, such as
#' DLL's. Instead of cleaning up everything, we just use a new R session to test
#' if a package is loadable.
#' @param p the package name (must be of length 1)
#' @return \code{TRUE} or \code{FALSE}.
#' @export
pkg_loadable = function(p) {
  (p %in% .packages(TRUE)) && require_ok(p)
}

#' Whether a package needs to be compiled
#'
#' This function uses the column \code{NeedsCompilation} of the package database
#' on CRAN to check if a package needes to be compiled. When it contains
#' C/C++/Fortran code, it has to be compiled. For such packages, we might need
#' to install additional system dependencies (e.g. \pkg{libxml2-dev} for the
#' \pkg{XML} package).
#' @inheritParams pkg_loadable
#' @return \code{TRUE} or \code{FALSE}.
#' @export
need_compile = function(p) {
  (p %in% rownames(pkg_db)) && pkg_db[p, 'NeedsCompilation'] == 'yes'
}

#' Install a package and its dependencies
#'
#' If a package is not loadable, install its system dependencies, then install
#' it from source. If the package cannot be found on CRAN, BioConductor will be
#' tried.
#' @param p the package name
#' @export
install_deps = function(p) {
  if (pkg_loadable(p)) return()
  message('Installing ', p)
  # use biocLite() to install both BioC and CRAN packages
  if (!pkg_loadable('BiocInstaller')) source('http://bioconductor.org/biocLite.R')
  suppressMessages(BiocInstaller::biocLite(
    p, suppressUpdates = TRUE, suppressAutoUpdate = TRUE, ask = FALSE
  ))
  if (!pkg_loadable(p))
    warning('Failed to install ', p, call. = FALSE, immediate. = TRUE)
}

#' Re-install packages that were built with R < 3.0.0
#'
#' Some Debian R packages were built with R 2.x, and such packages are not
#' loadable in R 3.x, so we need to find and reinstall them under R 3.x.
#' @param lib the library locations
#' @export
fix_R2 = function(lib = .libPaths()[-1]) {
  built = installed.packages(lib)[, 'Built']
  old = names(built[as.numeric_version(built) < '3.0.0'])
  if (length(old) == 0) return()
  message('Re-installing packages built before R 3.0.0')
  lapply(old, install_deps)
}

#' Given a character string, split it by white spaces or a custom string
#'
#' This package often reads R package names as a character string from
#' environment variables or YAML, and we need to split the character string into
#' a character vector.
#' @param string a charactor string of length 1
#' @param split a character string as the separator to split the string
#' @return A character vector
#' @export
split_pkgs = function(string, split = '\\s+') {
  if (is.na(string) || string == '') return()
  x = unlist(strsplit(string, split))
  unique(x[x != ''])
}

timer = local({
  nano = function() system2('date', '+%s%N', stdout = TRUE)
  timers = list()
  list(
    start = function(job) {
      id = paste(sample(c(0:9, letters), 8, TRUE), collapse = '')
      timers[[job]] <<- list(id = id, t1 = nano())
      cat(sprintf('travis_time:start:%s\r', id))
    },
    finish = function(job) {
      t2 = nano()
      t1 = timers[[job]][['t1']]
      id = timers[[job]][['id']]
      cat(sprintf(
        'travis_time:end:%s:start=%s,finish=%s,duration=%s\r',
        id, t1, t2, system2('echo', sprintf('$((%s - %s))', t2, t1), stdout = TRUE)
      ))
    }
  )
})

#' Fold Travis logs into sections
#'
#' Travis supports folding build logs to make navigation easier in the log
#' viewer. The function \code{travis_fold()} implemented this feature in R.
#' Additionally, the build time for each section will be written after the
#' section tag. You can use either \code{travis_start()} and \code{travis_end()}
#' separately (put R code in between), or a single \code{travis_fold()} call
#' when the R code is short enough.
#' @param job a character string as the section tag (job name)
#' @param code an R expression to run within a section
#' @param msg a character vector of messages to write for the log section
#' @param ... passed to \code{travis_start()}
#' @export
#' @references
#' \url{https://github.com/travis-ci/travis-build/blob/master/lib/travis/build/script/templates/header.sh}
travis_fold  = function(job, code, ...) {
  travis_start(job, ...)
  code
  travis_end(job)
}
#' @rdname travis_fold
#' @export
travis_start = function(job, msg = paste('Running', job)) {
  cat(sprintf('travis_fold:start:%s\r', job))
  timer$start(job)
  cat(msg, '\n')
}
#' @rdname travis_fold
#' @export
travis_end = function(job) {
  timer$finish(job)
  cat(sprintf('travis_fold:end:%s\r', job))
}

#' Find missing LaTeX packages from the log file
#'
#' This function mimics the behavior of MikTeX to find out the missing packages
#' for a LaTeX document automatically. The packages can be installed, for
#' example, via \command{tlmgr install}. Searching for missing packages is based
#' on \command{tlmgr search --global --file}.
#' @param log the filename of the LaTeX log
#' @return A character vector
#' @export
missing_latex = function(log) {
  r = ".*! LaTeX Error: File `([-[:alnum:]]+[.][[:alpha:]]{1,3})' not found.*|.*! Font [^=]+=([^ ]+).+ not loadable.*"
  x = grep(r, readLines(log), value = TRUE)
  if (length(x) == 0) {
    message('Sorry, I was unable to find any missing LaTeX packages')
    return()
  }
  x = unique(gsub(r, '\\1\\2', x))
  pkgs = NULL
  for (j in seq_along(x)) {
    l = system2('tlmgr', c('search --global --file', x[j]), stdout = TRUE)
    if (length(l) == 0) next
    # e.g. searching for fload.sty returns a list like this
    # endfloat:
    #   texmf-dist/tex/latex/endfloat/endfloat.sty
    # float:
    #   texmf-dist/tex/latex/float/float.sty
    k = grep(paste0('/', x[j], '([.][a-z]+)?$'), l)  # only match /fload.sty
    if (length(k) == 0) {
      warning('Failed to find a package that contains ', x[j])
      next
    }
    k = k[k > 2]
    p = grep(':$', l)
    if (length(p) == 0) next
    lapply(k, function(i) {
      l = gsub(':$', '', l[max(p[p < i])])  # find the package name
      pkgs <<- c(pkgs, setNames(l, x[j]))
    })
  }
  unique(pkgs)
}

# packages that probably errored
error_pkgs = function(log) {
  x = readLines(log)
  r1 = '.*travis_fold:start:check_([^_]+)_[0-9]+[.][0-9].*'
  r2 = '.*travis_fold:end:check_([^_]+)_[0-9]+[.][0-9].*'
  i1 = grep(r1, x)
  i2 = grep(r2, x)
  p1 = gsub(r1, '\\1', x[i1])
  p2 = gsub(r2, '\\1', x[i2])
  # these packages must have errored (started without ending)
  pa = setdiff(p1, p2)
  i1 = i1[p1 %in% p2]
  n  = length(i1)
  for (j in seq_len(n)) {
    txt = x[seq(i1[j], i2[j])]
    i = grep('\\* using log directory.+[.]Rcheck.\\s*', txt)
    if (length(i) == 1) txt = txt[i:length(txt)]
    if (any(grepl('Error', txt))) pa = c(pa, p1[j])
  }
  # some package might not have been checked due to timeout
  r = '^\\$\\s*export R_CHECK_PACKAGES="([^"]+)"\\s*$'
  pa = c(pa, setdiff(split_pkgs(gsub(r, '\\1', grep(r, x, value = TRUE))), c(p1, p2)))
  unique(pa)
}

error_cran = function () {
  x = readLines('https://cran.rstudio.com/web/checks/check_summary.html')
  x = grep('ERROR', x, value = TRUE)[-1]
  x = gsub('http://www.R-project.org/nosvn/R.check/', '', x, fixed = TRUE)
  if (length(x) == 0) return()
  x = do.call(rbind, strsplit(x, '</td> <td>'))
  j = grep('r-release-linux-x86_64', x[1, ])
  gsub('^.*x86_64/(.+)-00check.*$', '\\1', grep('ERROR', x[, j], value = TRUE))
}

analyze_logs = function(job, length) {
  log = tempfile()
  unlink(log)
  i = seq(job, length.out = length)
  u = sprintf(
    'wget -O - https://api.travis-ci.org/jobs/%d/log.txt?deansi=true >> %s',
    i, shQuote(log)
  )
  lapply(u, system)
  message('Travis logs written to ', log)
  path = '../ubuntu-bin/TeXLive.pkgs'
  pkg = missing_latex(log)
  pkg = c(pkg, readLines(path))
  writeLines(sort(unique(pkg)), path)
  pkgs = sort(error_pkgs(log))
  cat(pkgs)
  pkgs2 = error_cran()
  cat(pkgs2)
  message('\nAfter excluding packages that errorred on CRAN:')
  cat(setdiff(pkgs, pkgs2))
}
