# if the event is not pull request, only install/cache packages, then quit
if (!Sys.getenv('GITHUB_EVENT_NAME') %in% c('pull_request', 'workflow_dispatch')) {
  message('Reverse dependency checks are only performed on pull requests or manual dispatch to PR branch...')
  xfun:::pkg_install(setdiff(read.csv('.github/versions.csv')[, 1], .packages(TRUE)))
  q('no')
}

pkgs = readLines('latex-packages.txt')
install.packages('PKG_NAME')
res  = xfun::rev_check('PKG_NAME', src = 'package')
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
    'Some reverse dependencies may be broken by the dev version of PKG_NAME: ',
    paste(pkgs, collapse = ' ')
  )
}
