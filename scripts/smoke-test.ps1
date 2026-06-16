<#
.SYNOPSIS
    Smoke test the SREinProd demo web app (production slot + staging slot).

.DESCRIPTION
    Hits the root of each slot and confirms the response code is reasonable.
    The production slot is expected to be 200 OK. The staging slot is
    expected to respond 200 on a normal GET (the simulated 500 only fires
    after >5 ?crash=1 clicks).

.PARAMETER AppUrl
    Production hostname (no scheme). Defaults to APP_URL from scripts/env.conf.

.PARAMETER StagingUrl
    Staging slot hostname (no scheme). Defaults to STAGING_URL from scripts/env.conf.
#>
[CmdletBinding()]
param(
    [string]$AppUrl,
    [string]$StagingUrl
)

$ErrorActionPreference = 'Stop'
$envFile = Join-Path $PSScriptRoot 'env.conf'

function Get-EnvValue($key) {
    if (-not (Test-Path $envFile)) { return $null }
    $line = Select-String -Path $envFile -Pattern "^$key=" | Select-Object -First 1
    if (-not $line) { return $null }
    return ($line.Line -split '=', 2)[1].Trim()
}

if (-not $AppUrl)     { $AppUrl     = Get-EnvValue 'APP_URL' }
if (-not $StagingUrl) { $StagingUrl = Get-EnvValue 'STAGING_URL' }

if (-not $AppUrl) { throw 'AppUrl is required (pass -AppUrl or set APP_URL in scripts/env.conf).' }

$failed = @()

function Test-Endpoint($label, $url) {
    Write-Host ("-> {0}: {1}" -f $label, $url) -ForegroundColor Cyan
    try {
        $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 30
        Write-Host ("   status: {0}" -f $resp.StatusCode) -ForegroundColor Green
        return $true
    }
    catch {
        $code = $null
        if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
        Write-Host ("   FAILED: {0}{1}" -f $_.Exception.Message, ($code ? " (HTTP $code)" : '')) -ForegroundColor Red
        return $false
    }
}

if (-not (Test-Endpoint 'production' "https://$AppUrl")) { $failed += 'production' }
if ($StagingUrl) {
    if (-not (Test-Endpoint 'staging   ' "https://$StagingUrl")) { $failed += 'staging' }
}

if ($failed.Count -gt 0) {
    throw ("Smoke test failed for: {0}" -f ($failed -join ', '))
}

Write-Host ""
Write-Host 'Smoke test passed.' -ForegroundColor Green

