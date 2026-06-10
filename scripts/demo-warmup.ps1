<#
.SYNOPSIS
    Warm up the SREinProd demo and inject the HTTP 500 fault.

.DESCRIPTION
    Used at the start of Workshop module 5 (Incident Drill). The script:

      1. Resets INJECT_ERROR=0 on the production slot to start clean.
      2. Sends baseline GET traffic to the production URL.
      3. Flips INJECT_ERROR=1 on the production slot to enable the fault.
      4. Sends ?crash=1 traffic to trip the simulated HTTP 500 path (the
         sample app throws after 5 clicks in a single session).

    All defaults are read from scripts/env.conf (populated by
    scripts/deploy-demo-env.ps1).

    Sample app: https://github.com/Azure-Samples/app-service-dotnet-agent-tutorial

.PARAMETER AppName
    Web app name. Defaults to APP_NAME from scripts/env.conf.

.PARAMETER ResourceGroup
    Resource group. Defaults to APP_RESOURCE_GROUP from scripts/env.conf.

.PARAMETER AppUrl
    Hostname of the slot to drive traffic against. Defaults to APP_URL.

.PARAMETER BaselineRequests
    Number of healthy baseline requests to send. Defaults to 25.

.PARAMETER FaultRequests
    Number of ?crash=1 requests per session. Defaults to 30.

.PARAMETER Sessions
    Number of independent cookie sessions used to trigger the fault. Defaults to 3.
#>
[CmdletBinding()]
param(
    [string]$AppName,
    [string]$ResourceGroup,
    [string]$AppUrl,
    [int]$BaselineRequests = 25,
    [int]$FaultRequests = 30,
    [int]$Sessions = 3
)

$ErrorActionPreference = 'Stop'
$envFile = Join-Path $PSScriptRoot 'env.conf'

function Get-EnvValue($key) {
    if (-not (Test-Path $envFile)) { return $null }
    $line = Select-String -Path $envFile -Pattern "^$key=" | Select-Object -First 1
    if (-not $line) { return $null }
    return ($line.Line -split '=', 2)[1].Trim()
}

if (-not $AppName)       { $AppName = Get-EnvValue 'APP_NAME' }
if (-not $ResourceGroup) { $ResourceGroup = Get-EnvValue 'APP_RESOURCE_GROUP' }
if (-not $AppUrl)        { $AppUrl  = Get-EnvValue 'APP_URL' }

foreach ($p in @{ AppName = $AppName; ResourceGroup = $ResourceGroup; AppUrl = $AppUrl }.GetEnumerator()) {
    if (-not $p.Value) { throw ("{0} is required (pass as parameter or populate scripts/env.conf)." -f $p.Key) }
}

Write-Host 'Step 1/4: Resetting production slot to baseline (INJECT_ERROR=0)...' -ForegroundColor Cyan
az webapp config appsettings set --name $AppName --resource-group $ResourceGroup --settings INJECT_ERROR=0 --only-show-errors | Out-Null
Start-Sleep -Seconds 5

Write-Host ("Step 2/4: Generating {0} baseline requests against https://{1} ..." -f $BaselineRequests, $AppUrl) -ForegroundColor Cyan
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
1..$BaselineRequests | ForEach-Object {
    try { Invoke-WebRequest -Uri "https://$AppUrl" -UseBasicParsing -WebSession $session -TimeoutSec 15 | Out-Null } catch {}
    Start-Sleep -Milliseconds 250
}

Write-Host 'Step 3/4: Injecting fault (INJECT_ERROR=1)...' -ForegroundColor Yellow
az webapp config appsettings set --name $AppName --resource-group $ResourceGroup --settings INJECT_ERROR=1 --only-show-errors | Out-Null
Start-Sleep -Seconds 10

Write-Host ("Step 4/4: Driving {0} failing requests across {1} sessions ..." -f $FaultRequests, $Sessions) -ForegroundColor Yellow
for ($s = 1; $s -le $Sessions; $s++) {
    $sx = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    1..$FaultRequests | ForEach-Object {
        try { Invoke-WebRequest -Uri "https://$AppUrl/?crash=1" -UseBasicParsing -WebSession $sx -TimeoutSec 15 | Out-Null } catch {}
        Start-Sleep -Milliseconds 200
    }
    Write-Host ("  session {0} complete" -f $s)
}

Write-Host ''
Write-Host 'Warmup complete. Give Application Insights and the Http5xx metric alert about 3-5 minutes to surface telemetry, then ask the SRE Agent to investigate.' -ForegroundColor Green
Write-Host ''
Write-Host 'Suggested prompt:' -ForegroundColor Cyan
Write-Host '  "We are seeing a spike of HTTP 500 errors on our production application. Users started reporting issues in the last few minutes. Can you investigate the cause of these 500 errors and identify the likely root cause?"'

