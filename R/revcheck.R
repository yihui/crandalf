owd = setwd('package')
pkg_name = function(desc = 'DESCRIPTION') {
  if (file.exists(desc)) read.dcf(desc, fields = c('Package'))[1, 1] else NA
}
pkg_path = '.'
if (is.na(pkg <- pkg_name())) {
  for (i in list.files('.', '^DESCRIPTION$', recursive = TRUE, full.names = TRUE)) {
    if (!is.na(pkg <- pkg_name(i))) {
      message('Using the file ', i, ' as the package DESCRIPTION file.')
      pkg_path = dirname(i)
      break
    }
  }
}
if (is.na(pkg))
  stop('Cannot figure out the package name. Does the repo really contain an R package?')
setwd(owd)

# install TinyTeX
if (!tinytex::is_tinytex()) tinytex::install_tinytex()
# preinstall more LaTeX packages discovered from previous runs to save time
tinytex::tlmgr_install(scan('latex.txt', character()))
# record LaTeX packages used
writeLines(tinytex::tl_pkgs(), 'latex-packages.txt')

if (!Sys.getenv('GITHUB_EVENT_NAME') %in% c('pull_request', 'workflow_dispatch')) {
  message('Reverse dependency checks are only performed on pull requests or manual dispatch to PR branch...')
  q('no')
}

pkgs = readLines('latex-packages.txt')
res  = xfun::rev_check(pkg, src = file.path('package', pkg_path))
pkgs = setdiff(tinytex::tl_pkgs(), pkgs)
if (length(pkgs)) message(
  'These new packages were installed in TinyTeX during the checks: ',
  paste(pkgs, collapse = ' ')
)
xfun::write_utf8(pkgs, 'latex.txt')

xfun:::clean_Rcheck2()

if (length(pkgs <- names(res)[res == 1])) {
  if (file.exists(f <- '00check_diffs.md')) cat(xfun::file_string(f))
  writeLines(pkgs, 'recheck')
  writeLines(names(res)[res > 1], 'recheck2')
  stop(
    'Some reverse dependencies may be broken by the dev version of ', pkg, ': ',
    paste(pkgs, collapse = ' ')
  )
}
