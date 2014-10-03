pkg = Sys.getenv(
  'TRAVIS_BRANCH',
  system2('git', 'rev-parse --abbrev-ref HEAD', stdout = TRUE)
)
if (pkg == 'master')
  q('no')  # master branch? no, there is no package called master

options(repos = c(CRAN = 'http://cran.rstudio.com'))

con = url('http://cran.rstudio.com/web/packages/packages.rds', 'rb')
db = tryCatch(readRDS(gzcon(con)), finally = close(con))
rownames(db) = db[, 'Package']

config = read.dcf('PACKAGES')
if (is.na(match(pkg, config[, 'package'])))
  stop('The package ', pkg, ' was not specified in the PACKAGES file')
rownames(config) = config[, 'package']

# additional system dependencies for R packages that I cannot figure out by
# apt-get build-dep
recipes = read.dcf('RECIPES')
rownames(recipes) = tolower(recipes[, 'package'])

download_source = function(pkg) {
  download.file(sprintf('http://cran.rstudio.com/src/contrib/%s', pkg), pkg,
                method = 'wget', mode = 'wb', quiet = TRUE)
}
# some old packages should not be installed from PPA, e.g. abind
pkgs_old = rownames(db)[as.Date(db[, 'Published']) <= as.Date('2013-04-03')]
pkgs_old = unname(pkgs_old)

apt_get = function(pkgs, command = 'install', R = TRUE) {
  if (length(pkgs) == 0) return()
  if (length(pkgs) == 1 && (is.na(pkgs) || pkgs == '')) return()
  if (R) {
    if (command == 'install') pkgs = unlist(lapply(pkgs, function(p) {
      if (!pkg_loadable(p)) p
    }), use.names = FALSE)
    pkgs = tolower(pkgs)
    if (command == 'install') {
      for (p in intersect(pkgs, rownames(recipes))) system(recipes[p, 'recipe'])
      pkgs = setdiff(pkgs, rownames(recipes))
      pkgs = setdiff(pkgs, tolower(pkgs_old))
    }
    if (command == 'build-dep') pkgs = setdiff(pkgs, rownames(recipes))
    pkgs = intersect(pkgs, pkgs_deb)
    if (length(pkgs) == 0) return()
    pkgs = sprintf('r-cran-%s', pkgs)
  }
  cmd = function(stdout = NULL, options = '') {
    system2(
      'sudo',
      c(sprintf(
        'apt-get %s %s %s',
        if (is.null(stdout)) '-qq' else '', options, command
      ), pkgs),
      stdout = stdout
    )
  }
  if (cmd() == 0) return()
  # current I see it is possible to get the error "Unable to correct problems,
  # you have held broken packages", so see if `apt-get -f install` can fix it
  system2('sudo', 'apt-get update -qq')
  cmd('', '-f')  # write to stdout to diagnose the problem
}
pkg_loadable = function(p) {
  (p %in% .packages(TRUE)) && requireNamespace(p, quietly = TRUE)
}
need_compile = function(p) {
  (p %in% rownames(db)) && db[p, 'NeedsCompilation'] == 'yes'
}

if (Sys.getenv('TRAVIS') == 'true') {
  message('Checking reverse dependencies for ', pkg)
  apt_get(config[pkg, 'sysdeps'], R = FALSE)

  owd = setwd(tempdir())
  unlink(c('*00check.log', '*00install.out', '*.tar.gz'))
  pkgs_deb = system2('apt-cache', 'pkgnames', stdout = TRUE)
  pkgs_deb = grep('^r-cran-.+', pkgs_deb, value = TRUE)
  pkgs_deb = gsub('^r-cran-', '', pkgs_deb)
  apt_get(pkg)
  # knitr's reverse dependencies may need rmarkdown for R Markdown v2 vignettes
  if (pkg == 'knitr' && !('rmarkdown' %in% .packages(TRUE))) {
    apt_get(tools::package_dependencies('rmarkdown', db)[[1]])
    install.packages('rmarkdown', quiet = TRUE)
  }
  devtools::install_github(config[pkg, 'install'])

  pkgs = strsplit(Sys.getenv('R_CHECK_PACKAGES'), '\\s+')[[1]]
  n = length(pkgs)
  if (n == 0) q('no')

  db2 = available.packages()
  update_pkgs = function() {
    try(suppressWarnings(update.packages(
      ask = FALSE, checkBuilt = TRUE, available = db2, instlib = .libPaths()[1],
      quiet = TRUE
    )))
  }

  for (i in seq_len(n)) {
    p = pkgs[i]
    message(sprintf('Checking %s (%d/%d)', p, i, n))
    # use apt-get install/build-dep (thanks to Michael Rutter)
    apt_get(p)
    # in case it has system dependencies
    if (need_compile(p)) apt_get(p, 'build-dep')
    deps = tools::package_dependencies(p, db, which = 'all')[[1]]
    deps = unique(c(deps, unlist(tools::package_dependencies(deps, db, recursive = TRUE))))
    apt_get(deps)
    apt_get(pkgs_old, 'remove')

    # update old debian R packages
    old = rownames(old.packages(checkBuilt = TRUE, available = db2))
    if (length(old)) {
      apt_get(old, 'build-dep')
      if ('rJava' %in% old) system2('sudo', 'R CMD javareconf')
      update_pkgs()
    }

    install_deps = function(p) {
      if (pkg_loadable(p)) return()
      if (need_compile(p)) apt_get(p, 'build-dep')
      # p is not loadable, and it might be due to its dependencies are not loadable
      for (k in tools::package_dependencies(p, db)[[1]]) Recall(k)
      install.packages(p, quiet = TRUE)
      if (pkg_loadable(p)) return()
      # reinstall: why did it fail?
      install.packages(p, quiet = FALSE)
    }
    # install extra dependencies not covered by apt-get
    lapply(deps, install_deps)
    # double check if all installed packages are up-to-date
    update_pkgs()
    broken = c('abind', 'xtable')
    broken = intersect(broken, .packages(TRUE))
    for (k in broken) if (!pkg_loadable(k)) install.packages(k)

    acv = sprintf('%s_%s.tar.gz', p, db[p, 'Version'])
    for (j in 1:5) if (download_source(acv) == 0) break
    if (j == 5) {
      writeLines('Download failed', sprintf('%s-00download', p))
      next
    }
    # run R CMD check as a background process; write 0 to done on success,
    # otherwise create an empty done
    unlink('done')
    cmd = system2(
      'R', c('CMD check --no-codoc --no-manual', acv, '> /dev/null && echo 0 > done || touch done'),
      stdout = NULL, wait = FALSE
    )
    s = 0
    while(!file.exists('done')) {
      Sys.sleep(1)
      s = s + 1
      if (s %% 30 != 0) next
      # if it has not finished in 10 minutes, print the log to see what happened
      if (s > 10 * 60) system2('cat', sprintf('%s.Rcheck/00*.*', p))
      cat('.')  # write a dot to stdout every 30 seconds to avoid Travis timeouts
    }
    if (file.info('done')[, 'size'] == 0) {
      out = list.files(sprintf('%s.Rcheck', p), '^00.+[.](log|out)$', full.names = TRUE)
      file.copy(out, sprintf('%s-%s', p, basename(out)), overwrite = TRUE)
    }
    unlink('done')
  }
  # output in the order of maintainers
  authors = split(pkgs, db[pkgs, 'Maintainer'])
  failed = NULL
  for (i in names(authors)) {
    logs = Sys.glob(sprintf('%s-00*', authors[[i]]))
    if (length(logs) == 0) next
    fail   = unique(gsub('^(.+)-00.*$', '\\1', logs))
    failed = c(failed, fail)
    cat('\n\n', paste(c(i, fail), collapse = '\n'), '\n\n')
    system2('cat', c(logs, ' | grep -v "... OK"'))
  }
  if (length(failed))
    stop('These packages failed:\n', paste(formatUL(unique(failed)), collapse = '\n'))
  setwd(owd)
} else {
  pkgs = tools::package_dependencies(pkg, db, 'all', reverse = TRUE)[[1]]
  pkgs_only = config[pkg, 'only']
  m = NA_integer_
  if (!is.na(pkgs_only) && pkgs_only != '') {
    m = 1
    pkgs = intersect(pkgs, strsplit(pkgs_only, '\\s+')[[1]])
  }
  if (length(pkgs) == 0) q('no')  # are you kidding?
  if (is.na(m)) m = as.numeric(config[pkg, 'matrix'])
  if (is.na(m) || m == 0) m = 5  # 5 parallel builds by default
  # packages that need to be checked in separate VM's
  pkgs2 = config[pkg, 'separate']
  pkgs2 = if (!is.na(pkgs2) && pkgs2 != '') strsplit(pkgs2, '\\s+')[[1]]
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
  if (length(items) == 0) q('no')
  x = readLines('.travis.yml')
  i1 = which(x == '# matrix-start')
  i2 = which(x == '# matrix-end')
  writeLines(c(x[1:i1], items, x[i2:length(x)]), '.travis.yml')
  repo = 'https://travis-ci.org/yihui/crandalf'
  writeLines(c(sprintf(
    '# %s\n\n[![Build Status](%s.svg?branch=%s)](%s)\n', pkg,
    repo, pkg, repo
  ), 'Results of checking CRAN reverse dependencies.'), 'README.md')
}
