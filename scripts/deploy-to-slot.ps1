<#
.SYNOPSIS
    Build and deploy the cloned sample app to an App Service deployment slot.

.DESCRIPTION
    Helper used by scripts/deploy-demo-env.ps1 and by the azd postdeploy
    hook. It assumes the sample app has already been cloned (see
    scripts/clone-sample-app.ps1) and that the App Service web app and the
    target slot already exist.

    The script reads the active environment from scripts/env.conf so the
    same call works from both the PowerShell and azd flows.

.PARAMETER SlotName
    Slot to deploy to. Defaults to 'staging'.

.PARAMETER AppName
    Web app name. Defaults to APP_NAME from scripts/env.conf.

.PARAMETER ResourceGroup
    Resource group. Defaults to APP_RESOURCE_GROUP from scripts/env.conf.

.PARAMETER SampleAppDir
    Local sample app directory. Defaults to SAMPLE_APP_DIR from scripts/env.conf.
#>
[CmdletBinding()]
param(
    [string]$SlotName = 'staging',
    [string]$AppName,
    [string]$ResourceGroup,
    [string]$SampleAppDir
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$envFile = Join-Path $PSScriptRoot 'env.conf'

function Get-EnvValue($key) {
    if (-not (Test-Path $envFile)) { return $null }
    $line = Select-String -Path $envFile -Pattern "^$key=" -SimpleMatch:$false |
        Select-Object -First 1
    if (-not $line) { return $null }
    return ($line.Line -split '=', 2)[1].Trim()
}

if (-not $AppName) { $AppName = Get-EnvValue 'APP_NAME' }
if (-not $ResourceGroup) { $ResourceGroup = Get-EnvValue 'APP_RESOURCE_GROUP' }
if (-not $SampleAppDir) { $SampleAppDir = Get-EnvValue 'SAMPLE_APP_DIR' }
if (-not $SampleAppDir) { $SampleAppDir = 'sample-app' }

if (-not $AppName -or -not $ResourceGroup) {
    throw "AppName and ResourceGroup are required. Provide them as parameters or fill scripts/env.conf."
}

$sampleAppPath = Join-Path $repoRoot $SampleAppDir
if (-not (Test-Path $sampleAppPath)) {
    throw "Sample app not found at $sampleAppPath. Run scripts/clone-sample-app.ps1 first."
}

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    throw "dotnet SDK is required but was not found on PATH."
}
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI (az) is required but was not found on PATH."
}

$artifactDir = Join-Path $repoRoot '.artifacts'
$publishDir = Join-Path $artifactDir 'publish'
$zipPath = Join-Path $artifactDir ("app-{0}.zip" -f $SlotName)

if (Test-Path $publishDir) { Remove-Item -Recurse -Force $publishDir }
if (Test-Path $zipPath) { Remove-Item -Force $zipPath }
New-Item -ItemType Directory -Force -Path $publishDir | Out-Null

Write-Host "Publishing sample app..." -ForegroundColor Cyan
dotnet publish $sampleAppPath -c Release -o $publishDir | Out-Host
if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed." }

Write-Host "Packaging zip..." -ForegroundColor Cyan
Compress-Archive -Path (Join-Path $publishDir '*') -DestinationPath $zipPath -Force

Write-Host ("Deploying to {0} (slot: {1})..." -f $AppName, $SlotName) -ForegroundColor Cyan

$deployArgs = @(
    'webapp', 'deploy',
    '--resource-group', $ResourceGroup,
    '--name', $AppName,
    '--src-path', $zipPath,
    '--type', 'zip'
)
# 'production' is not a real slot - omit --slot to deploy to the live site.
$isStaging = $SlotName -and $SlotName -ne 'production'
if ($isStaging) {
    $deployArgs += @('--slot', $SlotName)
}

# Run az and capture all output so we can detect the cold-start false-timeout.
$tmpOut = [System.IO.Path]::GetTempFileName()
$tmpErr = [System.IO.Path]::GetTempFileName()
$proc = Start-Process -FilePath 'az' -ArgumentList $deployArgs -NoNewWindow -Wait -PassThru `
    -RedirectStandardOutput $tmpOut -RedirectStandardError $tmpErr
$deployStdout = (Get-Content $tmpOut -Raw -ErrorAction SilentlyContinue)
$deployStderr = (Get-Content $tmpErr -Raw -ErrorAction SilentlyContinue)
Remove-Item $tmpOut, $tmpErr -ErrorAction SilentlyContinue
if ($deployStdout) { Write-Host $deployStdout }
if ($deployStderr) { Write-Host $deployStderr }

if ($proc.ExitCode -ne 0) {
    $combined = "$deployStdout`n$deployStderr"
    $isColdStartTimeout = $combined -match 'failed to start within 10 mins|worker proccess failed to start|ContainerTimeout'
    if (-not $isColdStartTimeout) {
        throw "az webapp deploy failed for slot '$SlotName'."
    }

    # Cold-start can outlive az's 10-minute deployment poll on a fresh
    # Linux App Service plan (the runtime image is being pulled and warmed
    # for the first time). The deployment record itself is fine - just
    # poll the slot URL ourselves for a few extra minutes before failing.
    Write-Host '' -ForegroundColor Yellow
    Write-Host 'az polling timed out on container cold-start. Verifying site responds directly...' -ForegroundColor Yellow

    if ($isStaging) {
        $defaultHostname = az webapp show -g $ResourceGroup -n $AppName --slot $SlotName --query 'defaultHostName' -o tsv
    } else {
        $defaultHostname = az webapp show -g $ResourceGroup -n $AppName --query 'defaultHostName' -o tsv
    }
    if (-not $defaultHostname) { throw "az webapp deploy failed for slot '$SlotName' and could not resolve a hostname to probe." }

    $url = "https://$defaultHostname"
    $deadline = (Get-Date).AddMinutes(5)
    $ok = $false
    while ((Get-Date) -lt $deadline) {
        try {
            $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
            if ($r.StatusCode -ge 200 -and $r.StatusCode -lt 500) {
                Write-Host ("Site responded {0} at {1}. Treating cold-start timeout as success." -f $r.StatusCode, $url) -ForegroundColor Green
                $ok = $true
                break
            }
        } catch {
            Start-Sleep -Seconds 15
        }
    }
    if (-not $ok) { throw "az webapp deploy timed out and the site at $url never came up within an additional 5 minutes." }
}

Write-Host ("Deployed to slot '{0}'." -f $SlotName) -ForegroundColor Green
