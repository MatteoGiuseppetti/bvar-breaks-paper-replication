# Executes ONLY the article-selected routes in a project-local renv environment.
# First run Rscript --vanilla scripts/restore_environment.R from the repo root.
param(
  [ValidateSet("Simulation", "Empirical", "All")]
  [string]$Mode = "Empirical",
  [string]$RscriptCommand = "Rscript"
)
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$driver = Join-Path $root "scripts\run_paper_locked.R"
if (-not (Get-Command $RscriptCommand -ErrorAction SilentlyContinue)) {
  throw "Rscript not found; install R 4.6.1 and ensure Rscript is in PATH."
}
Push-Location $root
try {
  & $RscriptCommand --vanilla "scripts/check_inputs.R"
  if ($LASTEXITCODE -ne 0) { throw "Original input data validation failed." }
  & $RscriptCommand --vanilla "scripts/check_environment.R"
  if ($LASTEXITCODE -ne 0) { throw "R environment mismatch. First run Rscript --vanilla scripts/restore_environment.R." }
} finally { Pop-Location }
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$runDir = Join-Path $root ("results\paper_" + $Mode.ToLower() + "_" + $stamp)
New-Item -ItemType Directory -Path $runDir -Force | Out-Null
foreach ($name in @("PCECTPI.csv", "UNRATE.csv", "FEDFUNDS.csv")) {
  Copy-Item -LiteralPath (Join-Path $root ("data\raw\" + $name)) -Destination $runDir
}
$env:BVAR_PAPER_REPO_ROOT = $root
Write-Host "Starting paper-only $Mode with the locked R environment. Workdir: $runDir"
Write-Host "The selected three-break simulation has 4 x 150000 iterations and may be VERY slow."
Push-Location $runDir
try {
  & $RscriptCommand --vanilla $driver $Mode.ToLower() *> "run.log"
  $runExit = $LASTEXITCODE
  if ($runExit -ne 0) { throw "Paper script exited with code $runExit. See $runDir\run.log" }
  # Use the identical locked environment when recording package versions.
  & $RscriptCommand --vanilla -e "renv::load(project=Sys.getenv('BVAR_PAPER_REPO_ROOT')); capture.output(sessionInfo(), file='session_info.txt')"
  if ($LASTEXITCODE -ne 0) { throw "Could not record locked R session information." }
  Write-Host "Article-only run complete: $runDir"
  Write-Host "Check results against the documented manuscript values before claiming numerical reproduction."
} finally {
  Pop-Location
  Remove-Item Env:BVAR_PAPER_REPO_ROOT -ErrorAction SilentlyContinue
}
