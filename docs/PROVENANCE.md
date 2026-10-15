# Source provenance and repository boundary

**This is the article's independent replication repository.** The dissertation repository is a separate historical research archive, used **once as an input source** when preparing the article materials. No article run clones, imports code from, pushes to, or otherwise requires the dissertation repository. No changes have been made to that repository during this maintenance work.

For historical identification only, the source archive was:
https://github.com/MatteoGiuseppetti/bvar-structural-breaks-lag-selection

The following **local provenance copies** are retained here without edits, to audit exactly which statements and observations were used. Keeping them here does **not** merge the two projects or make the historical script part of the paper execution route.

| Paper repository path | Historical source path | Verified Git blob SHA-1 |
| --- | --- | --- |
| `code/reference/BVAR_thesis_full_code.R` | `BVAR_thesis_full_code.R` | `85aee115a241877bfdca9deb53eb12bde0ce6cc3` |
| `data/raw/PCECTPI.csv` | `PCECTPI.csv` | `ae36637e704c23483db0ab1da5057f553eaed88b` |
| `data/raw/UNRATE.csv` | `UNRATE.csv` | `16ec96fb08abc50c088d6b8f9fcacda18d80daa3` |
| `data/raw/FEDFUNDS.csv` | `FEDFUNDS.csv` | `8d52898492df6a8587d69a3425686c73b205e742` |

The content hashes were checked against the historical source repository on 2026-10-14. To audit the **copies inside this repository**:

```bash
git hash-object code/reference/BVAR_thesis_full_code.R
git hash-object data/raw/PCECTPI.csv
git hash-object data/raw/UNRATE.csv
git hash-object data/raw/FEDFUNDS.csv
python scripts/audit_paper_extraction.py
```

The paper's executable scientific path is under `code/paper/` only. `code/reference/` is not sourced by that path; the optional `scripts/run_full_thesis.ps1` is a **legacy comparison utility**, not part of paper replication. The historical script expects CSVs in its working directory, so the legacy script runs in its own isolated output directory.

A tracked `.gitattributes` rule (`data/raw/*.csv -text`) prohibits checkout line-ending conversion, preserving the **exact archived CSV bytes** on Windows as well as Linux. This is required for the hash audit.

The original snapshots are **not updated from FRED**. The archived UNRATE series has a missing October 2025 observation; the original quarterly conversion uses November and December for 2025Q4. Input changes would break the source integrity audit and invalidate the fixed-data C09 comparison.

The `renv` dependency lock concerns the article's **computing environment**, not its scientific methodology or its input provenance. The historical C09 Windows environment is reported separately in `docs/C09_VERIFICATION_2026-10-15.md`.

This is preservation and source tracing, not an assertion that scientific results have been independently reproduced beyond the expressly documented C09 scope.
