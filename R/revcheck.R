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

if (file.exists(f <- '00check_diffs.html')) {
  if (file.exists(f <- xfun::with_ext(f, '.md'))) cat(xfun::file_string(f))
  r = '[.]Rcheck2$'
  pkgs = gsub(r, '', list.files('.', r))
  stop(
    'Some reverse dependencies may be broken by the dev version of PKG_NAME: ',
    paste(pkgs, collapse = ' ')
  )
}
