# if R_LIBS_USER was set (in .Renviron), make sure it exists
dir.create(Sys.getenv('R_LIBS_USER', tempdir()), recursive = TRUE, showWarnings = FALSE)

if (file.exists("~/.Rprofile")) {
  base::sys.source("~/.Rprofile", envir = environment())
}

options(
  repos = c(
    gsub('^@CRAN@$', 'https://cloud.r-project.org', getOption('repos', c(CRAN = "@CRAN@")))
  ),
  Ncpus = 10, mc.cores = 10, browser = 'false',
  xfun.rev_check.compare = TRUE, xfun.rev_check.timeout = 30 * 60,
  xfun.rev_check.summary = TRUE, xfun.rev_check.sample = Inf,
  xfun.rev_check.keep_md = TRUE, xfun.rev_check.timeout_total = 5 * 60 * 60
)

# only install binary packages on Windows and macOS
if (.Platform$OS.type == "windows" || Sys.info()["sysname"] == "Darwin") {
  options(pkgType = 'binary')
}

# settings for myself
if (Sys.getenv('USER') == 'yihui') {
  options(xfun.rev_check.src_dir = '~/Dropbox/repo')
}
