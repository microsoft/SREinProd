# AZD Setup

One-command path to provision the SREinProd workshop environment using the
Azure Developer CLI.

Sample workload: [`Azure-Samples/app-service-dotnet-agent-tutorial`](https://github.com/Azure-Samples/app-service-dotnet-agent-tutorial)

## What `azd up` does in this repo

1. **preprovision hook** runs [`scripts/clone-sample-app.ps1`](./scripts/clone-sample-app.ps1), which clones the sample app into `./sample-app/` (gitignored).
2. **provision** deploys [`infra/main.bicep`](./infra/main.bicep) - App Service plan (Linux S1), web app, `staging` slot, Log Analytics workspace, Application Insights, diagnostic settings, and an Http5xx metric alert.
3. **deploy** publishes the .NET 9 sample to the **production slot** of the web app.
4. **postdeploy hook** runs [`scripts/deploy-to-slot.ps1 -SlotName staging`](./scripts/deploy-to-slot.ps1) to publish the same bits to the staging slot.

The Bicep template seeds the slot configuration so the **production slot is
healthy** and the **staging slot has `INJECT_ERROR=1`** (slot-sticky), ready
for Module 5.

## Prerequisites

- Azure Developer CLI 1.10+ (`azd version`)
- Azure CLI (`az --version`)
- PowerShell 7+ (`pwsh --version`)
- .NET 9 SDK (`dotnet --list-sdks`)
- Git (`git --version`)
- Permissions to create resource groups in your target subscription

## Flow

```powershell
# 1. Sign in (both CLIs)
azd auth login
az login

# 2. Create an azd environment for this workshop
azd env new sreinprod-demo
azd env set AZURE_LOCATION eastus2

# 3. (Optional) Pick a non-default subscription
azd env set AZURE_SUBSCRIPTION_ID <your-subscription-id>

# 4. Provision + deploy in one shot
azd up
```

When `azd up` finishes you will have:

- **Production URL** - healthy; suitable for the baseline traffic generator.
- **Staging URL** - configured with `INJECT_ERROR=1`; the 6th `?crash=1` request per session throws.
- **Application Insights** - already wired; SRE Agent will pick this up in Module 3.
- **Http5xx metric alert** - fires on >=5 failures in 5 minutes; the signal SRE Agent investigates.

The deployment outputs (web app name, URLs, AI/LA names) are also mirrored
into `scripts/env.conf` by [`scripts/deploy-demo-env.ps1`](./scripts/deploy-demo-env.ps1)
if you ever want to switch to the PowerShell path mid-workshop.

## Smoke test

```powershell
$prod = azd env get-values | Select-String '^WEBAPPURL=' | ForEach-Object { ($_ -split '=', 2)[1].Trim('"') }
Invoke-WebRequest -Uri $prod -UseBasicParsing | Select-Object StatusCode
```

Or, after `deploy-demo-env.ps1` has written `scripts/env.conf`:

```powershell
./scripts/smoke-test.ps1
```

## Tearing it down

```powershell
azd down --purge
```

`--purge` also removes the Application Insights and Log Analytics resources
so re-running the workshop starts from a clean slate.

