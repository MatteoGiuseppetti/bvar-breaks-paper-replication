# Reproducible R environment

## Reference setup

The original author-run C09 numerical verification used **Windows 11 x64, R 4.6.1, posterior 1.7.0**, LAPACK 3.12.1. The current `renv.lock` records **20 packages**, including `renv`, `posterior` and required indirect dependencies, under R 4.6.1. The version lock was generated on an R 4.6.1 runner; its indirect dependency versions are **not asserted to match exactly** every package historically installed in the author's C09 Windows environment.

This repository is exclusively for the **article and its supplementary experiments**. The original dissertation repository is a separate historical source, not needed for installation or execution.

## Restore from a clean checkout

Install R 4.6.1, then from the article repository root:

```powershell
Rscript --vanilla -e "install.packages('renv', repos='https://cloud.r-project.org')"
Rscript --vanilla scripts/restore_environment.R
Rscript --vanilla scripts/check_environment.R
Rscript --vanilla scripts/check_inputs.R
```

The restore script first activates the project-specific library before installing packages, checks R 4.6.1 and `posterior` 1.7.0, and reports `renv::status()`. Package downloads require a working CRAN repository/internet connection on the first restore; on some systems compilation toolchains may be required.

Run model code **only through the wrappers**:

```powershell
# Article
powershell -ExecutionPolicy Bypass -File scripts/run_paper.ps1 -Mode Empirical
powershell -ExecutionPolicy Bypass -File scripts/run_paper.ps1 -Mode Simulation

# Supplementary simulations (S7–S9)
powershell -ExecutionPolicy Bypass -File scripts/run_supplementary.ps1
```

Both wrappers activate the **same locked project environment** from isolated result directories. They never invoke the full dissertation code. Generated output files and results are ignored by Git.

## Verification limitations

The dependency restore and project-library checks previously passed on clean **Windows and Linux GitHub-hosted runners** (15 October 2026, [historical test](https://github.com/MatteoGiuseppetti/bvar-breaks-paper-replication/actions/runs/38755278460)). Those tests checked dependency installation, frozen inputs, original statement integrity and R parsing, **not** end-to-end model output. GitHub Actions workflows have since been removed by request; tests no longer run automatically.

The supplementary R file reproduces historical *source instructions* without editing them; executing it in the frozen environment and comparing its generated outputs to every Supplementary table/figure remain separate validations. Different OS, CPU math libraries or linear algebra implementations may give numerically different results. No bitwise equivalence is promised.

To deliberately change dependency versions, run a separately reviewed snapshot process rather than installing arbitrary current versions into the locked library. `renv.lock` should remain version controlled; local `renv/library` and generated `.Rprofile` must not be committed.
