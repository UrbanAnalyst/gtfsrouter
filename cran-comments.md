# CRAN notes for gtfsrouter_0.1.1 submission

Current CRAN version issues single note regarding explicit C++ specification. This submission rectifies that, and generates no additional notes or warnings on:

* Ubuntu 22.04: R-oldrelease, R-release, R-devel
* Windows: R-release
* Mac-OS: R-release
* win-builder (R-release, R-devel, R-oldrelease)

C++ source code in package also generates no warnings with either Clang++ -Weverything or UBSAN

## valgrind memory leak

Testing with "valgrind --tool=memcheck --leak-check=full" reveals two **POSSIBLE** memory leaks, both due to code within `data.table` and not code within this submission.
