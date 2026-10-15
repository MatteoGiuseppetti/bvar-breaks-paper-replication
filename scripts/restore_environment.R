# Run from the ARTICLE repository root using: Rscript --vanilla scripts/restore_environment.R
options(repos = c(CRAN = "https://cloud.r-project.org"))
root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
if (!file.exists(file.path(root, "renv.lock"))) {
  stop("Missing renv.lock; cannot claim a locked environment.")
}
if (as.character(getRversion()) != "4.6.1") {
  stop("This environment was frozen with R 4.6.1; current R is ", as.character(getRversion()))
}
if (!requireNamespace("renv", quietly = TRUE)) {
  stop("Install renv first: Rscript --vanilla -e \"install.packages('renv', repos='https://cloud.r-project.org')\"")
}
renv::restore(project = root, prompt = FALSE)
cat("DIAGNOSTIC: declared library: ", renv::paths$library(project = root), "\n", sep = "")
cat("DIAGNOSTIC: paths before load: ", paste(.libPaths(), collapse = " | "), "\n", sep = "")
cat("DIAGNOSTIC: installed project packages: ", paste(list.files(renv::paths$library(project = root)), collapse = ", "), "\n", sep = "")
renv::load(project = root)
cat("DIAGNOSTIC: paths after load: ", paste(.libPaths(), collapse = " | "), "\n", sep = "")
if (!requireNamespace("posterior", quietly = TRUE) ||
    as.character(utils::packageVersion("posterior")) != "1.7.0") {
  stop("Project environment must contain posterior 1.7.0.")
}
renv::status(project = root)
cat("PASS: R 4.6.1, posterior 1.7.0, restored project library.\n")
