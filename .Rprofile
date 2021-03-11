dir.create(.libPaths()[1], recursive = TRUE, showWarnings = FALSE)

if (file.exists("~/.Rprofile")) {
  base::sys.source("~/.Rprofile", envir = environment())
}

if (!requireNamespace('xfun', quietly = TRUE)) install.packages('xfun')

options(
  repos = c(
    gsub('^@CRAN@$', 'https://cloud.r-project.org', getOption('repos')),
    CRANextra = if (xfun::is_macos()) 'https://macos.rbind.io'
  ),
  Ncpus = 10, mc.cores = 10, browser = 'false',
  xfun.rev_check.summary = TRUE, xfun.rev_check.sample = 0
)
