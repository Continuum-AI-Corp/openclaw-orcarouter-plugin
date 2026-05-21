# One-time prerequisite installer for the e2e tests.
#
# Installs:
#   - openclaw CLI globally (required for test-e2e.ps1)
#
# Does NOT install:
#   - pnpm + upstream clone (only needed for test-e2e-from-source.ps1) -- see
#     scripts/README.md for the manual steps if you need that fallback.

$ErrorActionPreference = "Stop"

# --- Node version check ---------------------------------------------------
$nodeVersion = (node --version) -replace '^v', ''
$parts = $nodeVersion.Split(".")
$major = [int]$parts[0]
$minor = [int]$parts[1]
if ($major -lt 22 -or ($major -eq 22 -and $minor -lt 16)) {
    Write-Host "FAIL: Node $nodeVersion is too old. openclaw requires Node >= 22.16." -ForegroundColor Red
    Write-Host "      Install Node 22 LTS from https://nodejs.org or via nvm/fnm." -ForegroundColor Yellow
    exit 1
}
Write-Host "[setup] node $nodeVersion OK" -ForegroundColor DarkGray

# --- Already installed? --------------------------------------------------
$existing = Get-Command openclaw -ErrorAction SilentlyContinue
if ($existing) {
    $current = & openclaw --version 2>&1
    Write-Host "[setup] openclaw already installed: $current at $($existing.Source)" -ForegroundColor DarkGray
    Write-Host "[setup] re-run with -Force to upgrade." -ForegroundColor DarkGray
    if (-not $args.Contains("-Force")) { exit 0 }
}

# --- Install ------------------------------------------------------------
# Pin to the version we built/tested against. Bump in lockstep with
# package.json::openclaw.compat.pluginApi when the SDK contract changes.
$pinnedVersion = "2026.5.12"

Write-Host ""
Write-Host "=== Installing openclaw@$pinnedVersion globally (~2-5 min) ===" -ForegroundColor Cyan

# Bypass npm.ps1 -- the Node.js Windows installer's npm.ps1 shim has a known
# bug where it mis-substrings the invocation when called via & from inside
# another script (truncates "npm install" -> "pm install"). Use npm.cmd
# directly so PowerShell hands args straight to cmd.exe.
$npmCmd = (Get-Command npm.cmd -ErrorAction SilentlyContinue)
if (-not $npmCmd) {
    Write-Host "FAIL: npm.cmd not found in PATH." -ForegroundColor Red
    Write-Host "      Reinstall Node.js from https://nodejs.org" -ForegroundColor Yellow
    exit 1
}
Write-Host "[setup] using: $($npmCmd.Source) install -g openclaw@$pinnedVersion" -ForegroundColor DarkGray
Write-Host ""

& $npmCmd.Source install -g "openclaw@$pinnedVersion"
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "FAIL: npm install -g openclaw failed." -ForegroundColor Red
    Write-Host "  Common causes on Windows:" -ForegroundColor Yellow
    Write-Host "    - EPERM on cleanup: close any existing openclaw shells, then retry." -ForegroundColor Yellow
    Write-Host "    - 'node' not on PATH for postinstall: open a fresh PowerShell window after Node install." -ForegroundColor Yellow
    Write-Host "    - corporate proxy: set HTTP_PROXY / HTTPS_PROXY env vars." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Fallback path (no global install needed):" -ForegroundColor Yellow
    Write-Host "    Use scripts/test-e2e-from-source.ps1 instead -- it runs against the" -ForegroundColor Yellow
    Write-Host "    upstream clone at E:\tmp\openclaw-upstream." -ForegroundColor Yellow
    exit 1
}

# --- Verify --------------------------------------------------------------
$installed = Get-Command openclaw -ErrorAction SilentlyContinue
if (-not $installed) {
    Write-Host "FAIL: openclaw installed but not on PATH." -ForegroundColor Red
    Write-Host "  Open a fresh PowerShell window (PATH only refreshes for new shells)." -ForegroundColor Yellow
    exit 1
}
$ver = & openclaw --version 2>&1
Write-Host ""
Write-Host "PASS: openclaw $ver at $($installed.Source)" -ForegroundColor Green
Write-Host ""
Write-Host "Next:  .\scripts\test-e2e.ps1" -ForegroundColor Green
