# Reproduction status and acceptance gates

As of **2026-10-14**, this repository is a **work in progress**, with paper-only code extracted but numerical results still unverified. The original thesis code and the three input CSV snapshots have been transferred with matching Git blob hashes. This establishes file provenance, **not** numerical reproducibility.

## Completed static checks

- [x] New paper repository separate from the thesis repository.
- [x] Original thesis repository remains unchanged.
- [x] Copied R script byte-identical to the original thesis script.
- [x] Copied input CSVs byte-identical to the original thesis versions.
- [x] Reviewed the top-level external package dependency: the source calls `posterior::rhat`, `posterior::ess_bulk`, and `posterior::ess_tail`; remaining numerical functions use R and recommended/base packages.
- [x] Confirmed UNRATE has no usable October 2025 entry in the archived snapshot; November and December observations are present.
- [x] Documented that the archived original R script runs the full thesis program, not just the paper subset.
- [x] Extracted separate paper-only code paths: final three-break dispersed-start simulation, baseline K=4 and robustness K=8.
- [x] GitHub Actions CI: statement-level extraction and input-snapshot SHA tests **PASSED**; all five paper-only R scripts **PARSED** successfully using R on a GitHub-hosted runner (2026-10-14). This is not an execution of the estimators.
- [x] Preserved original scientific source ranges in the extracted modules and added a source-fidelity audit (not an R runtime validation).

## Completed user-executed numerical verification — C09 (2026-10-15)

- [x] R 4.6.1, `posterior` 1.7.0, Windows 11 x64 (build 26200) and LAPACK 3.12.1 recorded. Elapsed runtime and peak memory were **not measured**.
- [x] Original thesis R program ran against archived CSV snapshots and exited successfully; original full-run log and generated figures were reviewed.
- [x] Paper-only empirical driver executed; baseline profile log marginal likelihoods for m=0,...,4 and dates 1985Q1 / 2008Q3 / 2015Q4 reproduced.
- [x] Baseline calendar/effective regime sizes, modal models, model probabilities, all displayed PIPs, stability measures and univariate/LM diagnostic tables compared to thesis/manuscript (published precision).
- [x] K=8 robustness results compared, explicitly preserving the different effective sample.
- [x] Paper's selected three-break simulation ran with four 150,000-iteration chains and fixed seeds; posterior summaries, gamma models, acceptance rates, R-hat and ESS compared.
- [x] Additional thesis simulations (one break, two breaks, exact-vs-MCMC, m=0/1/2 selection) executed and printed summaries compared at published precision.
- [x] Final simulation output from paper-only runner and corresponding original thesis run compared; matching numeric log span and final summary documented.
- [x] Plots qualitatively checked, *not* verified pixel for pixel.
- [x] Evidence manifest, user-delivered ZIP archive, and [49-row machine-readable comparison summary](C09_NUMERICAL_COMPARISONS_2026-10-15.csv) prepared. The public repo tracks the manifest/report and CSV **but not the full generated evidence ZIP**.

### Provenance / limitations intentionally left open

- [ ] Measure wall-clock runtime and peak resource demands on reference hardware (not needed for the fixed-run numerical comparison).
- [ ] Archive locally the **not-uploaded** `simulation_three_breaks_final.rds` (2,483,259 bytes; user-reported SHA-256 recorded in the C09 report), together with the delivered ZIP.
- [ ] Record original empirical `run.log` and `session_info.txt` if retained; they were not uploaded, although the empirical RDS and plots were independently supplied.
- [ ] Freeze dependencies and test a versioned release across a second, independent environment. **Not claimed completed.**
- [ ] Compare bitwise against original historical run artifacts if these become available; the thesis tables show rounded numbers only.

### Interpretation

**C09 numeric gate: PASS, fixed inputs and author-run environment.** No discrepancies were found in the reported-precision outputs compared. This is a traceable user-executed replication; no third-party independent run and no proof of broader sampler validity. The historical preliminary three-break run (poor diagnostics) is distinct from the final 150,000-iteration experiment.

## Editorial work — C07 (independent from C09)

A standalone Online Appendix draft covering the omitted thesis simulation experiments has been prepared. It remains subject to adviser review and publication decisions; source-code availability in this repository is not a substitute for editorial approval.

## Nonclaims and scientific cautions

- Static Git file provenance alone does **not** establish numerical reproduction; the scope-limited numerical finding is instead supported by the author-executed logs/RDS and thesis comparison in the C09 report.
- The five profile break-count scores do not define posterior probabilities over break counts.
- The three-break MCMC simulation is one generated sample and does not establish general frequentist coverage.
- Changing K from 4 to 8 changes both the admissible lag-model set and the valid likelihood sample.
- A posterior-mean stability check does not prove stability across all posterior draws.
- Residual p-values are conventional post-selection diagnostics, not posterior predictive checks.

For the full original outputs and original-byte SHA-256 manifest, preserve the user-delivered evidence archive separately: generated RDS/log/PDF outputs are intentionally ignored by Git. This repository publishes a numerical comparison report and machine-readable summary, not a complete public release of those run artifacts.
