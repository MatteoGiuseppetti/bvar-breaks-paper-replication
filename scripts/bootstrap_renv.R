# Maintainer/CI-only: build a package-version lock on a clean R 4.6.1 runner.
# This does NOT execute or change the scientific code.
options(repos = c(CRAN = "https://cloud.r-project.org"))
if (as.character(getRversion()) != "4.6.1") {
  stop("Lockfile generation must use exactly R 4.6.1.")
}
if (!requireNamespace("renv", quietly = TRUE)) {
  stop("Install the CRAN renv package before calling this script.")
}
if (!file.exists("code/paper/run_paper.R")) {
  stop("Run this script from the article repository root.")
}
# Fresh GitHub runner: create a project-local library, then snapshot only
# the packages used by the paper and their transitive dependencies.
renv::init(project = getwd(), bare = TRUE, restart = FALSE)
renv::install("posterior@1.7.0", project = getwd())
if (as.character(utils::packageVersion("posterior")) != "1.7.0") {
  stop("Unable to install the documented posterior 1.7.0 version.")
}
renv::settings$snapshot.type("implicit", project = getwd())
renv::snapshot(project = getwd(), type = "implicit", prompt = FALSE)
if (!file.exists("renv.lock")) stop("renv.lock not generated.")
cat("Generated a project lock with R 4.6.1 and posterior 1.7.0.\n")
