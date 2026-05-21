# Shared helper: load .env.local into $env:* if present, then validate.
# Sourced by other scripts via: . "$PSScriptRoot\_load-env.ps1"; Assert-OrcaRouterKey
# - Loads .env.local on import (no side effects beyond setting $env:*)
# - Validation is a separate function so dot-source can fail the CALLER cleanly
#   (a dot-sourced `exit` only exits the helper, not the caller, on PS 5.1)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $repoRoot ".env.local"

if (Test-Path $envFile) {
    Write-Host "[env] loading $envFile" -ForegroundColor DarkGray
    Get-Content $envFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -eq "" -or $line.StartsWith("#")) { return }
        $kv = $line -split "=", 2
        if ($kv.Count -ne 2) { return }
        $key = $kv[0].Trim()
        $val = $kv[1].Trim().Trim('"').Trim("'")
        Set-Item -Path "env:$key" -Value $val
    }
} else {
    Write-Host "[env] no .env.local found - using existing process env" -ForegroundColor DarkGray
}

function Assert-OrcaRouterKey {
    if (-not $env:ORCAROUTER_API_KEY -or $env:ORCAROUTER_API_KEY -eq "sk-orca-REPLACE_ME" -or $env:ORCAROUTER_API_KEY -eq "") {
        Write-Host "[env] ORCAROUTER_API_KEY not set." -ForegroundColor Red
        Write-Host "      Copy .env.local.example to .env.local and paste your real sk-orca- key." -ForegroundColor Yellow
        throw "ORCAROUTER_API_KEY missing"
    }
    if (-not $env:ORCAROUTER_API_KEY.StartsWith("sk-orca-")) {
        Write-Host "[env] ORCAROUTER_API_KEY does not start with 'sk-orca-'." -ForegroundColor Red
        Write-Host "      OrcaRouter keys must use the sk-orca- prefix." -ForegroundColor Yellow
        throw "ORCAROUTER_API_KEY has wrong prefix"
    }
    $masked = $env:ORCAROUTER_API_KEY.Substring(0, 11) + "..." + $env:ORCAROUTER_API_KEY.Substring($env:ORCAROUTER_API_KEY.Length - 4)
    Write-Host "[env] ORCAROUTER_API_KEY=$masked" -ForegroundColor DarkGray
}
