# markdown is for xfun::rev_check() to generate the check summary in HTML;
# rmarkdown is installed just in case the package has R Markdown vignettes
pkgs = c('markdown', 'rmarkdown', 'remotes')
for (i in pkgs) {
  if (!requireNamespace(i, quietly = TRUE)) install.packages(i)
}
# TODO: use xfun >= 0.27 when it's on CRAN
remotes::install_github('yihui/xfun')

# clean up installed packages (from cache) that are no longer on CRAN
db = available.packages(type = 'source')
remove.packages(setdiff(.packages(TRUE), c(rownames(db), 'base', knitr:::.base.pkgs)))

update.packages(checkBuilt = TRUE, ask = FALSE)
