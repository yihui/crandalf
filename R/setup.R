# markdown is for xfun::rev_check() to generate the check summary in HTML;
# rmarkdown is installed just in case the package has R Markdown vignettes
pkgs = c('markdown', 'rmarkdown', 'commonmark')
for (i in pkgs) {
  if (!requireNamespace(i, quietly = TRUE)) install.packages(i)
}

# clean up installed packages (from cache) that are no longer on CRAN
db = available.packages(type = 'source')
remove.packages(setdiff(.packages(TRUE), c(rownames(db), xfun::base_pkgs())))

# packages could be broken for some reason (reinstall them if so)
for (i in .packages(TRUE)) tryCatch(find.package(i), error = function(e) install.packages(i))

update.packages(checkBuilt = TRUE, ask = FALSE)
