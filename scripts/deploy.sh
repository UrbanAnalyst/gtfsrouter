#!/usr/bin/env bash

Rscript -e "covr::codecov(function_exclusions='plot.gtfs_isochrone')"
Rscript -e "pkgdown::deploy_site_github()"
