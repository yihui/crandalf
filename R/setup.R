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

# generate the R script to do rev dep check
x = readLines('R/revcheck.R')
writeLines(gsub('PKG_NAME', pkg, x), 'R/revcheck.R')

# install TinyTeX
if (!tinytex::is_tinytex()) tinytex::install_tinytex()
# preinstall more LaTeX packages discovered from previous runs to save time
tinytex::tlmgr_install(scan('latex.txt', character()))
# record LaTeX packages used
writeLines(tinytex::tl_pkgs(), 'latex-packages.txt')

# clean up installed packages (from cache) that are no longer on CRAN
db = available.packages(type = 'source')
remove.packages(setdiff(.packages(TRUE), c(rownames(db), xfun::base_pkgs())))
