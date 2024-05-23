# crandalf

[![rev-check](https://github.com/yihui/crandalf/workflows/rev-check/badge.svg)](https://github.com/yihui/crandalf/actions)

TL;DR If you want to do the reverse dependency check on your package, you can
[edit the Github Action
rev-check.yaml](https://github.com/yihui/crandalf/edit/main/.github/workflows/rev-check.yaml)
(Github will automatically fork the repo for you since you don't have write
permission to my repo): change the `repository` from `yihui/knitr` to your
username/repo, and follow the Github guide to create a pull request. The check
results will be available in Github Actions.

## The idea

There are a lot of things to check before you submit an R package to CRAN, and
the last thing is probably to make sure your new version will not break any
existing packages on CRAN, otherwise you may hear [Gandalf tell you
that](http://youtu.be/V4UfAL9f74I) "You shall not pass."

![YOU SHALL NOT PASS](https://i.imgur.com/3mdv0k9.jpg)

The way to make sure your new version will not break packages that depend on
your package is to run reverse dependency checks. The basic idea is the
following:

1.  Install the new version (development version) of your package, and run
    `R CMD check` on all packages that depend on yours. In theory, all these
    checks should pass. If that's the case, you are good to go.

2.  If any of your reverse dependency fails to pass the check, there are two
    possible reasons:

    1.  A certain change that you made in the new version broke it. For this
        case, you should either undo the change, or contact the maintainer of
        the reverse dependency and see if they'd like to change their package to
        accommodate your (breaking) changes.

    2.  The reverse dependency is currently also failing on CRAN. For this case,
        usually you are good to go. To verify it, we can run the check again
        with the current CRAN version of your package. If it also fails, perhaps
        it is not your fault.

This repo provides a service based on Github Actions to run reverse dependency
checks via `xfun::rev_check(),` which is one implementation of the above idea.
Features include:

1.  The checks are run on macOS, and it will try to automatically install system
    dependencies for R packages via Homebrew (thanks to
    [sysreqsdb](https://github.com/r-hub/sysreqsdb)).
2.  It uses the LaTeX distribution [TinyTeX](https://github.com/yihui/tinytex),
    which means missing LaTeX packages will be automatically installed,
    including those used in package vignettes.

## Caveats

Note that this service has two caveats:

1.  It will try its best to install as many packages required by the checks as
    possible, but it doesn't guarantee all can be installed.
2.  Currently it only installs CRAN packages but not packages from other
    repositories. This may change in the future.

As a result, even if your package passes the checks, it *does not* guarantee
that all reverse dependencies would not be broken, because some of them may not
have been checked. Even with a subset of reverse dependencies checked, this
service may help you discover potential problems without you running all the
checks locally.

The option `xfun.rev_check.sample = Inf` in `.Rprofile` means that all soft
reverse dependencies are checked. Here "soft" means packages that list your
package in their `Suggests` or `Enhances` field in the `DESCRIPTION` file. This
number indicates the number of soft reverse dependencies that you want to check
(they will be randomly sampled). If you do not want to check them at all, set
this option to `0`.

## Debugging

When the checks for any reverse dependencies fail, the Github action run will
have an artifact `macOS-rev-check-results` for you to download ([see this
example](https://github.com/yihui/crandalf/actions/runs/641478391)). It contains
the `R CMD check` logs of failed packages as well as an HTML file
`00check_diff.html`, which contains a summary of the failed checks, indicating
the errors caused by the new version of the package (compared to its CRAN
version).

## Rechecking

After you fix the problems revealed by the initial check and push to the Github
repo of your package, you can add a `recheck` file to the root directory of this
repo. In this file, you specify the names of packages that you want to recheck.
This may save you some time by skipping checking packages that have been checked
and have passed last time. However, please note that your fix might break those
passed packages. To be conservative, you can always check the full list of
reverse dependencies, which can just be time-consuming for a package that has a
large number of reverse dependencies.

## Timeout

When your package has a large number of reverse dependencies, the job may take
longer than six hours to finish, which will lead to timeout. To solve this
problem, you have to split the reverse dependencies into batches and run the
checks in different jobs.

1.  Fork this repo, go to `Settings -> Actions` and allow all actions in your
    forked repo.

2.  Clone the forked repo. Change the `repository` in
    `.github/workflows/rev-check.yaml` to your package repo that you want to
    check (e.g., `therneau/survival`). Commit and push to your repo. Wait for
    the action to finish, which will cache the reverse dependencies and their
    dependencies. This can save quite a bit of R package installation time in
    the future.

3.  Install [the latest version of
    **xfun**](https://github.com/yihui/xfun#xfun). You may need to restart R
    after the installation.

4.  Run `xfun::crandalf_check("PKG")` where `PKG` is your package name (e.g.,
    `survival`). This function will split the reverse dependencies into batches
    if necessary. From my experience, checking a package takes about one or two
    minutes on average. You are likely to hit the timeout if you need to check
    more than 400 packages, so the batch size for `xfun::crandalf_check()` is
    400 by default, but you can change it.

5.  Run `xfun::crandalf_results("PKG")` and wait for all jobs to finish, which
    can take roughly `N / 5 * 6` hours where `N` is the number of batches. For
    example, if you have 4000 reverse dependencies to check, they will be
    checked in `4000 / 400 = 10` batches, and may take `10 / 5 * 6 = 12` hours.

## Run `xfun::rev_check()` locally

You can also run `xfun::rev_check()` locally in this repo. The help page
`?xfun::rev_check` has more information on its usage. Basically, you need to
pass the package name and the path of its development version to this function,
e.g.,

``` r
xfun::rev_check('knitr', src = '~/Downloads/repo/knitr')
```

If you want to run `xfun::rev_check()` locally in this repo, please note that it
will create an R library at `~/R-tmp`, which will be used to install reverse
dependencies and their dependencies (which you probably don't use routinely, so
a dedicated path `~/R-tmp` is used instead of the usual `.libPaths()`). Other
than that, all file I/O will only occur inside this repo.

## Related work

If you want to check revdeps in your own repo instead of this repo, you may use
the Github action [`r-devel/recheck.yml`](https://github.com/r-devel/recheck).

