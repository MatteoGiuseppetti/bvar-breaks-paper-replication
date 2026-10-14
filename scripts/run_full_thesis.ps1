# Runs the UNMODIFIED full thesis R program in an isolated output directory.
# IMPORTANT: includes simulations NOT reported in the paper and can be very slow.
# Run from any location: powershell -ExecutionPolicy Bypass -File scripts/run_full_thesis.ps1
param(
  [string]$RscriptCommand = "Rscript"
)
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$reference = Join-Path $root "code\reference\BVAR_thesis_full_code.R"
if (-not (Test-Path -LiteralPath $reference)) { throw "Missing reference R script." }
if (-not (Get-Command $RscriptCommand -ErrorAction SilentlyContinue)) {
  throw "Rscript executable not found. Install R and add Rscript to PATH."
}
Push-Location $root
try {
  & $RscriptCommand "scripts/check_inputs.R"
  if ($LASTEXITCODE -ne 0) { throw "Input checks failed; run cancelled." }
} finally {
  Pop-Location
}
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$runDir = Join-Path $root ("results\full_original_" + $stamp)
New-Item -ItemType Directory -Path $runDir -Force | Out-Null
foreach ($name in @("PCECTPI.csv", "UNRATE.csv", "FEDFUNDS.csv")) {
  Copy-Item -LiteralPath (Join-Path $root ("data\raw\" + $name)) -Destination $runDir
}
$log = Join-Path $runDir "run.log"
Write-Host "Running full thesis code (potentially computationally expensive)."
Write-Host "Output directory: $runDir"
Push-Location $runDir
try {
  & $RscriptCommand --vanilla $reference *> $log
  $exitCode = $LASTEXITCODE
  & $RscriptCommand --vanilla -e "capture.output(sessionInfo(), file='session_info.txt')" *> (Join-Path $runDir "environment.log")
  if ($exitCode -ne 0) {
    throw "Original R script failed with exit code $exitCode; inspect $log"
  }
  Write-Host "Original script completed. Numerical comparison to thesis is STILL required."
  Write-Host "Log: $log"
} finally {
  Pop-Location
}
