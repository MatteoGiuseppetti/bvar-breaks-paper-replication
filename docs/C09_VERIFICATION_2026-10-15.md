# C09 — evidence-scoped numerical reproduction (2026-10-15)

**Status: PASS — user-executed, thesis-referenced numerical comparison for the paper's selected results and the full historical thesis script.** This closes the *numerical execution and comparison* portion of C09 on the documented Windows/R setup. It does **not** certify bitwise equality with unavailable historical run artifacts, cross-platform reproducibility, statistical validity, resource requirements, or a versioned software release.

## Provenance and execution

- Baseline source revision reported and statically audited by the user: `b7f4d3372f8bcbb2843cb0c76040cff7dc597c94`.
- The user ran `python scripts/audit_paper_extraction.py` successfully after restoring literal LF CSV bytes. The working tree was subsequently clean; none of the source R statements or archived CSV observations was altered for this check.
- Input snapshot Git blob hashes: `PCECTPI.csv` `ae36637e704c23483db0ab1da5057f553eaed88b`; `UNRATE.csv` `16ec96fb08abc50c088d6b8f9fcacda18d80daa3`; `FEDFUNDS.csv` `8d52898492df6a8587d69a3425686c73b205e742`.
- Environment: Windows 11 x64 build 26200; R 4.6.1 (UCRT); `posterior` 1.7.0; LAPACK 3.12.1. `environment.log` is empty in the historical runner because its `sessionInfo()` is written to `session_info.txt`.
- **Paper empirical**: `powershell -ExecutionPolicy Bypass -File scripts/run_paper.ps1 -Mode Empirical` -> `results/paper_empirical_20261015_105034/`. The RDS and nine-page PDF were supplied and assessed; the original log/session metadata for this run were not supplied.
- **Paper selected simulation**: `powershell -ExecutionPolicy Bypass -File scripts/run_paper.ps1 -Mode Simulation` -> `results/paper_simulation_20261015_115523/`. Four dispersed-start 150,000-iteration chains, 25,000 burn-in iterations, seeds 1001–1004; log, session metadata and two figures supplied.
- **Full thesis source**: `powershell -ExecutionPolicy Bypass -File scripts/run_full_thesis.ps1` -> `results/full_original_20261015_123004/`. Full historical program exited successfully; log, session metadata, 18-page plot PDF supplied. Terminal also reported `Technical checks: ALL PASSED`.

## Numerical comparisons with the thesis (at published precision)

| Thesis result | User-run observation | Result |
|---|---|---|
| One-break unknown breakpoint, Chapter 5 | MAP 2002; mean 2003.28; SD 2.74; 95% CI [2000,2010]; true lag pair 101/010 recovered | PASS |
| Two-break exact local scan | MAP 796/1599; lag models 101/010/110; local 31×31 support | PASS |
| Exact-vs-MCMC comparisons, thesis Tables 5.1–5.5 | Reported posterior means, inclusion quantities, diagnostics, acceptance and distance summaries match after rounding | PASS |
| Break-count selection, thesis Table 5.6 | Profile log ML m=0: -6959.975, m=1: -6864.574, m=2: -6722.867; selected m=2 | PASS |
| Final three-break MCMC, thesis Tables 5.7–5.10 | Means 791.3121 / 1602.4603 / 2398.1205; modes 787 / 1600 / 2397; 95% equal-tailed CIs [785,803] / [1571,1627] / [2388,2407] | PASS |
| Final three-break lag selection | True/modal gammas 100 / 010 / 001 / 110; corresponding true-model masses 0.977672 / 0.934100 / 0.895784 / 0.988524 | PASS |
| Baseline K=4, thesis Tables 6.1–6.7 | Profile log ML m=0…4: -786.0830 / -714.6706 / -709.9439 / -690.8014 / -698.0518; selected dates 1985Q1, 2008Q3, 2015Q4; modals 1010/1111/1111/1111; associated PIPs, diagnostics and stability values match | PASS |
| Robustness K=8, thesis Table 6.8 | Selected m=3, same dates; modal gammas 10110100/11100110/11110111/11110011 and reported stability/diagnostic values match | PASS |

The final simulation output from the *paper-only* path and the corresponding final block of the full thesis run agree numerically: the 3,241-character normalized central diagnostics span (beginning with seed 1001 and ending at the gamma-recovery header) was identical, and the subsequent recovery summaries/CIs matched. This is **execution-level** agreement for the compared quantities, not merely static source matching.

**Do not confuse runs.** The full historical code also ran a **preliminary** three-break sampler with poor second-break diagnostics (`R-hat = 1.185382`, bulk-ESS `17.86628`, tail-ESS `64.77025`). These are not the final study results. The final four-chain run gave second-break `R-hat = 1.004964`, bulk-ESS `882.072`, tail-ESS `395.8172`, exactly as printed in the thesis. The second break remains less efficiently sampled in the tails; reproduction does not remove that scientific caveat.

## Evidence manifest (SHA-256, original uploaded bytes)

| Run | Original artifact | SHA-256 |
|---|---|---|
| paper empirical | `BVAR_real_data_final_results.rds` | `0de3395ab423119dd42ded22f60fb346d4536d32e803429207c6ae25161a2a7e` |
| paper empirical | `Rplots.pdf` | `b302b15591fb5b5076d56ddadc2b6f7d6cece0efaf750d52cc7c15d67dc0e0ff` |
| paper simulation | `run.log` (UTF-16LE) | `8696e1851fb1cf7fb3464007f932bea49e4b96d0b082ac0d36527c031941b27c` |
| paper simulation | `session_info.txt` | `b2bdbb9e9a1e3e31d511c3e3875a6db88950d1bfabf4bcb96b09fb919d97065d` |
| paper simulation | `simulation_three_breaks_trace.pdf` | `eb68150eb93311f6f628119ab2af2e73ef393b75e57c425afe69eb8fb5e2df01` |
| paper simulation | `simulation_three_breaks_break_posteriors.pdf` | `d916117d799af2aa0e34de8864501b4b677b909f1d0886e5a7c8644469814fde` |
| full thesis | `run.log` (UTF-16LE) | `36304e9b98e6fd70dd3a4f8379bbdf8480c9a49ce91c9bb8a8799f30ec530114` |
| full thesis | `session_info.txt` | `b2bdbb9e9a1e3e31d511c3e3875a6db88950d1bfabf4bcb96b09fb919d97065d` |
| full thesis | `Rplots.pdf` | `f9a9c660138314ab092f25ca17563754f83a46b60d39467c6e75ed2e1943d103` |

The simulation `simulation_three_breaks_final.rds` was confirmed **locally by the user** (2,483,259 bytes); its *user-reported*, not independently re-hashed SHA-256 is `448CD47A944389608DAB8077BAFF7541DAA4079422919EFED0D52647D008800E`. The file was not uploaded for the evidence archive. Preserve it locally.

Evidence files (including original UTF-16LE logs, PDFs, the supplied empirical RDS, a SHA-256 manifest, and the three detailed C09 reports) were bundled into a separate **user-delivered evidence ZIP**; that ZIP is **not committed to this public GitHub repository**. The small [machine-readable comparison summary](C09_NUMERICAL_COMPARISONS_2026-10-15.csv) covers 49 representative checks; detailed source-to-output assessments are in the delivered reports. PDF figure checks were qualitative, not pixel-exact.

## Distinctions and remaining nonclaims

- **Numerical C09:** closed for this fixed-source, fixed-data, user-executed scope, with no observed differences at the thesis's published precision. The program was not separately re-executed by a third party.
- **Resource benchmarks:** wall-clock time and peak memory not instrumented; no claim about hardware resource requirements.
- **Dependencies/release:** `posterior` and R versions recorded, but no lockfile or immutable, independently tested cross-platform release; versioned release remains pending.
- **Statistical scope:** the empirical break-count search uses *profile* integrated marginal likelihood and must not be described as a fully integrated posterior over break count. Two-break exact-MCMC benchmark is over a deliberately restricted local support. K=8 changes the effective likelihood sample. Single-DGP simulation does not establish frequentist coverage.
- **Artifacts:** source inputs and paper code are tracked; generated results are deliberately ignored by Git. Preserve original full outputs outside the repo along with this report and the ZIP. Absence of original empirical run.log and historical bitwise reference output prevents stronger claims.
- **Editorial C07 is separate:** supplementary manuscript draft is prepared, but adviser review/publication decisions remain pending.

This report updates only the verification state. It does not modify or endorse changes to statistical procedures, coefficients, input CSVs, or manuscript numbers.
