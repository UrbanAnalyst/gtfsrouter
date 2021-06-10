# CRAN notes for gtfsrouter_0.0.5 submission

The submission generates no notes or warnings on:

* Ubuntu 18.04: R-oldrelease, R-release, R-devel
* Windows: R-oldrelease, R-release, R-devel
* win-builder (R-release, R-devel, R-oldrelease)

C++ source code in package also generates no warnings with either Clang++ -Weverything or UBSAN

## valgrind memory leak

Testing with "valgrind --tool=memcheck --leak-check=full" reveals two **POSSIBLE** memory leaks, both due to code within `data.table` and not code within this submission.
