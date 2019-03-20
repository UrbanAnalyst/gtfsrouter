# CRAN notes for gtfsrouter_0.0.1 submission

There is currently no reference or DOI citation for this package. I am currently drafting a manuscript in which I would like to claim that the software is already available on CRAN. The manuscript should be submitted soon after the package appears, and subsequent releases will definitely have a reference.

The examples have been re-written to execute code previously wrapped in `\dontrun`. Several lines in three of the eight package functions nevertheless retain `dontrun` wrappers.  One of these has a single `dontrun` line, which calls a `plot` method that requires an API key, so must be switched off. The other two have two sets of 2-3 lines which are not run. The first in each case demonstrate the generally required setting of envvars for functions to work. The `dontrun` lines are immediately followed by equivalent lines which are run, and which set variables corresponding to internally-bundled package data only. The second pair of `dontrun` lines in each demonstrate general functionality which is dependent on current system time. Equivalent lines which are run in each case simply specify an explicit time necessary for functions to work with internal package data regardless of current system time.

In all cases, functionality should be absolutely clear, and understanding would in no way be enhanced through any further removal of `dontrun` lines (which would not be possible anyway).

This submission generates no notes or warnings on:

* Ubuntu 14.04 (on `travis-ci`): R-release, R-devel, R-oldrelease
* Windows Visual Studio 2015 (on `appveyor`; `x64`): R-release, R-devel
* win-builder (R-release, R-devel, R-oldrelease)

Package generates no warnings with Clang++ -Weverything

## valgrind memory leak

Testing with "valgrind --tool=memcheck --leak-check=full" reveals one **POSSIBLE** memory leak of around 2,000 bytes, which is due to data.table and not code within this submission. There are nevertheless no definite or indirect memory leaks whatsoever.
