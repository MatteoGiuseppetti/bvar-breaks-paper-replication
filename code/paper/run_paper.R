# Intended entry point: scripts/run_paper.ps1 (isolated results directory).
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L || !(args[1] %in% c("simulation", "empirical", "all"))) {
  stop("Usage: Rscript code/paper/run_paper.R simulation|empirical|all")
}
repo_root <- Sys.getenv("BVAR_PAPER_REPO_ROOT", unset = NA_character_)
if (is.na(repo_root) || !nzchar(repo_root)) {
  stop("Set BVAR_PAPER_REPO_ROOT to the absolute repository path, or use scripts/run_paper.ps1")
}
if (!requireNamespace("posterior", quietly = TRUE)) {
  stop("Missing R package 'posterior'; install.packages('posterior')")
}
source(file.path(repo_root, "code", "paper", "common.R"), local = FALSE)
if (args[1] %in% c("simulation", "all")) {
  source(file.path(repo_root, "code", "paper", "simulation_functions.R"), local = FALSE)
  source(file.path(repo_root, "code", "paper", "simulation_three_breaks.R"), local = FALSE)
}
if (args[1] %in% c("empirical", "all")) {
  needed <- c("PCECTPI.csv", "UNRATE.csv", "FEDFUNDS.csv")
  if (any(!file.exists(needed))) stop("Missing raw CSV(s) in the working directory")
  source(file.path(repo_root, "code", "paper", "empirical_application.R"), local = FALSE)
}
cat("Paper-specific R run completed. Numerical comparison to the manuscript remains necessary.\n")
