# Stage 2: live tests against api.orcarouter.ai.
# Requires .env.local with ORCAROUTER_API_KEY=sk-orca-...

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

. "$PSScriptRoot\_load-env.ps1"
Assert-OrcaRouterKey

$env:OPENCLAW_LIVE_TEST = "1"

Write-Host ""
Write-Host "=== Stage 2: live vitest (api.orcarouter.ai) ===" -ForegroundColor Cyan
Write-Host "  - resolves dynamic model" -ForegroundColor DarkGray
Write-Host "  - completes a real chat call" -ForegroundColor DarkGray
Write-Host "  - rejects an obviously bad key with 401" -ForegroundColor DarkGray
Write-Host ""

& node "node_modules/vitest/vitest.mjs" run tests/orcarouter.live.test.ts
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "FAIL: live tests" -ForegroundColor Red
    Write-Host "  - 401? double-check ORCAROUTER_API_KEY in .env.local" -ForegroundColor Yellow
    Write-Host "  - timeout? try OPENCLAW_LIVE_ORCAROUTER_MODEL=orcarouter/openai/gpt-5-nano in .env.local" -ForegroundColor Yellow
    Write-Host "  - 'Function calling is not enabled'? the auto router picked a non-tool model - pin a model in OPENCLAW_LIVE_ORCAROUTER_MODEL" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "PASS: Stage 2 (live)" -ForegroundColor Green
