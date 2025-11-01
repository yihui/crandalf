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

pkgs0 = c('xfun', 'tinytex')
for (i in pkgs0) {
  if (!requireNamespace(i, quietly = TRUE)) install.packages(i)
}

message('Querying reverse dependencies and their versions...')
db = available.packages(type = 'source')
pkgs = xfun:::check_deps(pkg, db, which = 'hard')$install
db = db[rownames(db) %in% c(pkgs, pkgs0), c('Package', 'Version')]

# update cache on GHA when package versions and/or R's major.minor version have changed
write.csv(
  rbind(db, c('R', paste(head(unlist(getRversion()), 2), collapse = '.'))),
  ".github/versions.csv", row.names = FALSE
)

# generate the R script to do rev dep check
x = readLines('R/revcheck.R')
writeLines(gsub('PKG_NAME', pkg, x), 'R/revcheck.R')

# install from Github if the default install from yihui.org failed
if (Sys.which('tlmgr') == '') tinytex::install_tinytex(version = 'latest')
# preinstall more LaTeX packages discovered from previous runs to save time
tinytex::tlmgr_install(scan('latex.txt', character()))
# record LaTeX packages used
writeLines(tinytex::tl_pkgs(), 'latex-packages.txt')
