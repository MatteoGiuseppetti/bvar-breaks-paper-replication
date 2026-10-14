#!/usr/bin/env python3
"""Static extraction audit. Does NOT execute R or validate numerical outputs."""
from pathlib import Path
import hashlib
import re
import sys

root = Path(__file__).resolve().parents[1]
reference = root / "code/reference/BVAR_thesis_full_code.R"
source_lines = reference.read_text(encoding="utf-8").splitlines()
expected = {
    "code/paper/common.R": [(10, 62), (94, 321), (672, 675)],
    "code/paper/simulation_functions.R": [
        (676, 686), (708, 767), (771, 813), (816, 834),
        (1461, 1484), (1487, 1509), (1512, 1537), (1539, 1550),
        (1553, 1713), (1862, 1889), (1892, 2059),
        (3274, 3281), (3298, 3336),
    ],
    "code/paper/simulation_three_breaks.R": [
        (2986, 3077), (3081, 3081), (3178, 3245), (3293, 3295),
    ],
    "code/paper/empirical_application.R": [(3352, 4222)],
}
original_blobs = {
    "code/reference/BVAR_thesis_full_code.R": "85aee115a241877bfdca9deb53eb12bde0ce6cc3",
    "data/raw/PCECTPI.csv": "ae36637e704c23483db0ab1da5057f553eaed88b",
    "data/raw/UNRATE.csv": "16ec96fb08abc50c088d6b8f9fcacda18d80daa3",
    "data/raw/FEDFUNDS.csv": "8d52898492df6a8587d69a3425686c73b205e742",
}
def git_blob_sha(data):
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()

failed = False
for path, wanted in original_blobs.items():
    found = git_blob_sha((root / path).read_bytes())
    good = found == wanted
    print(("PASS" if good else "FAIL"), "source hash", path)
    failed |= not good

pattern = re.compile(r"(?m)^# Original BVAR_thesis_full_code\.R lines (\d+)-(\d+) \(verbatim\)\n")
for path, spans in expected.items():
    data = (root / path).read_text(encoding="utf-8")
    matches = list(pattern.finditer(data))
    got_spans = [(int(m.group(1)), int(m.group(2))) for m in matches]
    if got_spans != spans:
        print("FAIL", path, "expected spans", spans, "got", got_spans)
        failed = True
        continue
    for i, (a, b) in enumerate(spans):
        end = matches[i+1].start() if i+1 < len(matches) else len(data)
        if path == "code/paper/simulation_three_breaks.R" and i == len(spans) - 1:
            boundary = data.find("\n# Output-only additions:", matches[i].end())
            if boundary < 0:
                print("FAIL missing output-only section separator")
                failed = True
                break
            end = boundary
        block = data[matches[i].end():end].strip("\n")
        expected_code = "\n".join(source_lines[a-1:b]).strip("\n")
        if block != expected_code:
            print("FAIL", path, "statement drift in lines", a, "-", b)
            failed = True
            break
    else:
        print("PASS", path, len(spans), "original ranges preserved")

sim = (root / "code/paper/simulation_three_breaks.R").read_text()
for required in ["set.seed(2026)", "n_iter_disp_3b <- 150000",
                 "burnin_disp_3b <- 25000", "seeds_disp_3b <- c(1001, 1002, 1003, 1004)"]:
    if required not in sim:
        print("FAIL missing simulation setting:", required)
        failed = True
if "multi_mcmc_3b <-" in sim or "multi_mcmc_2b" in sim:
    print("FAIL preliminary or two-break sampler included")
    failed = True
if failed:
    sys.exit("Static extraction audit FAILED")
print("PASS static extraction audit; this does not establish R execution or numerical equality.")
