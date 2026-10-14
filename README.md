# Bayesian VAR structural breaks: paper replication

**Status: research work in progress — empirical reproduction NOT YET VERIFIED (C09).**

This repository is dedicated to the research paper derived from the author's thesis on Bayesian VARs with structural breaks and regime-specific blockwise lag uncertainty. It is **separate** from the [original thesis repository](https://github.com/MatteoGiuseppetti/bvar-structural-breaks-lag-selection), which remains unchanged.

## What the paper reports

- A single **three-break simulation** with four dispersed-start collapsed-MCMC chains.
- An empirical U.S. macroeconomic application (PCE inflation, unemployment, federal funds rate), baseline maximum lag order **K = 4**.
- A robustness exercise with **K = 8**, and residual diagnostics.

The current source under `code/reference/` is an **unaltered archival copy of the full thesis script**, which also contains experiments that are *not* included in the paper. This preserves provenance while a paper-only execution path is developed and validated. Do not interpret all experiments in that script as results reported in the article.

## Repository layout

| Path | Purpose |
| --- | --- |
| `code/reference/BVAR_thesis_full_code.R` | Byte-identical reference script from the thesis repository; **not refactored** |
| `data/raw/*.csv` | The three source CSV snapshots copied from the thesis repository |
| `scripts/check_inputs.R` | Basic, nonstatistical validation of the archived input files |
| `scripts/run_full_thesis.ps1` | Windows PowerShell runner for the **complete original script**, in an isolated results directory |
| `docs/PROVENANCE.md` | Original file sources and Git blob identifiers |
| `docs/REPLICATION_STATUS.md` | Verified facts, pending tests, and limitations |

## First steps (Windows PowerShell)

Requires a working **R** installation and the CRAN package `posterior`. No complete R version/package lockfile or end-to-end runtime has yet been certified.

From the repository directory:

~~~powershell
Rscript scripts/check_inputs.R
Rscript -e "if (!requireNamespace('posterior', quietly=TRUE)) install.packages('posterior')"
powershell -ExecutionPolicy Bypass -File scripts/run_full_thesis.ps1
~~~

The last command can be **computationally expensive**: it executes the **entire historical thesis script**, including experiments omitted from the article, and may take considerable time and memory. It saves generated files and logs in a timestamped `results/` directory (ignored by Git). Do not treat successful input checks as a replication of numerical results.

A validated, scoped paper-only runner will be added only after comparing the original outputs with the thesis and the paper (C09). Full numerical reproduction has **not** been carried out by the maintainer through this repository.

## Data and methodological notes

The data snapshots use FRED identifiers [PCECTPI](https://fred.stlouisfed.org/series/PCECTPI), [UNRATE](https://fred.stlouisfed.org/series/UNRATE) and [FEDFUNDS](https://fred.stlouisfed.org/series/FEDFUNDS). They are preserved from the thesis repository rather than re-downloaded, to avoid confounding replication with subsequent source-data revisions.

The baseline application has maximum lag order K=4 and excludes 2020Q2, together with all response rows whose required lag regressors would include that quarter; K=8 uses a correspondingly longer exclusion window. These are **conditional-likelihood exclusions**, not Bayesian imputations. Model evidence is profiled over break partitions; empirical break-count probabilities are **not** computed.

For exact file provenance and the difference between confirmed static checks and pending empirical checks, see [PROVENANCE](docs/PROVENANCE.md) and [REPLICATION_STATUS](docs/REPLICATION_STATUS.md).

## Availability and citation

The code repository is public while the manuscript is under development. **Publication in GitHub does not imply peer review or verified replication.** A paper citation, DOI, software release, and license have not yet been finalized. When ready, the paper will link to this separate repository.

Please do not cite this repository as an independently validated replication package until C09 and related checks are complete.
