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

## Pending scientific validation — C09

- [ ] Record precise R version, `posterior` version, operating system, run time, and peak resource requirements.
- [ ] Execute original source against archived CSVs; capture all output and ensure it exits successfully.
- [ ] Reproduce baseline profile log marginal likelihoods for break counts m=0,...,4.
- [ ] Match selected dates 1985Q1, 2008Q3, 2015Q4 and calendar/effective regime sizes.
- [ ] Reproduce modal models, model probabilities, lag inclusion probabilities (PIPs), and spectral radii.
- [ ] Reproduce all displayed equation-specific diagnostics and baseline restricted-OLS LM diagnostics.
- [ ] Reproduce the K=8 comparison, noting the effective-sample change.
- [ ] Reproduce the paper's *selected* three-break simulation and its MCMC posterior/diagnostic summaries, with fixed seeds.
- [ ] Compare all paper tables/figures against captured output, document rounding differences, and resolve discrepancies.
- [x] Extract and document a scoped paper-only runner while preserving original scientific statements (static mapping). 
- [ ] Execute the scoped runner and establish numerical equivalence with the original thesis program for the selected outputs.
- [ ] Freeze dependencies and publish a reproducible release only after checks pass.

## Pending editorial work — C07

The paper mentions Supplementary Material. That material has not been finalized, and the source code in this repository does not replace it. Decide with the adviser which thesis experiments belong in the Online Appendix.

## Nonclaims and scientific cautions

- Published Git files do **not** certify a successful empirical reproduction.
- The five profile break-count scores do not define posterior probabilities over break counts.
- The three-break MCMC simulation is one generated sample and does not establish general frequentist coverage.
- Changing K from 4 to 8 changes both the admissible lag-model set and the valid likelihood sample.
- A posterior-mean stability check does not prove stability across all posterior draws.
- Residual p-values are conventional post-selection diagnostics, not posterior predictive checks.

To report a successful C09, attach run logs, environment metadata, a machine-readable results comparison, and explicit pass/fail status for every check above.
