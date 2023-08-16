# CRAN notes for gtfsrouter_0.1.1 submission

Several attempts to re-submit this package have been rejected because the auto-checking service identified examples with "CPU time > 2.5 times elapsed time". These were caused by default parallelisation in the data.table package. These examples have now been rectified by explicitly restricting data.table to a single thread in all examples.

Other than that, the current CRAN version issues a single note regarding explicit C++ specification. This submission rectifies that, and generates no additional notes or warnings on:

* Ubuntu 22.04: R-oldrelease, R-release, R-devel
* Windows: R-release
* Mac-OS: R-release
* win-builder (R-release, R-devel, R-oldrelease)

C++ source code in package also generates no warnings with either Clang++ -Weverything or UBSAN
