# Stage 3 (alternative): real-user e2e by linking the plugin into the upstream
# OpenClaw clone at E:\tmp\openclaw-upstream.
#
# Use this when `openclaw plugins install <tgz>` is not supported by your
# globally installed openclaw CLI (older builds), or when you want to test
# against latest main.
#
# What it does:
#   1. Verifies E:\tmp\openclaw-upstream exists
#   2. Verifies upstream has run `pnpm install` (one-time, ~5min)
#   3. Copies this plugin into upstream/extensions/orcarouter
#   4. Adds the package to upstream/pnpm-workspace.yaml and re-installs
#      (just-in-time symlink, no global install needed)
#   5. Builds (`pnpm build`) - required so the runtime sees the new ext
#   6. Runs `pnpm openclaw onboard` + `pnpm openclaw agent` from upstream
#
# Requires:
#   - pnpm installed: npm install -g pnpm
#   - .env.local with ORCAROUTER_API_KEY=sk-orca-...

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

. "$PSScriptRoot\_load-env.ps1"
Assert-OrcaRouterKey

$upstream = if ($env:OPENCLAW_UPSTREAM) { $env:OPENCLAW_UPSTREAM } else { "E:\tmp\openclaw-upstream" }
if (-not (Test-Path $upstream)) {
    Write-Host "FAIL: upstream clone not found at $upstream" -ForegroundColor Red
    Write-Host "  Clone it: git clone --depth 1 https://github.com/openclaw/openclaw.git $upstream" -ForegroundColor Yellow
    Write-Host "  Or set OPENCLAW_UPSTREAM env var to a different path." -ForegroundColor Yellow
    exit 1
}
Write-Host "[e2e] upstream: $upstream" -ForegroundColor DarkGray

if (-not (Test-Path (Join-Path $upstream "node_modules"))) {
    Write-Host "FAIL: upstream has no node_modules. Run this FIRST (one-time, ~5min):" -ForegroundColor Red
    Write-Host "  cd $upstream" -ForegroundColor Yellow
    Write-Host "  pnpm install" -ForegroundColor Yellow
    exit 1
}

# Copy plugin into upstream/extensions/orcarouter
$extDir = Join-Path $upstream "extensions\orcarouter"
if (Test-Path $extDir) {
    Write-Host "[e2e] removing previous $extDir" -ForegroundColor DarkGray
    Remove-Item -Recurse -Force $extDir
}
New-Item -ItemType Directory -Path $extDir | Out-Null

$filesToCopy = @(
    "index.ts",
    "onboard.ts",
    "provider-catalog.ts",
    "openclaw.plugin.json",
    "README.md",
    "LICENSE"
)
foreach ($f in $filesToCopy) {
    Copy-Item -Path (Join-Path $repoRoot $f) -Destination (Join-Path $extDir $f)
}

# Rewrite package.json to look like an in-tree extension (workspace dep instead
# of npm dep on `openclaw`). Mirrors extensions/openrouter/package.json shape.
$pkg = @{
    name = "@openclaw/orcarouter-provider"
    version = "0.1.0-dev"
    private = $true
    description = "OrcaRouter provider plugin (linked from openclaw-orcarouter-plugin for e2e test)"
    type = "module"
    devDependencies = @{ "@openclaw/plugin-sdk" = "workspace:*" }
    openclaw = @{ extensions = @("./index.ts") }
}
$pkg | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $extDir "package.json") -Encoding UTF8
Write-Host "[e2e] linked plugin → $extDir" -ForegroundColor DarkGray

# Re-resolve workspace
Set-Location $upstream
Write-Host ""
Write-Host "=== Stage 3a: pnpm install (workspace re-link) ===" -ForegroundColor Cyan
& pnpm install --offline 2>&1 | Tee-Object -FilePath (Join-Path $repoRoot ".openclaw-test-home\pnpm-install.log")
if ($LASTEXITCODE -ne 0) {
    Write-Host "WARN: --offline failed; retrying online" -ForegroundColor Yellow
    & pnpm install
    if ($LASTEXITCODE -ne 0) { Write-Host "FAIL: pnpm install" -ForegroundColor Red; exit 1 }
}

Write-Host ""
Write-Host "=== Stage 3b: pnpm build (~2-5min) ===" -ForegroundColor Cyan
& pnpm build
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAIL: pnpm build" -ForegroundColor Red
    Write-Host "  Read upstream/AGENTS.md §Build for troubleshooting." -ForegroundColor Yellow
    exit 1
}

# Isolated home
$testHome = Join-Path $repoRoot ".openclaw-test-home"
if (Test-Path $testHome) { Remove-Item -Recurse -Force $testHome }
New-Item -ItemType Directory -Path $testHome | Out-Null
$env:OPENCLAW_HOME = $testHome

Write-Host ""
Write-Host "=== Stage 3c: onboard ===" -ForegroundColor Cyan
& pnpm openclaw onboard --auth-choice orcarouter-api-key --orcarouter-api-key "$($env:ORCAROUTER_API_KEY)" --non-interactive --accept-risk --skip-health
if ($LASTEXITCODE -ne 0) { Write-Host "FAIL: onboard" -ForegroundColor Red; exit 1 }

# plugins.allow gate (use file-based patch to dodge PowerShell quote stripping)
$patchFile = Join-Path $repoRoot ".openclaw-test-home\.allow-patch.json"
Set-Content -Path $patchFile -Encoding UTF8 -Value '{"plugins":{"allow":["orcarouter"]}}'
& pnpm openclaw config patch --file $patchFile
Remove-Item $patchFile -ErrorAction SilentlyContinue

# Default agent is `main` (created by onboard).
$agentId = "main"

# Allow overriding the default model if the workspace lacks the `auto` router.
$modelAuto = if ($env:OPENCLAW_E2E_MODEL_AUTO) { $env:OPENCLAW_E2E_MODEL_AUTO } else { "orcarouter/auto" }

Write-Host ""
Write-Host "=== Stage 3d: agent - $modelAuto ===" -ForegroundColor Cyan
& pnpm openclaw agent --agent $agentId --message "Reply with exactly OK." --model $modelAuto
if ($LASTEXITCODE -ne 0) { Write-Host "FAIL: agent ($modelAuto)" -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "=== Stage 3e: agent - pinned model ===" -ForegroundColor Cyan
& pnpm openclaw agent --agent $agentId --message "Reply in one sentence: which model are you?" --model "orcarouter/anthropic/claude-opus-4.7"
if ($LASTEXITCODE -ne 0) {
    Write-Host "WARN: pinned model scenario failed (may be unavailable in your workspace)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Stage 3f: agent - longer prompt ===" -ForegroundColor Cyan
& pnpm openclaw agent --agent $agentId --message "List exactly three benefits of unified LLM routing." --model "orcarouter/auto"
if ($LASTEXITCODE -ne 0) { Write-Host "WARN: longer prompt scenario failed" -ForegroundColor Yellow }

Set-Location $repoRoot
Write-Host ""
Write-Host "PASS: Stage 3 (e2e from source)" -ForegroundColor Green
