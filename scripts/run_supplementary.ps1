# Article repository only: executes original supplementary simulations S7–S9.
# Scientific source is VERBATIM in code/supplementary/simulation_experiments.R.
param([string]$RscriptCommand = "Rscript")
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if (-not (Get-Command $RscriptCommand -ErrorAction SilentlyContinue)) {
  throw "Rscript not found; install R 4.6.1 and add it to PATH."
}
Push-Location $root
try {
  & $RscriptCommand --vanilla "scripts/check_environment.R"
  if ($LASTEXITCODE -ne 0) { throw "Restore the locked environment before running supplementary experiments." }
} finally { Pop-Location }
$runDir = Join-Path $root ("results\supplementary_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
New-Item -ItemType Directory -Path $runDir -Force | Out-Null
$env:BVAR_PAPER_REPO_ROOT = $root
$driver = Join-Path $root "scripts\run_supplementary_locked.R"
Write-Host "Running verbatim one-/two-break, exact-vs-MCMC and break-count experiments. This may be VERY slow."
Write-Host "Output directory: $runDir"
Push-Location $runDir
try {
  & $RscriptCommand --vanilla $driver *> "run.log"
  $runExit = $LASTEXITCODE
  if ($runExit -ne 0) { throw "Supplementary R code failed (exit $runExit). See $runDir\run.log." }
  & $RscriptCommand --vanilla -e "renv::load(project=Sys.getenv('BVAR_PAPER_REPO_ROOT')); capture.output(sessionInfo(), file='session_info.txt')"
  if ($LASTEXITCODE -ne 0) { throw "Could not save locked session information." }
  Write-Host "Supplementary simulations complete: $runDir"
} finally {
  Pop-Location
  Remove-Item Env:BVAR_PAPER_REPO_ROOT -ErrorAction SilentlyContinue
}
