# Executed inside the per-run results directory, with BVAR_PAPER_REPO_ROOT set.
# Only environment activation is added; paper source is unchanged.
root <- Sys.getenv("BVAR_PAPER_REPO_ROOT", unset = "")
if (!nzchar(root)) stop("BVAR_PAPER_REPO_ROOT must be set by scripts/run_paper.ps1.")
root <- normalizePath(root, winslash = "/", mustWork = TRUE)
run_dir <- getwd()
if (as.character(getRversion()) != "4.6.1") stop("Use R 4.6.1 for this project.")
if (!requireNamespace("renv", quietly = TRUE)) stop("Install renv, then restore the lock.")
renv::load(project = root)
setwd(run_dir)
if (!requireNamespace("posterior", quietly = TRUE) ||
    as.character(utils::packageVersion("posterior")) != "1.7.0") {
  stop("Expected locked posterior 1.7.0, restore the project first.")
}
source(file.path(root, "code", "paper", "run_paper.R"), local = FALSE)
