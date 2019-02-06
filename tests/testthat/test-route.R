context("route")

test_all <- (identical (Sys.getenv ("MPADGE_LOCAL"), "true") |
             identical (Sys.getenv ("TRAVIS"), "true"))

source ("../make-zip.R")

test_that("route", {
})
