owd = setwd('package')
pkg_name = function(desc = 'DESCRIPTION') {
  if (file.exists(desc)) read.dcf(desc, fields = c('Package'))[1, 1] else NA
}
if (is.na(pkg <- pkg_name())) {
  for (i in list.files('.', '^DESCRIPTION$', recursive = TRUE, full.names = TRUE)) {
    if (!is.na(pkg <- pkg_name(i))) {
      message('Using the file ', i, ' as the package DESCRIPTION file.')
      break
    }
  }
}
if (is.na(pkg))
  stop('Cannot figure out the package name. Does the repo really contain an R package?')
setwd(owd)

update.packages(checkBuilt = TRUE, ask = FALSE)

pkgs0 = c('xfun', 'tinytex', 'markdown', 'rmarkdown')
for (i in pkgs0) {
  if (!requireNamespace(i, quietly = TRUE)) install.packages(i)
  # if (i == 'remotes') remotes::install_github('yihui/xfun')
}

message('Querying reverse dependencies and their versions...')
db = available.packages(type = 'source')
pkgs = xfun:::check_deps(pkg, db)$install
db = db[rownames(db) %in% c(pkgs, pkgs0), c('Package', 'Version')]

writeLines(c(db[, 1], db[, 2], getRversion()$major), ".github/versions.txt")

retry = function(expr, times = 3) {
  for (i in seq_len(times)) {
    if (!inherits(res <- try(expr, silent = TRUE), 'try-error')) return(res)
    Sys.sleep(5)
  }
}

# Homebrew dependencies
message('Querying Homebrew dependencies for R packages')
deps = NULL
for (i in sprintf('https://sysreqs.r-hub.io/pkg/%s/osx-x86_64-clang', pkgs)) {
  x = retry(readLines(i, warn = FALSE))
  x = gsub('^\\s*\\[|\\]\\s*$', '', x)
  x = unlist(strsplit(gsub('"', '', x), ','))
  x = setdiff(x, 'null')
  deps = c(deps, x)
}
deps = unlist(strsplit(deps, '\\s+'))
deps = setdiff(deps, 'pandoc-citeproc')  # pandoc-citeproc is no longer available
if (length(deps)) {
  cat('Need to install system packages:', deps, sep = ' ')
  cat(
    paste(c('brew install', deps), collapse = ' '), '\n',
    file = 'install-sysreqs.sh', append = TRUE
  )
}

# generate the R script to do rev dep check
x = readLines('R/revcheck.R')
writeLines(gsub('PKG_NAME', pkg, x), 'R/revcheck.R')

# record LaTeX packages used
writeLines(tinytex::tl_pkgs(), 'latex-packages.txt')
