pkg = Sys.getenv(
  'TRAVIS_BRANCH',
  system2('git', 'rev-parse --abbrev-ref HEAD', stdout = TRUE)
)
if (nchar(pkg) < 5 || substr(pkg, 1, 4) != 'pkg/')
  q('no')  # master branch? no, there is no package called master
pkg = substr(pkg, 5, nchar(pkg))

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
stopifnot(ncol(recipes) == 2, identical(colnames(recipes), c('package', 'recipe')))

download_source = function(pkg, mirror = 'http://cran.rstudio.com') {
  download.file(sprintf('%s/src/contrib/%s', mirror, pkg), pkg,
                method = 'wget', mode = 'wb', quiet = TRUE)
}

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
        system(recipes[p, 'recipe'])
      pkgs = setdiff(pkgs, rownames(recipes))
    }
    pkgs = intersect(pkgs, pkgs_deb)
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
pkg_loadable = function(p) {
  (p %in% .packages(TRUE)) && requireNamespace(p, quietly = TRUE)
}
need_compile = function(p) {
  (p %in% rownames(db)) && db[p, 'NeedsCompilation'] == 'yes'
}
install_deps = function(p) {
  if (pkg_loadable(p)) return()
  if (need_compile(p)) apt_get(p, 'build-dep')
  # p is not loadable, and it might be due to its dependencies are not loadable
  for (k in tools::package_dependencies(p, db)[[1]]) Recall(k)
  install = function(p, quiet = TRUE) {
    if (p %in% rownames(db)) return(install.packages(p, quiet = quiet))
    # perhaps it is a BioC package...
    if (!exists('biocLite', mode = 'function'))
      source('http://bioconductor.org/biocLite.R')
    biocLite(p, suppressUpdates = TRUE, suppressAutoUpdate = TRUE, ask = FALSE,
             quiet = quiet)
  }
  install(p)
  if (pkg_loadable(p)) return()
  tryCatch(library(p, character.only = TRUE), error = identity, finally = {
    if (p %in% .packages()) detach(sprintf('package:', p), unload = TRUE)
  })
  # reinstall: why did it fail?
  install(p, FALSE)
}
split_pkgs = function(string) {
  if (is.na(string) || string == '') return()
  unlist(strsplit(string, '\\s+'))
}

if (Sys.getenv('TRAVIS') == 'true') {
  message('Checking reverse dependencies for ', pkg)
  apt_get(config[pkg, 'sysdeps'], R = FALSE)

  owd = setwd(tempdir())
  unlink(c('*00check.log', '*00install.out', '*.tar.gz'))
  pkgs_deb = system2('apt-cache', 'pkgnames', stdout = TRUE)
  pkgs_deb = grep('^r-cran-.+', pkgs_deb, value = TRUE)
  pkgs_deb = gsub('^r-cran-', '', pkgs_deb)
  # knitr's reverse dependencies may need rmarkdown for R Markdown v2 vignettes
  if (pkg == 'knitr' && !pkg_loadable('rmarkdown')) {
    apt_get(c('rmarkdown', tools::package_dependencies('rmarkdown', db)[[1]]))
    install.packages('rmarkdown', quiet = TRUE)
  }
  install_deps('devtools')
  install_deps(pkg)
  for (j in 1:5) {
    if (!inherits(
      devtools::install_github(config[pkg, 'install'], quiet = TRUE),
      'try-error'
    )) break
    Sys.sleep(30)
  }
  if (j == 5) stop('Failed to install ', pkg, ' from Github')

  pkgs = split_pkgs(Sys.getenv('R_CHECK_PACKAGES'))
  n = length(pkgs)
  if (n == 0) q('no')

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

    # install extra dependencies not covered by apt-get
    lapply(deps, install_deps)

    acv = sprintf('%s_%s.tar.gz', p, db[p, 'Version'])
    for (j in 1:5) {
      if (download_source(acv) == 0) break
      if (download_source(acv, 'http://cran.r-project.org') == 0) break
    }
    if (j == 5) {
      writeLines('Download failed', sprintf('%s-00download', p))
      next
    }
    # run R CMD check as a background process; write 0 to done on success,
    system2('R', c('CMD check --no-codoc --no-manual', acv), stdout = NULL)
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
    system2('cat', c(logs, ' | grep -v "... OK"'), ...)
  }
  if (length(failed))
    stop('These packages failed:\n', paste(formatUL(unique(failed)), collapse = '\n'))
  setwd(owd)
} else {
  pkgs = tools::package_dependencies(pkg, db, 'all', reverse = TRUE)[[1]]
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
