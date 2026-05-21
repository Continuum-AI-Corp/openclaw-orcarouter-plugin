# Stage 1: offline unit tests + typecheck.
# Does NOT require an API key.

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

Write-Host "=== Stage 1: typecheck ===" -ForegroundColor Cyan
& node "node_modules/typescript/lib/tsc.js" --noEmit
if ($LASTEXITCODE -ne 0) { Write-Host "FAIL: typecheck" -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "=== Stage 1: unit tests ===" -ForegroundColor Cyan
& node "node_modules/vitest/vitest.mjs" run tests/index.test.ts
if ($LASTEXITCODE -ne 0) { Write-Host "FAIL: unit tests" -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "PASS: Stage 1 (offline)" -ForegroundColor Green
