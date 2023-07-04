# CRAN notes for gtfsrouter_0.1.1 submission

Several attempts to re-submit this package have been rejected because the auto-checking service identified examples with "CPU time > 2.5 times elapsed time". I have ascertained that these ratios arise from filtering operations on large "data.table" objects, and not directly from this package. The main objects processed by this package are extensive lists of data.table objects. The only way to reduce these times has thus been to turn off all examples in the package. Minimal code which does not directly process the data.table objects has been left active.

Other than that, the current CRAN version issues a single note regarding explicit C++ specification. This submission rectifies that, and generates no additional notes or warnings on:

* Ubuntu 22.04: R-oldrelease, R-release, R-devel
* Windows: R-release
* Mac-OS: R-release
* win-builder (R-release, R-devel, R-oldrelease)

C++ source code in package also generates no warnings with either Clang++ -Weverything or UBSAN
