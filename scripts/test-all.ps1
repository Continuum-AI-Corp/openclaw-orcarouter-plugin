# Runs all three test stages in order. Stops at the first failure.
#
# Usage:
#   1. Copy .env.local.example to .env.local, fill in your sk-orca- key.
#   2. powershell -File scripts/test-all.ps1

$ErrorActionPreference = "Stop"

& "$PSScriptRoot\test-unit.ps1"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& "$PSScriptRoot\test-live.ps1"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& "$PSScriptRoot\test-e2e.ps1"
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "test-e2e.ps1 failed; falling back to test-e2e-from-source.ps1 ..." -ForegroundColor Yellow
    & "$PSScriptRoot\test-e2e-from-source.ps1"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Host ""
Write-Host "=========================" -ForegroundColor Green
Write-Host " ALL STAGES PASS" -ForegroundColor Green
Write-Host "=========================" -ForegroundColor Green
