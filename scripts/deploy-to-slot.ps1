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
if ($SlotName -and $SlotName -ne 'production') {
    $deployArgs += @('--slot', $SlotName)
}
az @deployArgs | Out-Host
if ($LASTEXITCODE -ne 0) { throw "az webapp deploy failed for slot '$SlotName'." }

Write-Host ("Deployed to slot '{0}'." -f $SlotName) -ForegroundColor Green
