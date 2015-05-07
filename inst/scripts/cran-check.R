if (Sys.getenv('TRAVIS') != 'true') q('no')

library(crandalf)
config = pkg_config

if (is.null(pkg <- pkg_branch())) {
  if (is.null(pkg <- pkg_commit()))
    q('no')  # no pkg branch, and no [crandalf] message
  if (is.na(match(pkg, config[, 'package']))) {
    config = rbind(config, '')
    config[nrow(config), c('package', 'install')] = c(pkg, attr(pkg, 'src', TRUE))
  }
}

options(repos = c(CRAN = 'http://cran.rstudio.com'))

if (!(pkg %in% rownames(pkg_db)))
  stop('The package ', pkg, ' is not found on CRAN')
if (is.na(match(pkg, config[, 'package'])))
  stop('The package ', pkg, ' was not specified in the PACKAGES file or commit message')
rownames(config) = config[, 'package']

message('Checking reverse dependencies for ', pkg)

setwd(tempdir())
unlink(c('*00check.log', '*00install.out', '*.tar.gz'))

# knitr's reverse dependencies may need rmarkdown for R Markdown v2 vignettes
travis_fold(
  'install_rmarkdown',
  if (pkg == 'knitr') install_deps('rmarkdown'),
  'Installing rmarkdown'
)

travis_fold(
  'install_devtools',
  install_deps('devtools'),
  'Installing devtools'
)
travis_fold(
  'devtools_install',
  install.packages(pkg, repos = c('http://yihui.name/xran', 'http://cran.rstudio.com')),
  c('Installing', pkg, 'from source')
)

travis_fold(
  'install_recommended',
  for (i in na.omit(pkg_db[pkg_db[, 3] == 'recommended', 1])) install_deps(i)
)

pkgs = split_pkgs(Sys.getenv('R_CHECK_PACKAGES'))
if (length(pkgs) == 0) pkgs = pkg_deps(pkg, 'all', reverse = TRUE)[[1]]
n = length(pkgs)
if (n == 0) q('no')

excludes = split_pkgs(config[pkg, 'exclude'])

for (i in seq_len(n)) {
  p = pkgs[i]
  if (any(unlist(c(pkg_deps(p, recursive = TRUE), pkg_deps(p, which = 'all'))) %in% excludes)) {
    message('Package ', p, ' was skipped since some dependencies cannot be installed')
    next
  }
  msg1 = sprintf('check_%s_%d.%d', p, n, i)
  travis_start(msg1, c('Checking', p))

  msg2 = sprintf('install_deps_%s', p)
  travis_start(msg2, '  Installing dependencies')
  deps = pkg_deps(p, which = 'all')[[1]]
  lapply(deps, install_deps)
  travis_end(msg2)

  if (is.null(acv <- download_source(p))) next
  travis_fold(
    sprintf('check_%s', p),
    res <- system2('R', c('CMD check --no-codoc --no-manual', acv)),
    c('  R CMD check', acv)
  )
  logs = sprintf('%s.Rcheck/%s', p, c('00check.log', '00install.out'))
  if (res != 0 || length(grep('^Error in', readLines(logs[1])))) {
    file.copy(
      logs,
      sprintf('%s-%s', p, c('00check.log', '00install.out'))
    )
  }

  travis_end(msg1)
}
# output in the order of maintainers
authors = split(pkgs, pkg_db[pkgs, 'Maintainer'])
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
