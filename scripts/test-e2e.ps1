# Stage 3: real-user end-to-end scenario.
#
# What it does:
#   1. Loads ORCAROUTER_API_KEY from .env.local (gitignored)
#   2. Packs this plugin: npm pack → orcarouter-openclaw-provider-0.1.0.tgz
#   3. Sets up an isolated OpenClaw home dir (.openclaw-test-home/) so it does
#      NOT touch your real ~/.openclaw/ config
#   4. Installs the packed plugin into that isolated home
#   5. Runs `openclaw agent --message "..." --model orcarouter/auto` against
#      api.orcarouter.ai through the plugin
#
# Requires:
#   - openclaw CLI installed globally: npm install -g openclaw@latest
#     (or set $env:OPENCLAW_BIN to point at a local build)
#   - .env.local with ORCAROUTER_API_KEY=sk-orca-...

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

. "$PSScriptRoot\_load-env.ps1"
Assert-OrcaRouterKey

$openclawBin = if ($env:OPENCLAW_BIN) { $env:OPENCLAW_BIN } else { "openclaw" }
Write-Host "[e2e] using openclaw binary: $openclawBin" -ForegroundColor DarkGray

# Verify openclaw is reachable
try {
    $version = & $openclawBin --version 2>&1
    Write-Host "[e2e] openclaw version: $version" -ForegroundColor DarkGray
} catch {
    Write-Host "FAIL: openclaw CLI not found." -ForegroundColor Red
    Write-Host "  Install globally:  npm install -g openclaw@latest" -ForegroundColor Yellow
    Write-Host "  Or set OPENCLAW_BIN to a local binary path." -ForegroundColor Yellow
    exit 1
}

# Isolated home dir so we never pollute the user's real ~/.openclaw/
$testHome = Join-Path $repoRoot ".openclaw-test-home"
if (Test-Path $testHome) {
    Write-Host "[e2e] removing previous test home: $testHome" -ForegroundColor DarkGray
    Remove-Item -Recurse -Force $testHome
}
New-Item -ItemType Directory -Path $testHome | Out-Null
$env:OPENCLAW_HOME = $testHome
Write-Host "[e2e] OPENCLAW_HOME=$testHome" -ForegroundColor DarkGray

# Build TS -> dist/*.js (openclaw plugins install rejects source-only tarballs).
Write-Host ""
Write-Host "=== Stage 3a: tsc build ===" -ForegroundColor Cyan
if (Test-Path dist) { Remove-Item -Recurse -Force dist }
& node "node_modules/typescript/lib/tsc.js" -p tsconfig.build.json
if ($LASTEXITCODE -ne 0) { Write-Host "FAIL: tsc build" -ForegroundColor Red; exit 1 }
if (-not (Test-Path "dist/index.js")) {
    Write-Host "FAIL: tsc finished but dist/index.js missing" -ForegroundColor Red
    exit 1
}

# Pack the plugin -- use npm.cmd directly (bypass the buggy npm.ps1 shim that
# ships with the Node Windows installer; it mis-substrings invocation args
# when called via & from another script).
Write-Host ""
Write-Host "=== Stage 3b: npm pack ===" -ForegroundColor Cyan
$npmCmd = (Get-Command npm.cmd -ErrorAction SilentlyContinue)
if (-not $npmCmd) {
    Write-Host "FAIL: npm.cmd not on PATH" -ForegroundColor Red
    exit 1
}
# Clean stale tarballs so $tgz capture below is unambiguous.
Get-ChildItem -Filter "orcarouter-openclaw-provider-*.tgz" | Remove-Item -Force
$packOutput = & $npmCmd.Source pack --silent
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAIL: npm pack" -ForegroundColor Red
    Write-Host $packOutput
    exit 1
}
$tgz = ($packOutput | Select-Object -Last 1).ToString().Trim()
$tgzPath = Join-Path $repoRoot $tgz
if (-not (Test-Path $tgzPath)) {
    Write-Host "FAIL: cannot locate packed tarball: $tgzPath" -ForegroundColor Red
    exit 1
}
Write-Host "[e2e] packed: $tgz" -ForegroundColor DarkGray

# Install plugin into isolated home
Write-Host ""
Write-Host "=== Stage 3c: openclaw plugins install (from local tarball) ===" -ForegroundColor Cyan
& $openclawBin plugins install $tgzPath
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAIL: openclaw plugins install" -ForegroundColor Red
    Write-Host "  If openclaw reports 'unknown plugin format', try installing the upstream clone instead." -ForegroundColor Yellow
    Write-Host "  See scripts/test-e2e-from-source.ps1 for the alternative path." -ForegroundColor Yellow
    exit 1
}

# Onboard with our API key.
# --non-interactive in OpenClaw 2026.5.x requires --accept-risk (security policy).
# --skip-health bypasses the gateway daemon reachability probe -- we only need
# the config written; `openclaw agent` calls below talk directly to OrcaRouter
# without going through the gateway daemon.
Write-Host ""
Write-Host "=== Stage 3d: openclaw onboard (orcarouter-api-key) ===" -ForegroundColor Cyan
& $openclawBin onboard --auth-choice orcarouter-api-key --orcarouter-api-key "$($env:ORCAROUTER_API_KEY)" --non-interactive --accept-risk --skip-health
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAIL: openclaw onboard" -ForegroundColor Red
    exit 1
}

# Explicitly allowlist the plugin so the runtime trusts it instead of warning
# about auto-loading a non-bundled plugin.
#
# PowerShell strips inner quotes when passing args via & to a native exe, so
# `config set plugins.allow '["orcarouter"]'` arrives at openclaw as
# [orcarouter] which is invalid JSON. Use config patch --file instead.
Write-Host ""
Write-Host "=== Stage 3d2: register orcarouter in plugins.allow ===" -ForegroundColor Cyan
$patchFile = Join-Path $repoRoot ".openclaw-test-home\.allow-patch.json"
Set-Content -Path $patchFile -Encoding UTF8 -Value '{"plugins":{"allow":["orcarouter"]}}'
& $openclawBin config patch --file $patchFile
Remove-Item $patchFile -ErrorAction SilentlyContinue
if ($LASTEXITCODE -ne 0) {
    Write-Host "WARN: failed to set plugins.allow (auto-load warning will reappear)" -ForegroundColor Yellow
}

# `openclaw agent` needs a target agent. The default agent created by onboard
# is named "main" (see onboard output: "Sessions OK: ...\.openclaw\agents\main").
$agentId = "main"

# Real-user scenario 1: orcarouter/auto smart routing.
# Override the default model with OPENCLAW_E2E_MODEL_AUTO in .env.local if
# your workspace has not configured the `auto` virtual router yet -- common
# 503 is "No available channel for model auto under group default".
$modelAuto = if ($env:OPENCLAW_E2E_MODEL_AUTO) { $env:OPENCLAW_E2E_MODEL_AUTO } else { "orcarouter/auto" }
Write-Host ""
Write-Host "=== Stage 3e: agent scenario 1 - $modelAuto ===" -ForegroundColor Cyan
$prompt1 = "Reply with exactly 'OK' and nothing else."
$reply1 = & $openclawBin agent --agent $agentId --message $prompt1 --model $modelAuto
Write-Host "PROMPT: $prompt1"
Write-Host "REPLY:  $reply1"
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAIL: scenario 1 ($modelAuto)" -ForegroundColor Red
    Write-Host "  503 'No available channel for model X under group default'?" -ForegroundColor Yellow
    Write-Host "    -> Your OrcaRouter workspace has no channel for that model in the default group." -ForegroundColor Yellow
    Write-Host "    -> Set OPENCLAW_E2E_MODEL_AUTO=orcarouter/openai/gpt-4o-mini in .env.local" -ForegroundColor Yellow
    Write-Host "       (or any model your workspace has configured at orcarouter.ai/console)." -ForegroundColor Yellow
    exit 1
}

# Real-user scenario 2: pinned reasoning model
Write-Host ""
Write-Host "=== Stage 3f: agent scenario 2 - pinned anthropic/claude-opus-4.7 ===" -ForegroundColor Cyan
$prompt2 = "Reply in one short sentence: which model are you?"
$reply2 = & $openclawBin agent --agent $agentId --message $prompt2 --model orcarouter/anthropic/claude-opus-4.7
Write-Host "PROMPT: $prompt2"
Write-Host "REPLY:  $reply2"
if ($LASTEXITCODE -ne 0) {
    Write-Host "WARN: scenario 2 failed (model may be unavailable in your OrcaRouter workspace)" -ForegroundColor Yellow
}

# Real-user scenario 3: long-context smoke test
Write-Host ""
Write-Host "=== Stage 3g: agent scenario 3 - longer prompt ===" -ForegroundColor Cyan
$prompt3 = "List exactly three benefits of unified LLM routing. Reply with a numbered list and nothing else."
$reply3 = & $openclawBin agent --agent $agentId --message $prompt3 --model orcarouter/auto
Write-Host "PROMPT: $prompt3"
Write-Host "REPLY:  $reply3"
if ($LASTEXITCODE -ne 0) {
    Write-Host "WARN: scenario 3 failed" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "PASS: Stage 3 (e2e)" -ForegroundColor Green
Write-Host ""
Write-Host "Test home was kept at $testHome for inspection." -ForegroundColor DarkGray
Write-Host "Delete it with: Remove-Item -Recurse -Force '$testHome'" -ForegroundColor DarkGray
