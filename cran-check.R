config = read.dcf('PACKAGES')

pkg = Sys.getenv(
  'TRAVIS_BRANCH',
  system2('git', 'rev-parse --abbrev-ref HEAD', stdout = TRUE)
)
if (nchar(pkg) > 5 && substr(pkg, 1, 4) == 'pkg/') {
  pkg = substr(pkg, 5, nchar(pkg))
} else {
  msg = Sys.getenv('TRAVIS_COMMIT_MSG')
  reg = '.*\\[crandalf ([[:alpha:]][[:alnum:].]+)(@[-[:alnum:]/@]+)?\\].*'
  if (!grepl(reg, msg)) q('no')  # no pkg branch, and no [crandalf] message
  pkg = sub(reg, '\\1', msg)
  pkg_src = sub('^@', '', sub(reg, '\\2', msg))
  if (is.na(match(pkg, config[, 'package']))) {
    config = rbind(config, '')
    n = nrow(config)
    config[n, c('package', 'install')] = c(pkg, pkg_src)
  }
}

options(repos = c(CRAN = 'http://cran.rstudio.com'))

con = url('http://cran.rstudio.com/web/packages/packages.rds', 'rb')
db = tryCatch(readRDS(gzcon(con)), finally = close(con))
rownames(db) = db[, 'Package']
if (!(pkg %in% rownames(db)))
  stop('The package ', pkg, ' is not found on CRAN')
if (is.na(match(pkg, config[, 'package'])))
  stop('The package ', pkg, ' was not specified in the PACKAGES file or commit message')
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
        system(recipes[p, 'recipe'], ignore.stdout = TRUE)
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
  (p %in% rownames(db)) && db[p, 'NeedsCompilation'] == 'yes'
}
install_deps = function(p) {
  if (pkg_loadable(p)) return()
  message('Installing ', p)
  if (need_compile(p)) apt_get(p, 'build-dep')
  # p is not loadable, and it might be due to its dependencies are not loadable
  for (k in tools::package_dependencies(p, db)[[1]]) Recall(k)
  install = function(p, quiet = TRUE) {
    if (p %in% rownames(db)) return(install.packages(p, quiet = quiet))
    # perhaps it is a BioC package...
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
travis_start = function(job) {
  cat(sprintf('travis_fold:start:%s%s\r', commandArgs(TRUE), job))
  timer$start(job)
}
travis_end = function(job) {
  timer$finish(job)
  cat(sprintf('travis_fold:end:%s%s\r', commandArgs(TRUE), job))
}
travis_fold  = function(job, code) {
  travis_start(job)
  code
  travis_end(job)
}

if (Sys.getenv('TRAVIS') == 'true') {
  message('Checking reverse dependencies for ', pkg)
  travis_fold(
    'system_dependencies',
    apt_get(config[pkg, 'sysdeps'], R = FALSE)
  )

  owd = setwd(tempdir())
  unlink(c('*00check.log', '*00install.out', '*.tar.gz'))
  pkgs_deb = system2('apt-cache', 'pkgnames', stdout = TRUE)
  pkgs_deb = grep('^r-cran-.+', pkgs_deb, value = TRUE)
  pkgs_deb = gsub('^r-cran-', '', pkgs_deb)

  # knitr's reverse dependencies may need rmarkdown for R Markdown v2 vignettes
  travis_start('install_rmarkdown')
  if (pkg == 'knitr' && !pkg_loadable('rmarkdown')) {
    apt_get(c('rmarkdown', tools::package_dependencies('rmarkdown', db)[[1]]))
    install.packages('rmarkdown', quiet = TRUE)
  }
  travis_end('install_rmarkdown')

  travis_fold(
    'install_devtools',
    install_deps('devtools')
  )
  travis_fold(
    sprintf('install_%s_apt', pkg),
    install_deps(pkg)
  )
  travis_start('devtools_install')
  for (j in 1:5) {
    if (!inherits(try(
      devtools::install_github(config[pkg, 'install'], quiet = TRUE)
    ), 'try-error')) break
    Sys.sleep(30)
  }
  if (j == 5) stop('Failed to install ', pkg, ' from Github')
  travis_end('devtools_install')

  pkgs = split_pkgs(Sys.getenv('R_CHECK_PACKAGES'))
  if (length(pkgs) == 0)
    pkgs = tools::package_dependencies(pkg, db, 'all', reverse = TRUE)[[1]]
  n = length(pkgs)
  if (n == 0) q('no')

  for (i in seq_len(n)) {
    p = pkgs[i]
    msg1 = sprintf('check_%s_(%d/%d)', p, i, n)
    travis_start(msg1)
    msg2 = sprintf('install_deps_%s', p)
    travis_start(msg2)
    # use apt-get install/build-dep (thanks to Michael Rutter)
    apt_get(p)
    # in case it has system dependencies
    if (need_compile(p)) apt_get(p, 'build-dep')
    deps = tools::package_dependencies(p, db, which = 'all')[[1]]
    deps = unique(c(deps, unlist(tools::package_dependencies(deps, db, recursive = TRUE))))
    apt_get(deps)

    # install extra dependencies not covered by apt-get
    lapply(deps, install_deps)
    travis_end(msg2)

    acv = sprintf('%s_%s.tar.gz', p, db[p, 'Version'])
    for (j in 1:5) {
      if (download_source(acv) == 0) break
      if (download_source(acv, 'http://cran.r-project.org') == 0) break
      Sys.sleep(5)
    }
    if (j == 5) {
      writeLines('Download failed', sprintf('%s-00download', p))
      next
    }
    msg3 = sprintf('check_%s', p)
    travis_start(msg3)
    system2('R', c('CMD check --no-codoc --no-manual', acv, '| grep -v "... OK"'))
    travis_end(msg3)
    travis_end(msg1)
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
    '# %s\n\n[![Build Status](%s.svg?branch=pkg/%s)](%s)\n', pkg,
    repo, pkg, repo
  ), 'Results of checking CRAN reverse dependencies.'), 'README.md')
}
