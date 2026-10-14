# Source provenance and file integrity

The reference materials below are copied **without edits** from the author's thesis repository:
https://github.com/MatteoGiuseppetti/bvar-structural-breaks-lag-selection

The original repository is the historical record and is not edited by this paper-replication project.

| Paper repository path | Original thesis path | Original Git blob SHA-1 |
| --- | --- | --- |
| code/reference/BVAR_thesis_full_code.R | BVAR_thesis_full_code.R | 85aee115a241877bfdca9deb53eb12bde0ce6cc3 |
| data/raw/PCECTPI.csv | PCECTPI.csv | ae36637e704c23483db0ab1da5057f553eaed88b |
| data/raw/UNRATE.csv | UNRATE.csv | 16ec96fb08abc50c088d6b8f9fcacda18d80daa3 |
| data/raw/FEDFUNDS.csv | FEDFUNDS.csv | 8d52898492df6a8587d69a3425686c73b205e742 |

These Git content hashes were checked against the source repository on 2026-10-14. To validate a local copy using Git, run:

~~~bash
git hash-object code/reference/BVAR_thesis_full_code.R
git hash-object data/raw/PCECTPI.csv
git hash-object data/raw/UNRATE.csv
git hash-object data/raw/FEDFUNDS.csv
~~~

The copied R source contains the *full* thesis research program; it includes experiments omitted from the paper and a separate empirical application. It has not been shortened or reorganized, intentionally. Its internal input paths expect three CSVs in the **current working directory**, not in data/raw/. The isolated PowerShell runner copies those CSV snapshots to a results directory before executing the untouched script.

The snapshots are not necessarily identical to values returned by a fresh FRED download today. In particular, the archived UNRATE file has a missing value for October 2025; the original data-processing rule averages the available November and December observations for 2025Q4.

**No new input-data downloads, statistical re-estimation, or code modifications are implied by this archive.**
