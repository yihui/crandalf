# crandalf

[![rev-check](https://github.com/yihui/crandalf/workflows/rev-check/badge.svg)](https://github.com/yihui/crandalf/actions)

TLDR; If you want to do the reverse dependency check on your package, you can
[edit the Github Action
rev-check.yaml](https://github.com/yihui/crandalf/edit/master/.github/workflows/rev-check.yaml):
change the `repository` from `yihui/xfun` to your username/repo, and follow the
Github guide to create a pull request. The check results will be available in
Github Actions.

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
