dir.create(.libPaths()[1], recursive = TRUE, showWarnings = FALSE)

if (file.exists("~/.Rprofile")) {
  base::sys.source("~/.Rprofile", envir = environment())
}

options(
  repos = c(
    gsub('^@CRAN@$', 'https://cloud.r-project.org', getOption('repos')),
    CRANextra = if (Sys.info()["sysname"] == "Darwin") 'https://macos.rbind.io'
  ),
  Ncpus = 10, mc.cores = 10, browser = 'false',
  xfun.rev_check.summary = TRUE, xfun.rev_check.sample = 0,
  xfun.rev_check.keep_md = TRUE
)
