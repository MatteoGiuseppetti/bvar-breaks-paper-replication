# Article-only code extraction map

This document maps the paper's executable code to the **frozen local provenance copy** `code/reference/BVAR_thesis_full_code.R` (Git blob `85aee115a241877bfdca9deb53eb12bde0ce6cc3`). No runtime dependency on the historical dissertation repository exists.

All mapped original R statements are retained, apart from CRLF-to-LF normalization and adjacent explanatory comments. No prior, likelihood, proposal distribution, numerical formula, break-search criterion, or MCMC setting was intentionally rewritten.

| Paper file | Original inclusive line ranges | Content |
| --- | --- | --- |
| `code/paper/common.R` | 10–62, 94–321, 672–675 | Log marginal likelihood/prior/design functions, companion radius, labels |
| `code/paper/simulation_functions.R` | 676–686, 708–767, 771–813, 816–834, 1461–1484, 1487–1509, 1512–1537, 1539–1550, 1553–1713, 1862–1889, 1892–2059, 3274–3281, 3298–3336 | DGP, MCMC, diagnostics and plots |
| `code/paper/simulation_three_breaks.R` | 2986–3077, 3081, 3178–3245, 3293–3295 | Final three-break DGP and dispersed-start MCMC |
| `code/paper/empirical_application.R` | 3352–4222 | Complete original empirical K=4 and K=8 section |

## Selected and omitted routes

The paper runner retains **only** the final three-break simulation and the empirical K=4/K=8 analysis. One-break, two-break, break-count comparison and auxiliary historical simulations remain in the local reference copy, but **do not execute in the paper route**. The preliminary three-break **15,000-iteration shared-start** sampler (original lines 3079–3175) is deliberately excluded; the article uses the final dispersed-start sampler with seeds **1001–1004**, **150,000 iterations** per chain and **25,000 burn-in**, unthinned draws for posterior summaries and thinning 5 only for plotting. The DGP resets its seed to **2026**.

The wrapper's saved RDS and two simulation PDFs are output-management additions. `code/paper/empirical_application.R` preserves the original numerical statements. The PowerShell runner writes artifacts to separate, Git-ignored results directories.

## Fidelity and numerical evidence

```bash
python scripts/audit_paper_extraction.py
```

This compares mapped statements and frozen data snapshots; **it cannot establish numerical correctness**. Separately, the author **did execute** the extracted paper paths and historical full-source program on 2026-10-15 and compared selected numeric quantities to the dissertation at reported precision, with C09 result **PASS within that documented scope**. See [C09 report](C09_VERIFICATION_2026-10-15.md) and [comparison CSV](C09_NUMERICAL_COMPARISONS_2026-10-15.csv).

The locked R environment is configured separately using `renv`; see [environment setup](ENVIRONMENT.md). A lockfile is not proof of independent cross-platform numerical replication.
