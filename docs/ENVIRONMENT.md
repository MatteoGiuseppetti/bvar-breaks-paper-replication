# Reproducible R environment for the paper

## Recorded reference and scope

The **C09 comparison environment** (run by the author on 2026-10-15) was Windows 11 x64, R **4.6.1** (UCRT), `posterior` **1.7.0**, LAPACK 3.12.1. The underlying R code uses `posterior::rhat`, `posterior::ess_bulk` and `posterior::ess_tail`; `posterior` has indirect package dependencies.

The tracked `renv.lock` freezes the versions in a separate environment **generated on GitHub Actions with R 4.6.1**. That dependency graph is intended to make the article reproducible independently of whichever R packages happen to be installed globally. It does **not** claim the entire indirect package inventory was historically identical to the author's Windows C09 library, or that numerical results on a different OS/BLAS will be bitwise identical. The source modules, input snapshots and inference settings are not changed by this environment work.

## Install from a clean clone

In **Windows PowerShell**, after installing R 4.6.1 and cloning the article repository:

```powershell
cd bvar-breaks-paper-replication
Rscript --version
Rscript --vanilla -e "install.packages('renv', repos='https://cloud.r-project.org')"
Rscript --vanilla scripts/restore_environment.R
Rscript --vanilla scripts/check_inputs.R
python scripts/audit_paper_extraction.py
```

`restore_environment.R` refuses a different R version, requires `renv.lock`, installs the pinned package versions into the project-specific library, verifies the selected package version, and reports `renv::status()`. This requires internet/package availability on the first run. A separate operating-system toolchain may be needed for source package compilation.

**Run the article only through the wrapper** (from any directory):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_paper.ps1 -Mode Empirical
powershell -ExecutionPolicy Bypass -File scripts/run_paper.ps1 -Mode Simulation
```

The runner checks the lockfile and project library from the repository root and then activates the same project library in the isolated `results/` working directory, despite using `Rscript --vanilla`. No global fallback to an arbitrary `posterior` is accepted by the preflight.

## Updating the environment

Do **not** change `renv.lock` simply to receive newer packages. The repository includes `scripts/bootstrap_renv.R` and a dedicated GitHub workflow to **generate** a lockfile with R 4.6.1 and `posterior` 1.7.0; updates require an explicit new review and new runtime verification. This is **not** a request to change the scientific model.

The `renv/` project library, caches and staging files must remain untracked. The tracked `renv.lock` is the dependency record, while a generated `.Rprofile` is local-only: launch restoration and analysis using the explicit scripts above.

## Clean-runner installation evidence

On **2026-10-15**, [GitHub Actions clean restore](https://github.com/MatteoGiuseppetti/bvar-breaks-paper-replication/actions/runs/38754513020) completed successfully on both `ubuntu-latest` and `windows-latest` with R 4.6.1. Each job restored the lock, checked the project-local library and `posterior` version, checked CSV contents and original-byte hashes, and parsed the article R code. This certifies **environment setup on those CI runners**, not equality of estimated outputs.

## What has and has not been verified

- **C09 already passed** for the author's original fixed-source Windows run and reported-precision comparisons to thesis tables; see the separate C09 report.
- `renv` lock generation and restoration are *environment engineering checks*. A successful restore, R syntax parse, or input audit does not re-run either estimator.
- Independent clean-machine execution of **both** paper modes using the **locked** library and numerical comparison to expected outputs is a separate, still-open validation step. Cross-platform equivalence and bitwise historical identity must not be inferred from a dependency lock.
