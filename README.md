# Bayesian VAR structural breaks — paper replication

**Reproducibility materials for the article on Bayesian VAR structural breaks and regime-specific blockwise lag uncertainty.** This repository is dedicated to the **article only**. The dissertation is a separate, historical project: its R code and frozen CSV data were used as **source materials**, but this repository does not need to call, clone, or update the dissertation repository.

**Verification status (15 October 2026):** C09 author-executed numerical comparisons **PASS within the documented scope**. The paper-specific empirical and final three-break simulation routes and the historical full-source comparison were executed on Windows 11 / R 4.6.1 / `posterior` 1.7.0; compared quantities agree with the dissertation tables at reported precision. This does **not** establish independent third-party replication, bit-for-bit identity to unavailable historical artifacts, or cross-platform numerical equivalence. The separately tested **locked R dependency restore** passes on fresh GitHub Windows and Linux runners ([CI run](https://github.com/MatteoGiuseppetti/bvar-breaks-paper-replication/actions/runs/38754513020)); that CI does not run model estimation. See [C09 evidence](docs/C09_VERIFICATION_2026-10-15.md) and [replication status](docs/REPLICATION_STATUS.md).

## Scientific scope

The framework compares admissible structural-break configurations using regime-specific model-marginalized evidence from a conjugate Matrix-Normal–Inverse-Wishart BVAR. Candidate lag blocks can vary across regimes.

The **article** selects:
- One simulated three-break design analyzed with the **final**, dispersed-start collapsed MCMC (four chains; 150,000 iterations per chain, 25,000 burn-in).
- An empirical U.S. quarterly application involving PCE inflation, unemployment, and the federal funds rate; baseline maximum lag order **K=4** and robustness check **K=8**.

Other historical dissertation experiments do **not** belong to the paper-only execution path. This repository makes no claim that a single simulated dataset proves general frequentist recovery/coverage.

## Quick start — Windows PowerShell

Prerequisites: **R 4.6.1**, `Rscript` on `PATH`, **Python 3** for the static extraction audit, an internet connection **once** to install locked R dependencies, and Windows PowerShell. Use a clean clone of **this repository**. Packages are installed into a project-local `renv` library.

```powershell
git clone https://github.com/MatteoGiuseppetti/bvar-breaks-paper-replication.git
cd bvar-breaks-paper-replication

Rscript --version
Rscript --vanilla -e "install.packages('renv', repos='https://cloud.r-project.org')"
Rscript --vanilla scripts/restore_environment.R
Rscript --vanilla scripts/check_inputs.R
python scripts/audit_paper_extraction.py

# Fast relative to the simulation: empirical baseline and robustness
powershell -ExecutionPolicy Bypass -File scripts/run_paper.ps1 -Mode Empirical

# Very expensive: four 150,000-iteration MCMC chains
powershell -ExecutionPolicy Bypass -File scripts/run_paper.ps1 -Mode Simulation

# Run both only if needed
powershell -ExecutionPolicy Bypass -File scripts/run_paper.ps1 -Mode All
```

The runner **requires and activates the lockfile environment** even though it executes the model inside an isolated results directory. It checks R and `posterior` versions before starting a model. Never replace the lockfile silently with packages from the current CRAN release. See [R environment instructions](docs/ENVIRONMENT.md) for setup, troubleshooting, and limits.

**Outputs:** each run writes figures, logs, `session_info.txt`, and generated artifacts into its own `results/paper_<mode>_<timestamp>/` directory. These are ignored by Git. The simulation can take substantial time; a passing input audit or successful R parse is **not** a model-execution check.

## Repository map

| Location | Role |
| --- | --- |
| `code/paper/common.R` | Design, priors, segment evidence and shared numerical functions |
| `code/paper/simulation_functions.R` | MCMC and diagnostic functions |
| `code/paper/simulation_three_breaks.R` | **Final** article-selected three-break experiment |
| `code/paper/empirical_application.R` | Empirical **K=4** and **K=8** analyses |
| `code/paper/run_paper.R` | Scientific driver; sourced by the locked-environment wrapper |
| `scripts/run_paper.ps1` | Isolated Windows paper runner |
| `scripts/restore_environment.R` | Restore and check the project-local `renv` library |
| `scripts/check_environment.R` | Fail early on an un-restored or mismatched environment |
| `scripts/check_inputs.R` | Frozen CSV format/date checks |
| `scripts/audit_paper_extraction.py` | Source-statement and input-snapshot integrity audit |
| `code/reference/BVAR_thesis_full_code.R` | **Frozen provenance copy**, not imported or executed by paper runner |
| `data/raw/*.csv` | Frozen source snapshots; no runtime downloads |
| `renv.lock` | R package dependency versions, generated from an R environment |
| `docs/` | Source mapping, provenance, reproduction evidence and limitations |
| `.github/workflows/` | Static checks, R parsing and environment setup verification |

## Research integrity and provenance

The inputs are frozen copies of FRED series `PCECTPI`, `UNRATE`, and `FEDFUNDS`; **do not substitute new FRED downloads** to reproduce the archived results. October 2025 is missing from the archived unemployment snapshot and is handled by the original quarterly processing logic. The empirical 2020Q2 exclusion also applies to any response or lagged-predictor row containing that quarter. K=4 and K=8 have different effective samples.

The break-count comparisons are based on **profile/maximized** integrated marginal likelihood over partitions, not posterior probabilities fully integrated over break positions. Exact two-break/MCMC comparisons from historical experiments use a deliberately restricted local support. The paper code preserves these distinctions.

- [Source provenance](docs/PROVENANCE.md) — original script and CSV Git hashes, and separation of the two projects
- [Paper code map](docs/PAPER_CODE_MAP.md) — original source statements, selected and excluded blocks
- [C09 report](docs/C09_VERIFICATION_2026-10-15.md) — numerical evidence, environment and caveats
- [Numerical comparison CSV](docs/C09_NUMERICAL_COMPARISONS_2026-10-15.csv) — 49 representative checks
- [Replication status](docs/REPLICATION_STATUS.md) — completed gates and outstanding work

## Publication status

The manuscript and standalone Online Appendix are separate editorial drafts awaiting supervisor feedback; they have **not** been published into this repository as final accepted material. No journal-specific final citation, software license, immutable versioned release, DOI, third-party independent run or verified cross-platform reproduction is claimed. The full generated evidence archive is retained separately, not committed here.
