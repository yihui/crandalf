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
                method = 'wget', mode = 'wb')
}
apt_get = function(pkgs, command = 'install') {
  if (length(pkgs) == 0) return()
  if (length(pkgs) == 1 && (is.na(pkgs) || pkgs == '')) return()
  system2('sudo', c(sprintf('apt-get -qq %s', command), pkgs), stdout = NULL)
}

if (Sys.getenv('TRAVIS') == 'true') {
  message('Checking reverse dependencies for ', pkg)
  apt_get(config[pkg, 'sysdeps'])

  owd = setwd(tempdir())
  unlink(c('*00check.log', '*00install.out', '*.tar.gz'))
  pkgs_deb = system2('apt-cache', 'pkgnames', stdout = TRUE)
  pkgs_deb = grep('^r-cran-.+', pkgs_deb, value = TRUE)
  pkgs_deb = gsub('^r-cran-', '', pkgs_deb)
  if (pkg %in% pkgs_deb) apt_get(sprintf('r-cran-%s', pkg))
  devtools::install_github(config[pkg, 'install'])

  pkgs = strsplit(Sys.getenv('R_CHECK_PACKAGES'), '\\s+')[[1]]
  n = length(pkgs)
  if (n == 0) q('no')

  for (i in seq_len(n)) {
    p = pkgs[i]
    message(sprintf('Checking %s (%d/%d)', p, i, n))
    # use apt-get install/build-dep (thanks to Michael Rutter)
    p_cran = sprintf('r-cran-%s', p)
    if (p %in% pkgs_deb) {
      apt_get(p_cran)
      # in case it has system dependencies
      if (db[p, 'NeedsCompilation'] == 'yes') apt_get(p_cran, 'build-dep')
    }
    deps = tools::package_dependencies(p, db, which = 'all')[[1]]
    deps = unique(c(deps, unlist(tools::package_dependencies(deps, db))))
    apt_get(sprintf('r-cran-%s', setdiff(tolower(deps), pkgs_deb)))
    broken = setdiff(c('xtable'), deps)  # known broken packages in the PPA
    if (length(broken)) install.packages(broken, quiet = TRUE)
    # install extra dependencies not covered by apt-get
    lapply(
      deps,
      function(p) {
        if (!(p %in% .packages(TRUE))) install.packages(p, quiet = TRUE)
      }
    )
    acv = sprintf('%s_%s.tar.gz', p, db[p, 'Version'])
    for (j in 1:5) if (download_source(acv) == 0) break
    if (j == 5) {
      writeLines('Download failed', sprintf('%s-00download', p))
      next
    }
    cmd = system2('R', c('CMD check --no-codoc --no-manual', acv), stdout = NULL)
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
    failed = c(failed, gsub('^(.+)-00.*$', '\\1', logs))
    cat(i, '\n\n')
    system2('cat', logs)
  }
  if (length(failed))
    stop('\nThese packages failed:\n', paste(formatUL(unique(failed)), collapse = '\n'))
  setwd(owd)
} else {
  pkgs = tools::package_dependencies(pkg, db, 'all', reverse = TRUE)[[1]]
  if (length(pkgs) == 0) q('no')  # are you kidding?
  m = as.numeric(config[pkg, 'matrix'])
  if (is.na(m) || m == 0) m = 5  # 5 parallel builds by default
  items = sprintf(
    '    - R_CHECK_PACKAGES="%s"',
    sapply(split(pkgs, rep(1:m, length.out = length(pkgs))), paste, collapse = ' ')
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
