# PowerShell Setup

Explicit, step-by-step path for provisioning the SREinProd workshop
environment using `az` + PowerShell. Use this when you want presenters or
lab runners to see each step.

Sample workload: [`Azure-Samples/app-service-dotnet-agent-tutorial`](https://github.com/Azure-Samples/app-service-dotnet-agent-tutorial)

## Prerequisites

- PowerShell 7+ (`pwsh --version`)
- Azure CLI (`az --version`)
- .NET 9 SDK (`dotnet --list-sdks`)
- Git (`git --version`)
- Permissions to create resource groups in your target subscription

## One-shot path (recommended for live demos)

```powershell
# 1. Configure the environment file (one-time)
Copy-Item .\scripts\env.template .\scripts\env.conf
notepad .\scripts\env.conf   # set AZURE_LOCATION, APP_RESOURCE_GROUP, etc.

# 2. Sign in (the script will also prompt if needed)
az login

# 3. Run the end-to-end deploy
pwsh .\scripts\deploy-demo-env.ps1
```

The script will:

1. Load `scripts/env.conf`.
2. Create `APP_RESOURCE_GROUP` if missing.
3. Deploy `infra/main.bicep` (App Service plan, web app, staging slot, Log Analytics, Application Insights, Http5xx alert).
4. Clone the sample app into `./sample-app/`.
5. Build with `dotnet publish -c Release`, zip the output, and deploy it to the **production slot** and the **staging slot** with `az webapp deploy`.
6. Run `scripts/smoke-test.ps1` against both slots.
7. Write the deployment outputs back into `scripts/env.conf` for the other scripts to consume.

## Step-by-step path (for teaching)

If you want to walk through the pieces individually:

```powershell
# 1. Pull the sample app
pwsh .\scripts\clone-sample-app.ps1

# 2. Create the resource group
az group create --name rg-sreinprod-app --location eastus2

# 3. Provision the infra
az deployment group create `
  --resource-group rg-sreinprod-app `
  --template-file .\infra\main.bicep `
  --parameters .\infra\main.parameters.json

# 4. Read the deployment outputs you need for app deploy
$out = (az deployment group show `
  --resource-group rg-sreinprod-app `
  --name <deployment-name> -o json | ConvertFrom-Json).properties.outputs
$appName = $out.webAppName.value

# 5. Deploy to each slot using the helper
pwsh .\scripts\deploy-to-slot.ps1 -SlotName production -AppName $appName -ResourceGroup rg-sreinprod-app
pwsh .\scripts\deploy-to-slot.ps1 -SlotName staging    -AppName $appName -ResourceGroup rg-sreinprod-app

# 6. Smoke test
pwsh .\scripts\smoke-test.ps1
```

## Script reference

| Script | Purpose | Used in |
|---|---|---|
| `scripts/clone-sample-app.ps1` | Idempotently clones the upstream sample into `./sample-app/`. | Setup, azd preprovision hook |
| `scripts/deploy-demo-env.ps1` | End-to-end build of the workshop environment. | Setup |
| `scripts/deploy-to-slot.ps1` | `dotnet publish` + zip + `az webapp deploy` for a named slot. | Setup, azd postdeploy hook |
| `scripts/smoke-test.ps1` | Verifies production and staging slots respond. | Setup, between runs |
| `scripts/demo-warmup.ps1` | Baseline traffic + flips `INJECT_ERROR=1` + drives `?crash=1` traffic. | Workshop Module 5 |
| `scripts/demo-rollback.ps1` | Restores `INJECT_ERROR=0` on production and re-asserts `INJECT_ERROR=1` on staging. | Workshop Module 5 / between runs |

## Tearing it down

```powershell
az group delete --name rg-sreinprod-app --yes --no-wait
```

