#' Update the GIT branches with the \code{pkg/} prefix
#'
#' The script \file{inst/scripts/branch-update} calls this function to update
#' \file{.travis.yml} and \file{README.md} in the \code{pkg/foo} branch based on
#' the config file \file{inst/config/PACKAGES}. Basically it divides packages to
#' be checked into groups for the Travis matrix.
#' @noRd
update_branch = function() {
  if (!file.exists('.travis.yml')) {
    warning('.travis.yml not found under ', getwd())
    return()
  }
  if (is.null(pkg <- pkg_branch())) return()
  config = pkg_config()
  pkgs = pkg_deps(pkg, pkg_db, 'all', reverse = TRUE)[[1]]
  pkgs = setdiff(pkgs, split_pkgs(config[pkg, 'exclude']))
  pkgs_only = split_pkgs(config[pkg, 'only'])
  m = NA_integer_
  if (length(pkgs_only)) {
    m = 1
    pkgs = intersect(pkgs, pkgs_only)
  }
  if (length(pkgs) == 0) q('no')  # are you kidding?
  if (is.na(m)) m = as.numeric(config[pkg, 'matrix'])
  if (is.na(m) || m == 0) m = 5  # 5 parallel builds by default
  # packages that need to be checked in separate VM's
  pkgs2 = split_pkgs(config[pkg, 'separate'])
  pkgs2 = intersect(pkgs2, pkgs)
  # arrange the rest of packages in a matrix
  pkgs  = setdiff(pkgs, pkgs2)
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
  writeLines(c(sprintf(
    '# %s\n\n[![Build Status](%s.svg?branch=pkg/%s)](%s)\n', pkg,
    repo, pkg, repo
  ), 'Results of checking CRAN reverse dependencies.'), 'README.md')
}

config_path = function(...) system.file('config', ..., package = 'crandalf')

pkg_config = function() read.dcf(config_path('PACKAGES'))

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
#'   \code{[crandalf user/repo]}, where \code{user/repo} is a repository on
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
#' @format Data frames.
#' @aliases pkg_db
#' @export recipes pkg_db
#' @examples str(recipes); str(pkg_db)
recipes = NULL
pkg_db  = NULL

# create the recipes data during R CMD INSTALL but not roxygenize
if (!('roxygen2' %in% loadedNamespaces())) {
  recipes = read.dcf('inst/config/RECIPES')
  rownames(recipes) = tolower(recipes[, 'package'])
  stopifnot(ncol(recipes) == 2, identical(colnames(recipes), c('package', 'recipe')))

  con = url('http://cran.rstudio.com/web/packages/packages.rds', 'rb')
  pkg_db = tryCatch(readRDS(gzcon(con)), finally = close(con))
  rownames(pkg_db) = pkg_db[, 'Package']
}

#' Compute package dependencies
#'
#' This function is a wrapper for \code{\link[tools]{package_dependencies}()}.
#' @param ... passed to \code{\link[tools]{package_dependencies}()}
#' @keywords internal
pkg_deps = function(...) tools::package_dependencies(...)

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
        if (!need_compile(p) || pkg_loadable(p)) return()
      p
    }), use.names = FALSE)
    pkgs = tolower(pkgs)
    if (command %in% c('install', 'build-dep')) {
      for (p in intersect(pkgs, rownames(recipes)))
        system(recipes[p, 'recipe'], ignore.stdout = TRUE)
      pkgs = setdiff(pkgs, rownames(recipes))
    }
    pkgs = intersect(pkgs, pkgs_deb())
    if (length(pkgs) == 0) return()
    pkgs = sprintf('r-cran-%s', pkgs)
  }
  cmd = function(stdout = NULL, options = '') {
    quiet = is.null(stdout)
    system2(
      'sudo',
      c(sprintf(
        'apt-get %s %s %s',
        if (quiet) '-qq' else '', options, command
      ), pkgs, if (quiet) '> /dev/null'),
      stdout = stdout
    )
  }
  if (cmd() == 0) return()
  # current I see it is possible to get the error "Unable to correct problems,
  # you have held broken packages", so see if `apt-get -f install` can fix it
  system2('sudo', 'apt-get update -qq')
  cmd('', '-f')  # write to stdout to diagnose the problem
}

# do not use requireNamespace() because there is a limit on the number of dll's
# to be loaded in the system, and detach()/unloadNamespace() cannot unload them;
# I do not want to check the dark magic, either, so simply launch a new R
# session to test the package to keep the current session clean
require_ok = function(p, quiet = TRUE) {
  system2(
    'Rscript', c('-e', shQuote(sprintf('library(%s)', p))),
    stdout = !quiet, stderr = !quiet
  ) == 0
}

pkg_loadable = function(p) {
  (p %in% .packages(TRUE)) && require_ok(p)
}

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
  if (need_compile(p)) apt_get(p, 'build-dep')
  # p is not loadable, and it might be due to its dependencies are not loadable
  for (k in pkg_deps(p, pkg_db)[[1]]) Recall(k)
  install = function(p, quiet = TRUE) {
    if (p %in% rownames(pkg_db)) return(install.packages(p, quiet = quiet))
    # perhaps it is a BioC package...
    if (pkg_loadable('BiocInstaller')) library(BiocInstaller)
    if (!exists('biocLite', mode = 'function'))
      source('http://bioconductor.org/biocLite.R')
    suppressMessages(biocLite(
      p, suppressUpdates = TRUE, suppressAutoUpdate = TRUE, ask = FALSE, quiet = quiet
    ))
  }
  install(p)
  if (pkg_loadable(p)) return()
  require_ok(p, FALSE)
  # reinstall: why did it fail?
  install(p, FALSE)
}

#' Given a character string, split it by white spaces
#'
#' This package often reads R package names as a character string from
#' environment variables or YAML, and we need to split the character string into
#' a character vector.
#' @param string a charactor string of length 1
#' @return A character vector
#' @export
split_pkgs = function(string) {
  if (is.na(string) || string == '') return()
  unlist(strsplit(string, '\\s+'))
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
