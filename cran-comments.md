# CRAN notes for gtfsrouter_0.1.2 submission

This submission fixes UBSAN errors from previous, recent submission. It documents return values on all functions, as suggested in email from Benjamin Altmann, and also rectifies the package documentation in the man/ entry, as recommended in recent email from Kurt Hornik. The request to ensure user options are reset arises only from hard-coding 'data.table::setDTthreads(1L)' throughout entire package, as recently discussed at great length on r-pkg-devel mailing list. This re-submission also resets values to initial value of 'getDTthreads()', which should also rectify that issue.

Other than that, this submission generates no additional notes or warnings on:

* Ubuntu 22.04: R-oldrelease, R-release, R-devel
* Windows: R-release
* Mac-OS: R-release
* win-builder (R-release, R-devel, R-oldrelease)

C++ source code in package also generates no warnings with Clang++ -Weverything
