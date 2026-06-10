<#
.SYNOPSIS
    End-to-end deployment of the SREinProd workshop environment.

.DESCRIPTION
    Deploys the demo workload used by the workshop in five steps:

      1. Load environment from scripts/env.conf (created from env.template).
      2. Ensure the Azure CLI session is signed in.
      3. Create the application resource group if it does not exist.
      4. Provision infra/main.bicep (App Service + slot + Log Analytics +
         Application Insights + Http5xx metric alert).
      5. Clone the sample app and deploy the .NET 9 build to both the
         production slot and the staging (fault-injection) slot.

    Sample app: https://github.com/Azure-Samples/app-service-dotnet-agent-tutorial

    The script writes the names produced by Bicep (web app, AI, Log
    Analytics, URLs) back into scripts/env.conf so the other lab scripts
    (smoke-test, demo-warmup, demo-rollback) can pick them up without
    further configuration.

.PARAMETER SubscriptionId
    Optional. If supplied, `az account set` is invoked before deployment.

.PARAMETER EnvFile
    Path to the env file. Defaults to scripts/env.conf.

.PARAMETER SkipAppDeploy
    Only run the Bicep deployment; do not build/push the sample app.

.EXAMPLE
    Copy-Item scripts/env.template scripts/env.conf
    pwsh ./scripts/deploy-demo-env.ps1
#>
[CmdletBinding()]
param(
    [string]$SubscriptionId,
    [string]$EnvFile = (Join-Path $PSScriptRoot 'env.conf'),
    [switch]$SkipAppDeploy
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

# ---------- env loader ----------
if (-not (Test-Path $EnvFile)) {
    Write-Host "env file not found at $EnvFile. Copying from env.template." -ForegroundColor Yellow
    Copy-Item (Join-Path $PSScriptRoot 'env.template') $EnvFile
    Write-Host "Edit $EnvFile if you want to change defaults, then rerun." -ForegroundColor Yellow
}

$envMap = @{}
Get-Content $EnvFile | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith('#')) { return }
    $kv = $line -split '=', 2
    if ($kv.Count -eq 2) { $envMap[$kv[0].Trim()] = $kv[1].Trim() }
}

function Need($key) {
    if (-not $envMap.ContainsKey($key) -or [string]::IsNullOrWhiteSpace($envMap[$key])) {
        throw "$key is required in $EnvFile"
    }
    return $envMap[$key]
}

$workshop  = Need 'WORKSHOP_NAME'
$envName   = Need 'ENVIRONMENT_NAME'
$location  = Need 'AZURE_LOCATION'
$appRg     = Need 'APP_RESOURCE_GROUP'
$slotName  = if ($envMap.STAGING_SLOT_NAME) { $envMap.STAGING_SLOT_NAME } else { 'staging' }
$sampleDir = if ($envMap.SAMPLE_APP_DIR)    { $envMap.SAMPLE_APP_DIR }    else { 'sample-app' }
$sampleRef = if ($envMap.SAMPLE_APP_REF)    { $envMap.SAMPLE_APP_REF }    else { 'main' }
$sampleUrl = if ($envMap.SAMPLE_APP_REPO)   { $envMap.SAMPLE_APP_REPO }   else { 'https://github.com/Azure-Samples/app-service-dotnet-agent-tutorial.git' }

# ---------- tooling ----------
foreach ($tool in 'az','git','dotnet') {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "$tool is required but was not found on PATH."
    }
}

# ---------- subscription ----------
$account = az account show --only-show-errors 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Host 'Not signed in. Launching `az login`...' -ForegroundColor Yellow
    az login --only-show-errors | Out-Null
    $account = az account show --only-show-errors | ConvertFrom-Json
}
if ($SubscriptionId) {
    az account set --subscription $SubscriptionId | Out-Null
    $account = az account show --only-show-errors | ConvertFrom-Json
}
Write-Host ("Subscription: {0} ({1})" -f $account.name, $account.id) -ForegroundColor Cyan

# ---------- resource group ----------
Write-Host ("Ensuring resource group '{0}' in '{1}'..." -f $appRg, $location) -ForegroundColor Cyan
az group create --name $appRg --location $location --tags workload=$workshop purpose=sre-agent-workshop --only-show-errors | Out-Null

# ---------- bicep deployment ----------
$deploymentName = ("{0}-{1}-{2:yyyyMMddHHmmss}" -f $workshop, $envName, (Get-Date))
Write-Host ("Deploying infra/main.bicep (deployment: {0})..." -f $deploymentName) -ForegroundColor Cyan

$bicepPath = Join-Path $repoRoot 'infra' 'main.bicep'
$paramPath = Join-Path $repoRoot 'infra' 'main.parameters.json'

$deployJson = az deployment group create `
    --resource-group $appRg `
    --name $deploymentName `
    --template-file $bicepPath `
    --parameters $paramPath `
    --parameters location=$location workloadName=$workshop environmentName=$envName stagingSlotName=$slotName `
    --only-show-errors `
    --output json
if ($LASTEXITCODE -ne 0) { throw 'Bicep deployment failed.' }

$outputs = ($deployJson | ConvertFrom-Json).properties.outputs
$appName       = $outputs.webAppName.value
$appUrl        = $outputs.webAppUrl.value
$stagingUrl    = $outputs.stagingUrl.value
$aiName        = $outputs.appInsightsName.value
$laName        = $outputs.logAnalyticsWorkspaceName.value

Write-Host "" -ForegroundColor Green
Write-Host "Deployment outputs" -ForegroundColor Green
Write-Host ("  Web app:           {0}" -f $appName)
Write-Host ("  Production URL:    {0}" -f $appUrl)
Write-Host ("  Staging slot URL:  {0}" -f $stagingUrl)
Write-Host ("  App Insights:      {0}" -f $aiName)
Write-Host ("  Log Analytics WS:  {0}" -f $laName)
Write-Host ""

# ---------- write outputs back to env file ----------
function Set-EnvLine($key, $value) {
    $pattern = "^$key=.*$"
    $line = "$key=$value"
    $content = Get-Content $EnvFile
    if ($content -match $pattern) {
        ($content -replace $pattern, $line) | Set-Content $EnvFile
    } else {
        Add-Content -Path $EnvFile -Value $line
    }
}
Set-EnvLine 'APP_NAME' $appName
Set-EnvLine 'APP_URL' ($appUrl -replace '^https?://', '')
Set-EnvLine 'STAGING_URL' ($stagingUrl -replace '^https?://', '')
Set-EnvLine 'APP_INSIGHTS_NAME' $aiName
Set-EnvLine 'LOG_ANALYTICS_WORKSPACE' $laName
Write-Host "Updated $EnvFile with deployment outputs." -ForegroundColor Green

if ($SkipAppDeploy) {
    Write-Host 'SkipAppDeploy was set; not building or deploying the sample app.' -ForegroundColor Yellow
    return
}

# ---------- clone sample app ----------
Write-Host ""
& (Join-Path $PSScriptRoot 'clone-sample-app.ps1') -RepoUrl $sampleUrl -Ref $sampleRef -TargetDir (Join-Path $repoRoot $sampleDir)

# ---------- build + deploy to both slots ----------
Write-Host ""
Write-Host 'Deploying sample app to production slot...' -ForegroundColor Cyan
& (Join-Path $PSScriptRoot 'deploy-to-slot.ps1') -SlotName 'production' -AppName $appName -ResourceGroup $appRg -SampleAppDir $sampleDir

Write-Host ""
Write-Host 'Deploying sample app to staging slot...' -ForegroundColor Cyan
& (Join-Path $PSScriptRoot 'deploy-to-slot.ps1') -SlotName $slotName -AppName $appName -ResourceGroup $appRg -SampleAppDir $sampleDir

# ---------- smoke test ----------
Write-Host ""
Write-Host 'Running smoke test...' -ForegroundColor Cyan
& (Join-Path $PSScriptRoot 'smoke-test.ps1') -AppUrl ($appUrl -replace '^https?://', '') -StagingUrl ($stagingUrl -replace '^https?://', '')

Write-Host ""
Write-Host 'SREinProd demo environment is ready.' -ForegroundColor Green
Write-Host ("  Production (healthy):    {0}" -f $appUrl)
Write-Host ("  Staging (INJECT_ERROR=1): {0}" -f $stagingUrl)
Write-Host ''
Write-Host 'Next steps:' -ForegroundColor Cyan
Write-Host '  - Workshop module 2 - create the Azure SRE Agent and attach it to this resource group.'
Write-Host '  - Workshop module 5 - run scripts/demo-warmup.ps1 to start the incident drill.'

