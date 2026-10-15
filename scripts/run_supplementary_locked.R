# Output-management wrapper only. Scientific R statements are preserved verbatim.
root <- Sys.getenv("BVAR_PAPER_REPO_ROOT", unset = "")
if (!nzchar(root)) stop("Launch via scripts/run_supplementary.ps1")
root <- normalizePath(root, winslash = "/", mustWork = TRUE)
run_dir <- getwd()
if (as.character(getRversion()) != "4.6.1") stop("Use R 4.6.1.")
if (!requireNamespace("renv", quietly = TRUE)) stop("Missing renv package.")
renv::load(project = root)
setwd(run_dir)
if (!requireNamespace("posterior", quietly = TRUE) ||
    as.character(utils::packageVersion("posterior")) != "1.7.0") {
  stop("Restore locked posterior 1.7.0 first.")
}
# The original begins with rm(list=ls()); isolating it in a new environment
# keeps runner/output settings outside that historical code.
experiment_env <- new.env(parent = globalenv())
source(file.path(root, "code", "supplementary", "simulation_experiments.R"),
       local = experiment_env, echo = FALSE, chdir = FALSE)
if (!exists("results", envir = experiment_env, inherits = FALSE) ||
    !exists("results_2b", envir = experiment_env, inherits = FALSE)) {
  stop("Expected original one-break or two-break results objects were not created.")
}
saveRDS(get("results", envir = experiment_env, inherits = FALSE),
        file = "supplementary_one_break_results.rds")
saveRDS(get("results_2b", envir = experiment_env, inherits = FALSE),
        file = "supplementary_two_break_and_selection_results.rds")
cat("Saved supplementary results without altering any original scientific instructions.\n")
