<#
.SYNOPSIS
    Restore the SREinProd demo environment after an incident drill.

.DESCRIPTION
    Used at the end of Workshop module 5 (Incident Drill) to put the
    environment back into a clean state for the next run:

      1. Set INJECT_ERROR=0 on the production slot.
      2. Leave INJECT_ERROR=1 on the staging slot (it is the fault source).
      3. Run the smoke test against both slots.

    All defaults are read from scripts/env.conf.

.PARAMETER AppName
    Web app name. Defaults to APP_NAME from scripts/env.conf.

.PARAMETER ResourceGroup
    Resource group. Defaults to APP_RESOURCE_GROUP from scripts/env.conf.

.PARAMETER AppUrl
    Production hostname. Defaults to APP_URL.

.PARAMETER StagingUrl
    Staging hostname. Defaults to STAGING_URL.

.PARAMETER StagingSlotName
    Staging slot name. Defaults to STAGING_SLOT_NAME (or 'staging').
#>
[CmdletBinding()]
param(
    [string]$AppName,
    [string]$ResourceGroup,
    [string]$AppUrl,
    [string]$StagingUrl,
    [string]$StagingSlotName
)

$ErrorActionPreference = 'Stop'
$envFile = Join-Path $PSScriptRoot 'env.conf'

function Get-EnvValue($key) {
    if (-not (Test-Path $envFile)) { return $null }
    $line = Select-String -Path $envFile -Pattern "^$key=" | Select-Object -First 1
    if (-not $line) { return $null }
    return ($line.Line -split '=', 2)[1].Trim()
}

if (-not $AppName)         { $AppName = Get-EnvValue 'APP_NAME' }
if (-not $ResourceGroup)   { $ResourceGroup = Get-EnvValue 'APP_RESOURCE_GROUP' }
if (-not $AppUrl)          { $AppUrl  = Get-EnvValue 'APP_URL' }
if (-not $StagingUrl)      { $StagingUrl = Get-EnvValue 'STAGING_URL' }
if (-not $StagingSlotName) { $StagingSlotName = Get-EnvValue 'STAGING_SLOT_NAME' }
if (-not $StagingSlotName) { $StagingSlotName = 'staging' }

foreach ($p in @{ AppName = $AppName; ResourceGroup = $ResourceGroup; AppUrl = $AppUrl }.GetEnumerator()) {
    if (-not $p.Value) { throw ("{0} is required (pass as parameter or populate scripts/env.conf)." -f $p.Key) }
}

Write-Host 'Restoring production slot to baseline (INJECT_ERROR=0)...' -ForegroundColor Cyan
az webapp config appsettings set --name $AppName --resource-group $ResourceGroup --settings INJECT_ERROR=0 --only-show-errors | Out-Null

Write-Host ("Re-asserting fault on '{0}' slot (INJECT_ERROR=1)..." -f $StagingSlotName) -ForegroundColor Cyan
az webapp config appsettings set --name $AppName --resource-group $ResourceGroup --slot $StagingSlotName --settings INJECT_ERROR=1 --only-show-errors | Out-Null

Start-Sleep -Seconds 5

Write-Host 'Running smoke test...' -ForegroundColor Cyan
& (Join-Path $PSScriptRoot 'smoke-test.ps1') -AppUrl $AppUrl -StagingUrl $StagingUrl

Write-Host 'Rollback complete.' -ForegroundColor Green

