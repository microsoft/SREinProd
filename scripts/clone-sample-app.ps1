<#
.SYNOPSIS
    Clone (or refresh) the SREinProd workshop sample application.

.DESCRIPTION
    Pulls Azure-Samples/app-service-dotnet-agent-tutorial into ./sample-app/.
    Safe to run multiple times: if the directory already contains the repo it
    is updated to the requested ref; otherwise it is freshly cloned.

    The sample app is NOT vendored in this repository (sample-app/ is
    gitignored) so the workshop always demos against the latest upstream code.

.PARAMETER RepoUrl
    Git URL of the sample app. Defaults to the upstream Azure-Samples repo.

.PARAMETER Ref
    Branch, tag, or commit to check out. Defaults to 'main'.

.PARAMETER TargetDir
    Local directory the sample is cloned into. Defaults to './sample-app'.

.PARAMETER Force
    Wipe the target directory before cloning.
#>
[CmdletBinding()]
param(
    [string]$RepoUrl = 'https://github.com/Azure-Samples/app-service-dotnet-agent-tutorial.git',
    [string]$Ref = 'main',
    [string]$TargetDir = (Join-Path $PSScriptRoot '..' 'sample-app'),
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "git is required but was not found on PATH."
}

$TargetDir = [System.IO.Path]::GetFullPath($TargetDir)

if ($Force -and (Test-Path $TargetDir)) {
    Write-Host "Removing existing $TargetDir (Force)" -ForegroundColor Yellow
    Remove-Item -Recurse -Force $TargetDir
}

if (Test-Path (Join-Path $TargetDir '.git')) {
    Write-Host "Updating existing clone in $TargetDir" -ForegroundColor Cyan
    Push-Location $TargetDir
    try {
        git fetch --depth 1 origin $Ref | Out-Null
        git checkout -B $Ref FETCH_HEAD | Out-Null
        Write-Host "Sample app refreshed to '$Ref'." -ForegroundColor Green
    }
    finally {
        Pop-Location
    }
}
else {
    if ((Test-Path $TargetDir) -and ((Get-ChildItem -Force $TargetDir | Measure-Object).Count -gt 0)) {
        throw "$TargetDir exists and is not empty. Re-run with -Force to overwrite."
    }
    Write-Host "Cloning $RepoUrl ($Ref) into $TargetDir" -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null
    git clone --depth 1 --branch $Ref $RepoUrl $TargetDir | Out-Null
    Write-Host "Sample app cloned." -ForegroundColor Green
}

# Sanity check: the project file we expect must be present.
$projects = Get-ChildItem -Path $TargetDir -Filter '*.csproj' -File -ErrorAction SilentlyContinue
if (-not $projects -or $projects.Count -eq 0) {
    throw "No .csproj found in $TargetDir after clone. Did the upstream layout change?"
}

Write-Host ("Sample project: {0}" -f $projects[0].FullName) -ForegroundColor Green
