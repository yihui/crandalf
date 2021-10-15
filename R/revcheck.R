# if the event is not pull request, only install/update packages
if (Sys.getenv('GITHUB_EVENT_NAME') != 'pull_request') {
  message('Reverse dependency checks are only performed on pull requests...')
  writeLines(read.csv('.github/versions.csv')[, 1], '00ignore')
}

pkgs = readLines('latex-packages.txt')
res  = xfun::rev_check('PKG_NAME', src = 'package')
pkgs = setdiff(tinytex::tl_pkgs(), pkgs)
if (length(pkgs)) message(
  'These new packages were installed in TinyTeX during the checks: ',
  paste(pkgs, collapse = ' ')
)
xfun::write_utf8(c(pkgs, xfun::read_utf8('latex.txt')), 'latex.txt')

xfun:::clean_Rcheck2()

if (file.exists(f <- '00check_diffs.html')) {
  if (file.exists(f <- xfun::with_ext(f, '.md'))) cat(xfun::file_string(f))
  writeLines(pkgs <- names(res)[res == 1], 'recheck')
  writeLines(names(res)[res > 1], 'recheck2')
  stop(
    'Some reverse dependencies may be broken by the dev version of PKG_NAME: ',
    paste(pkgs, collapse = ' ')
  )
}
