# Bayesian VARs with Structural Breaks — Article and Supplementary Code

This repository contains the **self-contained R code and frozen input data for the research article** on structural breaks and regime-specific blockwise lag uncertainty, along with the experiments documented in its Supplementary Material.

**Project boundary:** the dissertation is a **separate historical project**. Its code was consulted once to extract the *unchanged scientific statements* used here. There is no runtime dependency on that repository, no mirrored full thesis script and no full-thesis runner. The original dissertation repository is not part of this article's development workflow.

## Reproducible components

| Location | Purpose |
| --- | --- |
| `code/paper/common.R` | Prior, model integration and shared BVAR functions |
| `code/paper/simulation_functions.R` | MCMC and simulation diagnostics used in the article |
| `code/paper/simulation_three_breaks.R` | Final dispersed-start three-break simulation in the article (also Supplement S1–S3) |
| `code/paper/empirical_application.R` | Quarterly U.S. empirical analysis with K=4 and K=8 (also Supplement S4–S6) |
| `code/supplementary/simulation_experiments.R` | **Verbatim original** one-break, two-break/exact-vs-MCMC, and break-count simulation statements (Supplement S7–S9) |
| `scripts/run_paper.ps1` | Isolated paper execution: Empirical, Simulation, All |
| `scripts/run_supplementary.ps1` | Isolated supplementary simulation execution, independent of the paper route |
| `data/raw/` | Frozen `PCECTPI.csv`, `UNRATE.csv` and `FEDFUNDS.csv` snapshots |
| `renv.lock`, `renv/` | Locked R dependencies |
| `docs/ENVIRONMENT.md` | Environment setup and verification limitations |

**Important:** The supplementary R file preserves original instructions **unchanged**. It is the original contiguous source prefix, lines **1–2983**, ending before the thesis's three-break simulation. The supplementary runner only activates the locked environment, runs the preserved source in an isolated working directory and saves output objects afterward. No likelihood, prior, proposal, random seed, search grid or MCMC setting has been rewritten.

The Supplementary PDF describes *existing* thesis figures and tables; code execution may produce the underlying numeric evidence and original plotting calls, but it is **not** a pixel-identical regeneration of the typeset Supplementary PDF. No fresh MCMC or numerical comparison is claimed from the present repository reorganization.

## Quick start: Windows PowerShell

Install **R 4.6.1**, make `Rscript` available on `PATH`, and clone **this** repository. First install `renv` and restore the **20 pinned packages** (`posterior` 1.7.0 and its dependencies included):

```powershell
git clone https://github.com/MatteoGiuseppetti/bvar-breaks-paper-replication.git
cd bvar-breaks-paper-replication
Rscript --vanilla -e "install.packages('renv', repos='https://cloud.r-project.org')"
Rscript --vanilla scripts/restore_environment.R
Rscript --vanilla scripts/check_environment.R
Rscript --vanilla scripts/check_inputs.R

# Main article empirical application: K=4 and K=8
powershell -ExecutionPolicy Bypass -File scripts/run_paper.ps1 -Mode Empirical

# Main article: final three-break, four-chain MCMC (computationally intensive)
powershell -ExecutionPolicy Bypass -File scripts/run_paper.ps1 -Mode Simulation

# Supplementary historical simulations: S7, S8, S9 (computationally intensive)
powershell -ExecutionPolicy Bypass -File scripts/run_supplementary.ps1
```

The paper and supplementary runners write to independent, ignored `results/paper_<mode>_<timestamp>/` and `results/supplementary_<timestamp>/` directories. The supplementary runner captures a log, records `session_info.txt` and saves the generated `results` (one-break) and `results_2b` (two-break/MCMC/model-selection) objects as separate RDS files. It does not run the article's three-break model or empirical analysis.

For `renv` troubleshooting and platform limitations see [Environment](docs/ENVIRONMENT.md).

## Interpretation and verification

On **15 October 2026**, author-executed numerical comparison of selected article outputs against the original dissertation **passed at reported table precision** under Windows 11 / R 4.6.1 / `posterior` 1.7.0. This is not a third-party replication or proof of bitwise/cross-platform numerical equivalence. A subsequent clean dependency restore and syntax/input checks passed on hosted Windows and Linux; those checks did **not** rerun the estimators.

The previous internal validation reports (C09), statement-extraction mapping and original full-script copy have been removed from the **current repository tree** to focus on article deliverables. Previous records remain available through ordinary Git history, for example the [historical C09 report](https://github.com/MatteoGiuseppetti/bvar-breaks-paper-replication/blob/8a77692825366d52ec14987210de7a166be40c91/docs/C09_VERIFICATION_2026-10-15.md). **There are no GitHub Actions workflows** in the current tree; checks must be run manually.

The preserved inputs are the exact archived FRED snapshots (do not substitute newly downloaded series). The paper's empirical break-count criterion profiles integrated evidence over admissible partitions; it does not calculate a fully integrated posterior over break counts. The two-break exact-vs-MCMC experiment uses a deliberately **restricted local break grid**. One simulated DGP does not establish repeated-sampling coverage.

### Scientific source and provenance

The supplementary experiment file is verbatim from historical `BVAR_thesis_full_code.R` lines 1–2983; the complete historical script's **Git blob SHA-1** is `85aee115a241877bfdca9deb53eb12bde0ce6cc3`. The existing article files also descend from that same original implementation. This hash and the linked historical Git record establish source provenance without requiring the dissertation repository to be cloned or executed.

The manuscript and standalone Supplementary Material remain subject to the professor's editorial feedback. No journal acceptance, independently certified numerical reproduction, versioned release, license or DOI is asserted.
