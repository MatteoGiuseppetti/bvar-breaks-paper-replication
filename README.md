# Bayesian VAR structural breaks — paper replication code

**Paper-only code is available. Numerical equality with the manuscript has not been independently verified through this repository.** The original thesis repository remains unchanged.

## Two distinct projects

- **This repository:** [bvar-breaks-paper-replication](https://github.com/MatteoGiuseppetti/bvar-breaks-paper-replication) — *paper-only* code, original input-data snapshots, source mapping and execution instructions.
- **Historical thesis repository:** [bvar-structural-breaks-lag-selection](https://github.com/MatteoGiuseppetti/bvar-structural-breaks-lag-selection) — the entire thesis research script and dataset snapshots, retained intact.

The paper investigates Bayesian VARs with structural breaks and **regime-specific blockwise lag uncertainty**. The selected simulation is **one three-break DGP** with four dispersed-start collapsed-MCMC chains. The empirical application estimates **K=4** and examines **K=8** robustness for U.S. inflation, unemployment, and the federal funds rate.

## What to run

For **Windows PowerShell**, install R and the required CRAN package `posterior`, then in the cloned repository directory:

~~~powershell
Rscript --version
Rscript -e "if (!requireNamespace('posterior', quietly=TRUE)) install.packages('posterior')"
Rscript scripts/check_inputs.R
python scripts/audit_paper_extraction.py

# Empirical application: baseline K=4 and robustness K=8
powershell -ExecutionPolicy Bypass -File scripts/run_paper.ps1 -Mode Empirical

# The PAPER's selected simulation: four chains, 150000 MCMC iterations each (SLOW)
powershell -ExecutionPolicy Bypass -File scripts/run_paper.ps1 -Mode Simulation

# Both routes, if needed
powershell -ExecutionPolicy Bypass -File scripts/run_paper.ps1 -Mode All
~~~

The first two audit commands check **input format and source-code extraction only**. They do not estimate a model. `-Mode Empirical` is the default and does **not** run thesis-only simulations.

All generated outputs, run logs, session metadata and figures go to separate, ignored `results/paper_<mode>_<timestamp>/` directories. The simulation can be computationally demanding: the final sampler performs 4 × 150,000 iterations. Do not start it expecting a quick smoke test.

## Files

| Path | Description |
| --- | --- |
| `code/paper/common.R` | Prior, integrated marginal likelihood, design and model helpers extracted from original code |
| `code/paper/simulation_functions.R` | Multi-break sampler, diagnostics and plotting functions |
| `code/paper/simulation_three_breaks.R` | Only the **final three-break** simulation reported in the paper |
| `code/paper/empirical_application.R` | **Entire K=4 / K=8 empirical section**, as in the thesis |
| `code/paper/run_paper.R` | R driver for paper-only modules |
| `scripts/run_paper.ps1` | Windows isolated runner with `Empirical`, `Simulation` and `All` modes |
| `scripts/audit_paper_extraction.py` | Tests source/data Git hashes and statement-level fidelity |
| `code/reference/BVAR_thesis_full_code.R` | Unmodified original script for traceability; **not** the paper-only run route |
| `data/raw/` | Original FRED CSV snapshots |
| `docs/PAPER_CODE_MAP.md` | Exact original source-line map and inclusion/exclusion decisions |
| `docs/REPLICATION_STATUS.md` | Verification checklist and limitations |

An optional legacy runner, `scripts/run_full_thesis.ps1`, executes **all** thesis experiments. It is **not** part of the paper-only workflow.

## Data and methodological fidelity

The original CSV snapshots for [PCECTPI](https://fred.stlouisfed.org/series/PCECTPI), [UNRATE](https://fred.stlouisfed.org/series/UNRATE) and [FEDFUNDS](https://fred.stlouisfed.org/series/FEDFUNDS) were copied from the thesis repository, **not** re-downloaded. October 2025 is missing from the archived UNRATE series; the original quarterly conversion uses available months if there are at least two.

In the empirical likelihood, 2020Q2 is excluded with any row for which it is a response or a lagged predictor (a common lag-model mask). The break-count scores use **maximized/profile** integrated marginal likelihoods over partitions, not fully integrated break-count posteriors. K=4 and K=8 use different effective sample sizes.

The paper-only code reuses unchanged original source statements (aside from line-ending normalization and file-output additions). **Code extraction is not yet an R execution result or a numerical replication certificate.** See [source mapping](docs/PAPER_CODE_MAP.md), [provenance](docs/PROVENANCE.md) and [replication status](docs/REPLICATION_STATUS.md).

No definitive versioned software release, license or journal citation has yet been assigned. Until C09 evidence is assembled, cite this as an in-progress paper-code repository, not as a certified replication package.
