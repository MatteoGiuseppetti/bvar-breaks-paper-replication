# Paper-only code extraction map

This file records exactly how the **paper-only** scripts were separated from the unchanged original `code/reference/BVAR_thesis_full_code.R` (Git blob `85aee115a241877bfdca9deb53eb12bde0ce6cc3`).

All quoted original line ranges contain the original R statements, with only **CRLF-to-LF line-ending normalization** and adjacent explanatory section comments. No prior, likelihood, proposal distribution, numerical formula, break-search criterion, or MCMC setting has intentionally been rewritten.

| Paper file | Original inclusive line ranges | Content |
| --- | --- | --- |
| `code/paper/common.R` | 10–62, 94–321, 672–675 | Log-marginal/prior/design functions, companion spectral radius, label conversion |
| `code/paper/simulation_functions.R` | 676–686, 708–767, 771–813, 816–834, 1461–1484, 1487–1509, 1512–1537, 1539–1550, 1553–1713, 1862–1889, 1892–2059, 3274–3281, 3298–3336 | Multi-break DGP, collapsed MCMC, dispersed chains, MCMC diagnostics and plot functions |
| `code/paper/simulation_three_breaks.R` | 2986–3077, 3081, 3178–3245, 3293–3295 | Three-break DGP and **final** dispersed-start MCMC and quantile intervals |
| `code/paper/empirical_application.R` | 3352–4222 | The complete original real-data section, including **K=4** and **K=8**, model evidence, tables, tests and figure output |

## Excluded from the paper-only route

The reference source still contains all earlier one-break and two-break simulation experiments, approximate/global-grid comparisons, and auxiliary checks. These **do not run** through `scripts/run_paper.ps1`.

The original **15,000-iteration shared-start MCMC** for the three-break case (original lines 3079–3175) is omitted. The selected paper run uses the original dispersed starts, seeds **1001–1004**, **150,000 iterations per chain**, burn-in **25,000**, and unthinned posterior summary draws. Plotting thinning is 5. The three-break DGP resets the seed to **2026** immediately before simulation, and each MCMC chain sets its seed, so earlier thesis-only random draws are not needed to initialize these retained experiments. This source-level independence has **not yet been confirmed by running the extracted code**.

The paper-only R wrapper adds a `saveRDS` of the final three-break draws and explicitly saves the original plotting calls into two PDFs. These are **output-management changes**, not changes to estimation code. The empirical block is retained intact and produces the original nine PDFs and final RDS.

## How to audit integrity

From the new repository root, run:

~~~bash
python scripts/audit_paper_extraction.py
~~~

The audit checks all four original source/data Git blobs and verifies that each declared extracted statement range still matches the thesis source. It **cannot verify R syntax, execution success, elapsed time, or numerical equality**. Those require separately running both routes in R and comparing the reported tables and figures.

## Entry points

`scripts/run_paper.ps1 -Mode Empirical` runs the entire K=4 and K=8 empirical analyses; `-Mode Simulation` runs only the final three-break experiment; `-Mode All` runs both. Output and logs go under gitignored `results/`, not the repository root.

**Scientific status:** separation and static audit only; no new independently verified computational evidence is asserted.
