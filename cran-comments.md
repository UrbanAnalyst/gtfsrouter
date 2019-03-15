# CRAN notes for gtfsrouter_0.0.1 submission

Sorry for previous NOTE regarding "no prebuilt vignette index" - that has now been fixed, and the only NOTE remains "New submission".  Other than that, this submission generates no notes or warnings on:

* Ubuntu 14.04 (on `travis-ci`): R-release, R-devel, R-oldrelease
* Windows Visual Studio 2015 (on `appveyor`; `x64`): R-release, R-devel
* win-builder (R-release, R-devel, R-oldrelease)

Package generates no warnings with Clang++ -Weverything

## valgrind memory leak

Testing with "valgrind --tool=memcheck --leak-check=full" reveals one **POSSIBLE** memory leak of around 2,000 bytes, which is due to data.table and not code within this submission. There are nevertheless no definite or indirect memory leaks whatsoever.
