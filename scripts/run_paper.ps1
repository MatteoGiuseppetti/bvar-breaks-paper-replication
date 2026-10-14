# Paper-only analyses from the original thesis code.
# Examples:
#   powershell -ExecutionPolicy Bypass -File scripts/run_paper.ps1 -Mode Empirical
#   powershell -ExecutionPolicy Bypass -File scripts/run_paper.ps1 -Mode Simulation
#   powershell -ExecutionPolicy Bypass -File scripts/run_paper.ps1 -Mode All
param(
  [ValidateSet("Simulation", "Empirical", "All")]
  [string]$Mode = "Empirical",
  [string]$RscriptCommand = "Rscript"
)
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$driver = Join-Path $root "code\paper\run_paper.R"
if (-not (Get-Command $RscriptCommand -ErrorAction SilentlyContinue)) {
  throw "Rscript not found; install R and ensure Rscript is in PATH."
}
Push-Location $root
try {
  & $RscriptCommand "scripts/check_inputs.R"
  if ($LASTEXITCODE -ne 0) { throw "Original input data validation failed." }
} finally { Pop-Location }
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$runDir = Join-Path $root ("results\paper_" + $Mode.ToLower() + "_" + $stamp)
New-Item -ItemType Directory -Path $runDir -Force | Out-Null
foreach ($name in @("PCECTPI.csv", "UNRATE.csv", "FEDFUNDS.csv")) {
  Copy-Item -LiteralPath (Join-Path $root ("data\raw\" + $name)) -Destination $runDir
}
$env:BVAR_PAPER_REPO_ROOT = $root
Write-Host "Starting paper-only $Mode. Workdir: $runDir"
Write-Host "The three-break simulation has 4 x 150000 MCMC iterations and may be VERY slow."
Push-Location $runDir
try {
  & $RscriptCommand --vanilla -e "capture.output(sessionInfo(), file='session_info.txt')"
  if ($LASTEXITCODE -ne 0) { throw "Unable to record R environment." }
  & $RscriptCommand --vanilla $driver $Mode.ToLower() *> "run.log"
  $runExit = $LASTEXITCODE
  if ($runExit -ne 0) { throw "Paper script exited with code $runExit. See $runDir\run.log" }
  Write-Host "Paper-only code finished. Outputs: $runDir"
  Write-Host "Compare numbers with the manuscript before reporting verified reproduction."
} finally {
  Pop-Location
  Remove-Item Env:BVAR_PAPER_REPO_ROOT -ErrorAction SilentlyContinue
}
