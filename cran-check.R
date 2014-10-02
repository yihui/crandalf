pkg = Sys.getenv(
  'TRAVIS_BRANCH',
  system2('git', 'rev-parse --abbrev-ref HEAD', stdout = TRUE)
)
if (pkg == 'master')
  q('no')  # master branch? no, there is no package called master

options(repos = c(CRAN = 'http://cran.rstudio.com'))

con = url('http://cran.rstudio.com/web/packages/packages.rds', 'rb')
db = tryCatch(readRDS(gzcon(con)), finally = close(con))
db = db[, c(
  'Package', 'Depends', 'Imports', 'LinkingTo', 'Suggests', 'Enhances', 'Version',
  'Maintainer', 'NeedsCompilation'
)]
rownames(db) = db[, 'Package']

config = read.dcf('PACKAGES')
if (is.na(match(pkg, config[, 'package'])))
  stop('The package ', pkg, ' was not specified in the PACKAGES file')
rownames(config) = config[, 'package']

download_source = function(pkg) {
  download.file(sprintf('http://cran.rstudio.com/src/contrib/%s', pkg), pkg,
                method = 'wget', mode = 'wb', quiet = TRUE)
}
apt_get = function(pkgs, command = 'install', R = TRUE) {
  if (length(pkgs) == 0) return()
  if (length(pkgs) == 1 && (is.na(pkgs) || pkgs == '')) return()
  if (R) {
    pkgs = tolower(pkgs)
    pkgs = intersect(pkgs, pkgs_deb)
    if (length(pkgs) == 0) return()
    pkgs = sprintf('r-cran-%s', pkgs)
  }
  cmd = function(stdout = NULL) {
    system2(
      'sudo',
      c(sprintf('apt-get %s %s', if (is.null(stdout)) '-qq' else '', command), pkgs),
      stdout = stdout
    )
  }
  if (cmd() == 0) return()
  # current I see it is possible to get the error "Unable to correct problems,
  # you have held broken packages", so see if `apt-get -f install` can fix it
  system2('sudo', 'apt-get -f install')
  cmd('')  # write to stdout to diagnose the problem
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

  for (i in seq_len(n)) {
    p = pkgs[i]
    message(sprintf('Checking %s (%d/%d)', p, i, n))
    # use apt-get install/build-dep (thanks to Michael Rutter)
    apt_get(p)
    # in case it has system dependencies
    if (db[p, 'NeedsCompilation'] == 'yes') apt_get(p, 'build-dep')
    deps = tools::package_dependencies(p, db, which = 'all')[[1]]
    deps = unique(c(deps, unlist(tools::package_dependencies(deps, db, recursive = TRUE))))
    apt_get(deps)
    # known broken packages in the PPA
    broken = c('abind', 'MCMCpack', 'rJava', 'timeDate', 'xtable')
    broken = intersect(broken, deps)
    if (length(broken)) {
      apt_get(broken, 'build-dep')
      install.packages(broken)
    }
    # some packages that cannot be installed
    broken = c('depth', 'mmod', 'pkgmaker', 'rgbif', 'rgdal', 'spatstat', 'RcmdrMisc', 'RAppArmor', 'XLConnectJars')
    # install extra dependencies not covered by apt-get
    lapply(
      deps,
      function(p) {
        if (!(p %in% .packages(TRUE)))
          install.packages(p, quiet = !(p %in% broken))
      }
    )
    acv = sprintf('%s_%s.tar.gz', p, db[p, 'Version'])
    for (j in 1:5) if (download_source(acv) == 0) break
    if (j == 5) {
      writeLines('Download failed', sprintf('%s-00download', p))
      next
    }
    # some packages may take more than 10 minutes to finish, and we need stdout
    # output to avoid Travis timeouts
    timeout = c('DLMtool', 'SCGLR')
    cmd = system2(
      'R', c('CMD check --no-codoc --no-manual', acv), stdout = p %in% timeout
    )
    if (cmd != 0) {
      out = list.files(sprintf('%s.Rcheck', p), '^00.+[.](log|out)$', full.names = TRUE)
      file.copy(out, sprintf('%s-%s', p, basename(out)), overwrite = TRUE)
    }
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
  if (length(pkgs) == 0) q('no')  # are you kidding?
  m = as.numeric(config[pkg, 'matrix'])
  if (is.na(m) || m == 0) m = 5  # 5 parallel builds by default
  items = sprintf(
    '    - R_CHECK_PACKAGES="%s"',
    sapply(split(pkgs, sort(rep(1:m, length.out = length(pkgs)))), paste, collapse = ' ')
  )
  x = readLines('.travis.yml')
  i1 = which(x == '# matrix-start')
  i2 = which(x == '# matrix-end')
  writeLines(c(x[1:i1], items, x[i2:length(x)]), '.travis.yml')
  repo = 'https://travis-ci.org/yihui/cran-revdep-check'
  writeLines(c(sprintf(
    '# %s\n\n[![Build Status](%s.svg?branch=%s)](%s)\n', pkg,
    repo, pkg, repo
  ), 'Results of checking CRAN reverse dependencies.'), 'README.md')
}
