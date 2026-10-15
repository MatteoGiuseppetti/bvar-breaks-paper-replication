# Fast, no-install preflight. Must run from the ARTICLE repository root.
root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
if (!file.exists(file.path(root, "renv.lock"))) {
  stop("Missing renv.lock: run scripts/restore_environment.R first.")
}
if (as.character(getRversion()) != "4.6.1") {
  stop("Expected R 4.6.1; found ", as.character(getRversion()), ".")
}
if (!requireNamespace("renv", quietly = TRUE)) {
  stop("Missing renv. Install renv, then run scripts/restore_environment.R.")
}
renv::load(project = root)
if (!requireNamespace("posterior", quietly = TRUE) ||
    as.character(utils::packageVersion("posterior")) != "1.7.0") {
  stop("Missing locked posterior 1.7.0. Run scripts/restore_environment.R.")
}
project_lib <- normalizePath(renv::paths$library(project = root), winslash = "/", mustWork = TRUE)
active_lib <- normalizePath(.libPaths()[1], winslash = "/", mustWork = TRUE)
if (!identical(project_lib, active_lib)) {
  stop("Unexpected R library: analysis would not use the project-local renv library.")
}
cat("PASS locked R environment: R ", as.character(getRversion()),
    "; posterior ", as.character(utils::packageVersion("posterior")), "\n", sep = "")
