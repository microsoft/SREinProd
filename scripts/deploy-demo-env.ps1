<#
.SYNOPSIS
    End-to-end, interactive deployment of the SREinProd workshop environment.

.DESCRIPTION
    Prompts for (or accepts via parameters) the Azure subscription,
    resource group, and region, then provisions and deploys the workshop
    workload end-to-end without further interaction:

      1. Verify required tooling (az, git, dotnet 9.x).
      2. Resolve the active Azure context (az login only if needed).
      3. Interactively select subscription / location / resource group
         (defaults pulled from scripts/env.conf when present). The region
         prompt presents a curated list of regions known to have App
         Service Linux S1 quota for typical workshop subscriptions
         (canadacentral, westus3, swedencentral); eastus and eastus2 are
         intentionally not on the list because they are commonly capped
         at 0 instances on internal / sponsored / MPN subscriptions.
      4. Persist the chosen values to scripts/env.conf for re-runs.
      5. Create the resource group if it does not exist.
      6. PREFLIGHT: `az deployment group validate` so quota / SKU
         / region issues surface in seconds instead of after a partial
         deployment. If validation fails on quota, the script offers to
         pick a different region and re-validates.
      7. `az deployment group create` of infra/main.bicep.
      8. Clone the upstream sample app into ./sample-app/.
      9. Build with `dotnet publish -c Release` ONCE, zip the output
         with .NET ZipFile (fastest compression), and deploy the same
         artifact to the production slot AND the staging slot in
         PARALLEL via `az webapp deploy --slot` (bypasses azd's known
         slowness on slot-enabled sites - the "Checking deployment
         slots" hang - and avoids a duplicate build / serialised waits
         for two cold-starts).
     10. Run scripts/smoke-test.ps1 against both slots.

    Sample app: https://github.com/Azure-Samples/app-service-dotnet-agent-tutorial

.PARAMETER SubscriptionId
    Optional. Subscription ID (or display name). Skips the prompt.

.PARAMETER ResourceGroup
    Optional. Resource group name. Skips the prompt.

.PARAMETER Location
    Optional. Azure region. Skips the prompt.

.PARAMETER WorkloadName
    Short workload name used to derive resource names (3-12 lowercase chars).
    Defaults to WORKSHOP_NAME in env.conf or 'sreinprod'.

.PARAMETER EnvironmentName
    Short env name appended to derived names (e.g. 'demo', 'lab').
    Defaults to ENVIRONMENT_NAME in env.conf or 'demo'.

.PARAMETER EnvFile
    Path to the env file. Defaults to scripts/env.conf.

.PARAMETER NonInteractive
    Fail instead of prompting when a required value is missing.

.PARAMETER SkipAppDeploy
    Provision infra only; do not build or deploy the sample app.

.EXAMPLE
    # Fully interactive:
    pwsh ./scripts/deploy-demo-env.ps1

.EXAMPLE
    # Unattended (CI / second run):
    pwsh ./scripts/deploy-demo-env.ps1 `
        -SubscriptionId 9cba8386-943e-4adf-b359-1d21a0d14857 `
        -ResourceGroup rg-sreinprod-demo `
        -Location canadacentral `
        -NonInteractive
#>
[CmdletBinding()]
param(
    [string]$SubscriptionId,
    [string]$ResourceGroup,
    [string]$Location,
    [string]$WorkloadName,
    [string]$EnvironmentName,
    [string]$EnvFile = (Join-Path $PSScriptRoot 'env.conf'),
    [switch]$NonInteractive,
    [switch]$SkipAppDeploy
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

# =============================================================================
# Helpers
# =============================================================================

function Read-EnvFile([string]$Path) {
    $map = @{}
    if (-not (Test-Path $Path)) { return $map }
    Get-Content $Path | ForEach-Object {
        $line = $_.Trim()
        if (-not $line -or $line.StartsWith('#')) { return }
        $kv = $line -split '=', 2
        if ($kv.Count -eq 2) { $map[$kv[0].Trim()] = $kv[1].Trim() }
    }
    return $map
}

function Set-EnvLine([string]$Path, [string]$Key, [string]$Value) {
    if (-not (Test-Path $Path)) {
        Set-Content -Path $Path -Value ("{0}={1}" -f $Key, $Value)
        return
    }
    $pattern = "^$Key=.*$"
    $line = "$Key=$Value"
    $content = Get-Content $Path
    if ($content -match $pattern) {
        ($content -replace $pattern, $line) | Set-Content $Path
    } else {
        Add-Content -Path $Path -Value $line
    }
}

function Prompt-WithDefault([string]$Message, [string]$Default) {
    if ($NonInteractive) {
        if ([string]::IsNullOrWhiteSpace($Default)) {
            throw "Non-interactive mode but no default available for '$Message'."
        }
        return $Default
    }
    $suffix = if ($Default) { " [$Default]" } else { '' }
    $response = Read-Host ("{0}{1}" -f $Message, $suffix)
    if ([string]::IsNullOrWhiteSpace($response)) { return $Default }
    return $response.Trim()
}

# Curated list of regions known to have App Service Linux S1 quota for the
# typical workshop subscription profile (internal / MPN / sponsored). eastus
# and eastus2 are intentionally NOT on this list because those regions are
# frequently capped at 0 instances on those subscription types. See README.md
# (Prerequisites) for the quota note.
$Script:RecommendedRegions = @(
    @{ Slug = 'canadacentral';  Display = 'Canada Central' }
    @{ Slug = 'westus3';        Display = 'West US 3' }
    @{ Slug = 'swedencentral';  Display = 'Sweden Central' }
)

function Select-WorkshopRegion([string]$Default) {
    # Returns a region slug. In NonInteractive mode, returns the default (or
    # throws if no default is available).
    if ($NonInteractive) {
        if ([string]::IsNullOrWhiteSpace($Default)) {
            throw 'Non-interactive mode but no default region available.'
        }
        return $Default
    }

    # Pick a sensible default index: env.conf value if it is one of the
    # recommended regions, otherwise canadacentral (index 1).
    $defaultIndex = 1
    if ($Default) {
        for ($i = 0; $i -lt $Script:RecommendedRegions.Count; $i++) {
            if ($Script:RecommendedRegions[$i].Slug -eq $Default) {
                $defaultIndex = $i + 1
                break
            }
        }
    }

    Write-Host ''
    Write-Host 'Select an Azure region for the workshop workload:' -ForegroundColor Cyan
    Write-Host '  (these regions have known App Service Linux S1 quota; eastus and eastus2'
    Write-Host '   are typically capped at 0 instances on workshop subscriptions)'
    for ($i = 0; $i -lt $Script:RecommendedRegions.Count; $i++) {
        $r = $Script:RecommendedRegions[$i]
        Write-Host ('  [{0}] {1,-18} ({2})' -f ($i + 1), $r.Slug, $r.Display)
    }
    $otherIndex = $Script:RecommendedRegions.Count + 1
    Write-Host ('  [{0}] Other (enter your own region)' -f $otherIndex)

    while ($true) {
        $response = Prompt-WithDefault 'Pick 1-3 (or 4 for Other)' ([string]$defaultIndex)
        if ($response -match '^\d+$') {
            $idx = [int]$response
            if ($idx -ge 1 -and $idx -le $Script:RecommendedRegions.Count) {
                return $Script:RecommendedRegions[$idx - 1].Slug
            }
            if ($idx -eq $otherIndex) {
                $custom = Prompt-WithDefault 'Enter Azure region slug (e.g. westeurope)' ''
                if ([string]::IsNullOrWhiteSpace($custom)) {
                    Write-Host 'Region cannot be empty.' -ForegroundColor Yellow
                    continue
                }
                Write-Host ''
                Write-Host ("WARNING: '{0}' is not in the curated list. If your subscription has 0 quota there, deployment will fail at preflight." -f $custom) -ForegroundColor Yellow
                return $custom.Trim().ToLowerInvariant()
            }
        }
        Write-Host ('Invalid choice. Enter a number from 1 to {0}.' -f $otherIndex) -ForegroundColor Yellow
    }
}

function Invoke-Az {
    # Run az and capture output as JSON. Throws on non-zero exit.
    $args = @($Args)
    $output = & az @args 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw ("az {0} failed (exit {1}):`n{2}" -f ($args -join ' '), $LASTEXITCODE, ($output -join "`n"))
    }
    return $output
}

# =============================================================================
# 1. Tooling check
# =============================================================================

Write-Host '==> Checking tooling...' -ForegroundColor Cyan
foreach ($tool in 'az','git','dotnet') {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "$tool is required but was not found on PATH."
    }
}

# Confirm a .NET 9 SDK is installed (the sample targets net9.0).
$sdks = & dotnet --list-sdks
if (-not ($sdks -match '^9\.')) {
    throw ".NET 9 SDK is required (sample targets net9.0). Installed SDKs:`n$($sdks -join "`n")"
}
Write-Host 'OK: az, git, dotnet (9.x) found.' -ForegroundColor Green

# =============================================================================
# 2. Load env file (or seed from template)
# =============================================================================

if (-not (Test-Path $EnvFile)) {
    Write-Host ("==> Seeding {0} from env.template" -f $EnvFile) -ForegroundColor Cyan
    Copy-Item (Join-Path $PSScriptRoot 'env.template') $EnvFile
}
$envMap = Read-EnvFile $EnvFile

# =============================================================================
# 3. Resolve Azure context (az login only if needed)
# =============================================================================

Write-Host ''
Write-Host '==> Resolving Azure context...' -ForegroundColor Cyan
$account = $null
try {
    $account = (az account show --only-show-errors 2>$null) | ConvertFrom-Json
} catch { $account = $null }

if (-not $account) {
    if ($NonInteractive) {
        throw 'Not signed in to Azure CLI and NonInteractive was set. Run `az login` first.'
    }
    Write-Host 'Not signed in. Launching az login...' -ForegroundColor Yellow
    az login --only-show-errors | Out-Null
    $account = (az account show --only-show-errors) | ConvertFrom-Json
}

# Resolve target subscription: parameter > env.conf > current az context > prompt
$targetSub = $SubscriptionId
if (-not $targetSub -and $envMap.AZURE_SUBSCRIPTION_ID) { $targetSub = $envMap.AZURE_SUBSCRIPTION_ID }
if (-not $targetSub) {
    Write-Host ('Current subscription: {0} ({1})' -f $account.name, $account.id) -ForegroundColor Cyan
    $targetSub = Prompt-WithDefault 'Use this subscription? Enter ID or name to switch, or press Enter to keep' $account.id
}

if ($targetSub -ne $account.id -and $targetSub -ne $account.name) {
    Write-Host ("Switching to subscription '{0}'..." -f $targetSub) -ForegroundColor Cyan
    az account set --subscription $targetSub --only-show-errors | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Could not switch to subscription '$targetSub'." }
    $account = (az account show --only-show-errors) | ConvertFrom-Json
}
Write-Host ('Subscription: {0} ({1})' -f $account.name, $account.id) -ForegroundColor Green

# =============================================================================
# 4. Resolve workload / environment / location / resource group
# =============================================================================

if (-not $WorkloadName)    { $WorkloadName    = if ($envMap.WORKSHOP_NAME)     { $envMap.WORKSHOP_NAME }     else { 'sreinprod' } }
if (-not $EnvironmentName) { $EnvironmentName = if ($envMap.ENVIRONMENT_NAME)  { $envMap.ENVIRONMENT_NAME }  else { 'demo' } }

if (-not $Location) {
    $defaultLocation = if ($envMap.AZURE_LOCATION) { $envMap.AZURE_LOCATION } else { 'canadacentral' }
    $Location = Select-WorkshopRegion $defaultLocation
}

# Validate the region actually offers Linux App Service S1.
Write-Host ("==> Validating region '{0}' supports App Service Linux S1..." -f $Location) -ForegroundColor Cyan
# `az appservice list-locations` returns display names ("Canada Central") in the
# `name` field, not slugs. Normalize (strip spaces, lowercase) on both sides.
$normTarget = ($Location -replace '\s','').ToLowerInvariant()
$regionsJson = az appservice list-locations --linux-workers-enabled --sku S1 -o json 2>$null
$regions = $regionsJson | ConvertFrom-Json
$regionMatch = $regions | Where-Object { ($_.name -replace '\s','').ToLowerInvariant() -eq $normTarget }
if (-not $regionMatch) {
    throw "Region '$Location' does not offer Linux App Service S1 (or your subscription does not have access). Pick a different region."
}
Write-Host ('OK: {0} supports Linux App Service S1.' -f $Location) -ForegroundColor Green

if (-not $ResourceGroup) {
    $defaultRg = if ($envMap.APP_RESOURCE_GROUP) { $envMap.APP_RESOURCE_GROUP } else { "rg-$WorkloadName-$EnvironmentName" }
    $ResourceGroup = Prompt-WithDefault 'Resource group for the workshop workload' $defaultRg
}

$slotName  = if ($envMap.STAGING_SLOT_NAME) { $envMap.STAGING_SLOT_NAME } else { 'staging' }
$sampleDir = if ($envMap.SAMPLE_APP_DIR)    { $envMap.SAMPLE_APP_DIR }    else { 'sample-app' }
$sampleRef = if ($envMap.SAMPLE_APP_REF)    { $envMap.SAMPLE_APP_REF }    else { 'main' }
$sampleUrl = if ($envMap.SAMPLE_APP_REPO)   { $envMap.SAMPLE_APP_REPO }   else { 'https://github.com/Azure-Samples/app-service-dotnet-agent-tutorial.git' }

# =============================================================================
# 5. Summary + confirmation
# =============================================================================

Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ' Deployment plan' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host (' Subscription : {0} ({1})' -f $account.name, $account.id)
Write-Host (' Tenant       : {0}' -f $account.tenantId)
Write-Host (' Region       : {0}' -f $Location)
Write-Host (' Resource grp : {0}' -f $ResourceGroup)
Write-Host (' Workload     : {0} / {1}' -f $WorkloadName, $EnvironmentName)
Write-Host (' Staging slot : {0}' -f $slotName)
Write-Host (' Sample app   : {0} ({1})' -f $sampleUrl, $sampleRef)
Write-Host '============================================================' -ForegroundColor Cyan

if (-not $NonInteractive) {
    $proceed = Prompt-WithDefault 'Proceed? (y/n)' 'y'
    if ($proceed -notmatch '^(y|yes)$') {
        Write-Host 'Aborted by user.' -ForegroundColor Yellow
        return
    }
}

# Persist choices before doing any work so the next run picks them up.
Set-EnvLine $EnvFile 'AZURE_SUBSCRIPTION_ID' $account.id
Set-EnvLine $EnvFile 'AZURE_LOCATION' $Location
Set-EnvLine $EnvFile 'APP_RESOURCE_GROUP' $ResourceGroup
Set-EnvLine $EnvFile 'WORKSHOP_NAME' $WorkloadName
Set-EnvLine $EnvFile 'ENVIRONMENT_NAME' $EnvironmentName

# =============================================================================
# 6. Create resource group
# =============================================================================

Write-Host ''
Write-Host ("==> Ensuring resource group '{0}' in '{1}'..." -f $ResourceGroup, $Location) -ForegroundColor Cyan
az group create `
    --name $ResourceGroup `
    --location $Location `
    --tags workload=$WorkloadName purpose=sre-agent-workshop `
    --only-show-errors | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'az group create failed.' }
Write-Host 'OK.' -ForegroundColor Green

# =============================================================================
# 7. Preflight validation (catches quota / SKU / region issues fast)
# =============================================================================

$bicepPath = Join-Path $repoRoot 'infra' 'main.bicep'
$paramPath = Join-Path $repoRoot 'infra' 'main.parameters.json'

function Invoke-Validate([string]$ValidationLocation) {
    Write-Host ''
    Write-Host ("==> Preflight: az deployment group validate ({0})..." -f $ValidationLocation) -ForegroundColor Cyan
    $raw = az deployment group validate `
        --resource-group $ResourceGroup `
        --template-file $bicepPath `
        --parameters $paramPath `
        --parameters location=$ValidationLocation workloadName=$WorkloadName environmentName=$EnvironmentName stagingSlotName=$slotName `
        --only-show-errors `
        --output json 2>&1
    return @{ ExitCode = $LASTEXITCODE; Output = $raw }
}

$validation = Invoke-Validate $Location
while ($validation.ExitCode -ne 0) {
    $msg = ($validation.Output -join "`n")
    Write-Host '' -ForegroundColor Red
    Write-Host 'Preflight validation failed:' -ForegroundColor Red
    Write-Host $msg -ForegroundColor Red

    $isQuota = $msg -match 'SubscriptionIsOverQuotaForSku|quota'
    if ($NonInteractive -or -not $isQuota) {
        throw 'Preflight validation failed. See errors above.'
    }
    Write-Host ''
    Write-Host 'This is a quota / SKU issue. Pick a different region from the curated list:' -ForegroundColor Yellow
    $newLocation = Select-WorkshopRegion $Location
    if ([string]::IsNullOrWhiteSpace($newLocation) -or $newLocation -eq $Location) {
        throw 'Aborted: same region selected after quota failure, or no region provided.'
    }
    $normNew = ($newLocation -replace '\s','').ToLowerInvariant()
    $regionsJson = az appservice list-locations --linux-workers-enabled --sku S1 -o json 2>$null
    $regionMatch = ($regionsJson | ConvertFrom-Json) | Where-Object { ($_.name -replace '\s','').ToLowerInvariant() -eq $normNew }
    if (-not $regionMatch) { throw "Region '$newLocation' does not offer Linux App Service S1." }
    $Location = $newLocation
    Set-EnvLine $EnvFile 'AZURE_LOCATION' $Location
    # Move the RG to the new region by creating a fresh one. We do not delete the
    # old RG automatically (could contain other work); print a warning instead.
    Write-Host ("Region switched to '{0}'. Note: the old empty resource group still exists - delete manually if desired." -f $Location) -ForegroundColor Yellow
    az group create --name $ResourceGroup --location $Location --tags workload=$WorkloadName purpose=sre-agent-workshop --only-show-errors | Out-Null
    $validation = Invoke-Validate $Location
}
Write-Host 'OK: preflight validation passed.' -ForegroundColor Green

# =============================================================================
# 8. Bicep deployment
# =============================================================================

$deploymentName = ("{0}-{1}-{2:yyyyMMddHHmmss}" -f $WorkloadName, $EnvironmentName, (Get-Date))
Write-Host ''
Write-Host ("==> Deploying infra/main.bicep (deployment: {0})..." -f $deploymentName) -ForegroundColor Cyan

$deployJson = az deployment group create `
    --resource-group $ResourceGroup `
    --name $deploymentName `
    --template-file $bicepPath `
    --parameters $paramPath `
    --parameters location=$Location workloadName=$WorkloadName environmentName=$EnvironmentName stagingSlotName=$slotName `
    --only-show-errors `
    --output json
if ($LASTEXITCODE -ne 0) { throw 'Bicep deployment failed.' }

$outputs    = ($deployJson | ConvertFrom-Json).properties.outputs
$appName    = $outputs.webAppName.value
$appUrl     = $outputs.webAppUrl.value
$stagingUrl = $outputs.stagingUrl.value
$aiName     = $outputs.appInsightsName.value
$laName     = $outputs.logAnalyticsWorkspaceName.value

Write-Host ''
Write-Host 'Deployment outputs' -ForegroundColor Green
Write-Host ('  Web app:           {0}' -f $appName)
Write-Host ('  Production URL:    {0}' -f $appUrl)
Write-Host ('  Staging slot URL:  {0}' -f $stagingUrl)
Write-Host ('  App Insights:      {0}' -f $aiName)
Write-Host ('  Log Analytics WS:  {0}' -f $laName)

Set-EnvLine $EnvFile 'APP_NAME' $appName
Set-EnvLine $EnvFile 'APP_URL' ($appUrl -replace '^https?://', '')
Set-EnvLine $EnvFile 'STAGING_URL' ($stagingUrl -replace '^https?://', '')
Set-EnvLine $EnvFile 'APP_INSIGHTS_NAME' $aiName
Set-EnvLine $EnvFile 'LOG_ANALYTICS_WORKSPACE' $laName

if ($SkipAppDeploy) {
    Write-Host ''
    Write-Host 'SkipAppDeploy was set; not building or deploying the sample app.' -ForegroundColor Yellow
    return
}

# =============================================================================
# 9. Clone sample app
# =============================================================================

Write-Host ''
Write-Host '==> Cloning sample app...' -ForegroundColor Cyan
& (Join-Path $PSScriptRoot 'clone-sample-app.ps1') -RepoUrl $sampleUrl -Ref $sampleRef -TargetDir (Join-Path $repoRoot $sampleDir)

# =============================================================================
# 10. Build sample app once, then deploy to BOTH slots in parallel
#     (bypasses azd's slot-check hang AND avoids a duplicate dotnet publish /
#      serialised az webapp deploy calls).
# =============================================================================

$sampleAppPath = Join-Path $repoRoot $sampleDir
if (-not (Test-Path $sampleAppPath)) {
    throw "Sample app not found at $sampleAppPath. Step 9 (clone) must have failed."
}

$artifactDir = Join-Path $repoRoot '.artifacts'
$publishDir  = Join-Path $artifactDir 'publish'
$zipPath     = Join-Path $artifactDir 'app.zip'

if (Test-Path $publishDir) { Remove-Item -Recurse -Force $publishDir }
if (Test-Path $zipPath)    { Remove-Item -Force $zipPath }
New-Item -ItemType Directory -Force -Path $publishDir | Out-Null

Write-Host ''
Write-Host '==> Publishing sample app (one build for both slots)...' -ForegroundColor Cyan
dotnet publish $sampleAppPath -c Release -o $publishDir | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'dotnet publish failed.' }

Write-Host '==> Packaging zip (fastest compression)...' -ForegroundColor Cyan
Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
[System.IO.Compression.ZipFile]::CreateFromDirectory(
    $publishDir,
    $zipPath,
    [System.IO.Compression.CompressionLevel]::Fastest,
    $false
)

# Ensure Start-ThreadJob is available (ships with PowerShell 7 in the
# Microsoft.PowerShell.ThreadJob module). Fall back to Start-Job if not.
$useThreadJob = $null -ne (Get-Command Start-ThreadJob -ErrorAction SilentlyContinue)
$startJob = if ($useThreadJob) { 'Start-ThreadJob' } else { 'Start-Job' }

Write-Host ''
Write-Host ("==> Deploying to PRODUCTION and '{0}' slots in parallel ({1})..." -f $slotName, $startJob) -ForegroundColor Cyan

$deployScript = Join-Path $PSScriptRoot 'deploy-to-slot.ps1'
$slotsToDeploy = @('production', $slotName)
$jobs = foreach ($s in $slotsToDeploy) {
    $jobArgs = @{
        Name         = ("deploy-{0}" -f $s)
        ArgumentList = @($deployScript, $s, $appName, $ResourceGroup, $zipPath)
        ScriptBlock  = {
            param($Script, $Slot, $App, $Rg, $Zip)
            & $Script -SlotName $Slot -AppName $App -ResourceGroup $Rg -ZipPath $Zip
        }
    }
    if ($useThreadJob) { Start-ThreadJob @jobArgs } else { Start-Job @jobArgs }
}

# Wait for all jobs, then stream each job's output sequentially so the log
# stays readable. Failed jobs are collected and reported at the end.
Wait-Job -Job $jobs | Out-Null
$failed = @()
foreach ($job in $jobs) {
    Write-Host ''
    Write-Host ("---- {0} output ----" -f $job.Name) -ForegroundColor DarkCyan
    try {
        Receive-Job -Job $job -ErrorAction Stop
    } catch {
        $failed += ("{0}: {1}" -f $job.Name, $_.Exception.Message)
    }
    if ($job.State -eq 'Failed' -and $failed -notcontains $job.Name) {
        $failed += ("{0}: job state Failed" -f $job.Name)
    }
    Remove-Job -Job $job -Force
}
if ($failed.Count -gt 0) {
    throw ("Slot deploy(s) failed:`n  - {0}" -f ($failed -join "`n  - "))
}

# =============================================================================
# 11. Smoke test
# =============================================================================

Write-Host ''
Write-Host '==> Running smoke test...' -ForegroundColor Cyan
try {
    & (Join-Path $PSScriptRoot 'smoke-test.ps1') `
        -AppUrl ($appUrl -replace '^https?://', '') `
        -StagingUrl ($stagingUrl -replace '^https?://', '')
} catch {
    Write-Host ("Smoke test failed: {0}" -f $_.Exception.Message) -ForegroundColor Yellow
    Write-Host '(The app can take 30-60s to warm up on first request. Re-run scripts/smoke-test.ps1 if needed.)' -ForegroundColor Yellow
}

# =============================================================================
# Done
# =============================================================================

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host ' SREinProd demo environment is ready' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host ('  Production (healthy):     {0}' -f $appUrl)
Write-Host ('  Staging (INJECT_ERROR=1): {0}' -f $stagingUrl)
Write-Host ''
Write-Host 'Next steps:' -ForegroundColor Cyan
Write-Host '  - Workshop module 2: create the Azure SRE Agent and attach it to this resource group.'
Write-Host '  - Workshop module 5: run scripts/demo-warmup.ps1 to start the incident drill.'

