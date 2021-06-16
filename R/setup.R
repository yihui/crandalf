# markdown is for xfun::rev_check() to generate the check summary in HTML;
# rmarkdown is installed just in case the package has R Markdown vignettes
pkgs = c('markdown', 'rmarkdown')
for (i in pkgs) {
  if (!requireNamespace(i, quietly = TRUE)) install.packages(i)
}

update.packages(checkBuilt = TRUE, ask = FALSE)
