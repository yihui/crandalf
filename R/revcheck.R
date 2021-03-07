# TODO: remotes is no longer necessary when xfun v0.22 is on CRAN
# markdown is for xfun::rev_check() to generate the check summary in HTML;
# rmarkdown is installed just in case the package has R Markdown vignettes
pkgs = c('remotes', 'markdown', 'rmarkdown')
for (i in pkgs) {
  if (!requireNamespace(i, quietly = TRUE)) install.packages(i)
  if (i == 'remotes') remotes::install_github('yihui/xfun')
}

# if the event is not pull request, only install/update packages
if (Sys.getenv('GITHUB_EVENT_NAME') != 'pull_request') {
  message('Reverse dependency checks are only performed on pull requests...')
  writeLines(read.csv('.github/versions.csv')[, 1], '00ignore')
}

pkgs = readLines('latex-packages.txt')
xfun::rev_check('PKG_NAME', src = 'package')
pkgs = setdiff(tinytex::tl_pkgs(), pkgs)
if (length(pkgs)) message(
  'These new packages were installed in TinyTeX during the checks: ',
  paste(pkgs, collapse = ' ')
)

if (file.exists('00check_diffs.html')) {
  system('curl -F "file=@00check_diffs.html" https://file.io')
  r = '[.]Rcheck2$'
  pkgs = gsub(r, '', list.files('.', r))
  stop(
    'Some reverse dependencies may be broken by the dev version of PKG_NAME: ',
    paste(pkgs, collapse = ' ')
  )
}
