# Replication status and acceptance gates

**State on 2026-10-15 — article repository only.** The dissertation is a separate historical project used as the source of copied statements/data, not as a linked development environment or operational dependency.

## Scientific verification: C09 (already completed in the documented scope)

**C09 numerical comparison: PASS** for the author's **fixed-source, fixed-data, Windows 11 / R 4.6.1** executions, as established before this documentation/environment update. The selected paper simulation and empirical paths and the original full-source comparison were executed, and the compared numerical values matched dissertation tables at their published precision.

- [C09 report: exact evidence, versions, sources and limitations](C09_VERIFICATION_2026-10-15.md)
- [49-row comparison summary](C09_NUMERICAL_COMPARISONS_2026-10-15.csv)

This is **not** independent third-party replication, a bit-for-bit comparison with unavailable historical run outputs, cross-platform reproducibility, a software release or proof of statistical consistency.

The full historical run served as a **one-time source-validation comparison**: it is not an article runtime prerequisite. The public article repository contains a frozen reference copy, but the executable paper path is `code/paper/` only.

## Source and input integrity

- [x] Distinct article-only execution path, no runtime clone/import from the thesis repository.
- [x] Frozen copy of complete historical R script for statement-level comparison.
- [x] Frozen PCECTPI/UNRATE/FEDFUNDS input snapshots.
- [x] Statement-level source extraction audit.
- [x] GitHub Actions static extraction, input-hash and R syntax checks passed on 2026-10-14.
- [x] Selected three-break final-chain simulation and empirical K=4/K=8 results checked under C09.
- [x] C09 report, original-artifact hash manifest and 49 representative numerical comparisons documented.

`scripts/check_inputs.R` checks input structures and special missingness, not fitted model results. `scripts/audit_paper_extraction.py` checks copied statements and Git blob hashes, not runtime semantics.

## R environment engineering (separate from scientific C09)

- [x] Reference R version **4.6.1** and direct external dependency `posterior` **1.7.0** identified from the C09 environment.
- [x] Project-local `renv` restoration/check scripts and locked-library paper runner added, without altering scientific R model statements.
- [x] Generated and committed `renv.lock` (R 4.6.1, `posterior` 1.7.0, 20 total packages), tracking direct and required transitive dependencies.
- [x] Fresh Windows and Linux GitHub-hosted runners both restored the locked library and passed input CSV **byte-hash**, source-extraction and R syntax checks ([successful CI execution](https://github.com/MatteoGiuseppetti/bvar-breaks-paper-replication/actions/runs/38754513020)). **No model estimation was run in CI.**
- [ ] Independent clean Windows/Linux **full article numerical run using the new lock** and result-by-result comparison. **Not certified by lock generation.**
- [ ] Historical Windows indirect-dependency inventory comparison (not available in the original C09 evidence).

See [environment setup](ENVIRONMENT.md). Package versions are now pinned in the generated, committed and clean-runner-tested `renv.lock`. This verifies the **package environment**, not independent numerical reproduction of the paper.

## Provenance and work still open

- [ ] Preserve the original user-delivered full evidence ZIP and the separately retained `simulation_three_breaks_final.rds` (2,483,259 bytes) locally.
- [ ] Recover the original empirical run log and session metadata, if available; C09 assessed its RDS/figures without them.
- [ ] Optionally measure runtime and peak memory on reference hardware.
- [ ] Optionally test the locked package setup and numerical output on a second independent system, prior to versioned release.
- [ ] Release metadata: citation, license, version/DOI and any journal-required format to be decided after editorial feedback.
- [ ] Compare bitwise to historical reference artifacts *only if those artifacts later become available*.

## Editorial status: separate from code

The article manuscript and standalone Online Appendix are drafted but **not final, approved or published to this repository**. The pending supervisor review and eventual journal decisions do not change C09's documented numerical outcome. No publication of manuscript files is authorized by this documentation update.

## Scientific nonclaims

- Empirical break-count scores maximize/profile integrated marginal likelihood across partitions; they are **not** posterior break-count masses integrated over all partitions.
- The old exact two-break benchmark compares exact vs MCMC on a **restricted local support**, not the full global space.
- The selected final three-break result is from one generated dataset and does not establish frequentist coverage; its second break has comparatively weaker tail mixing.
- K=8 changes both admissible model dimension and effective valid likelihood rows relative to K=4.
- Posterior-mean stability checks are not stability statements about every posterior draw.
- Conventional post-selection residual diagnostics are not posterior predictive checks.
