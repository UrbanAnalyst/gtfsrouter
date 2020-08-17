# CRAN notes for gtfsrouter_0.0.2 submission

This submission removes the previous NOTE generated on some CRAN systems.

The submission generates no notes or warnings on:

* Ubuntu 18.04: R-oldrelease, R-release
* Windows: R-oldrelease, R-release, R-devel
* win-builder (R-release, R-devel, R-oldrelease)

C++ source code in package also generates no warnings with Clang++ -Weverything

## valgrind memory leak

Testing with "valgrind --tool=memcheck --leak-check=full" reveals several **POSSIBLE** memory leaks, all due to code within `libldunits` and not code within this submission.
