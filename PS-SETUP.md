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

## One-shot path (recommended for live demos and CI)

> This is now the **primary** deployment path for the workshop. It is more reliable than the [`azd up`](./AZD-SETUP.md) flow on slot-enabled App Service apps (`azd` is known to hang on "Checking deployment slots").

```powershell
# Fully interactive - the script prompts for subscription, region, and resource group
pwsh .\scripts\deploy-demo-env.ps1
```

Or pass everything up-front for unattended runs:

```powershell
pwsh .\scripts\deploy-demo-env.ps1 `
    -SubscriptionId <your-sub-id> `
    -ResourceGroup  rg-sreinprod-demo `
    -Location       canadacentral `
    -NonInteractive
```

The script will:

1. Verify `az`, `git`, and **.NET 9 SDK** are on PATH.
2. Seed `scripts/env.conf` from `env.template` if it does not exist.
3. Resolve the Azure context (uses the current `az` session and **only triggers `az login` when needed** - avoids MFA loops across multiple tenants).
4. Prompt for **subscription / region / resource group** (showing the values already in `env.conf` as defaults). The chosen values are persisted to `env.conf` immediately so re-runs are unattended.
5. Validate that the selected region offers Linux App Service S1.
6. Create the resource group with the workshop tags.
7. **PREFLIGHT**: run `az deployment group validate` so quota / SKU / region issues surface in seconds instead of after a partial deployment. On `SubscriptionIsOverQuotaForSku`, the script **offers to re-select the region** and re-validates.
8. Deploy `infra/main.bicep` (App Service plan, web app, staging slot, Log Analytics, Application Insights, Http5xx alert).
9. Clone the sample app into `./sample-app/`.
10. Build with `dotnet publish -c Release`, zip the output, and deploy it to the **production slot** and the **staging slot** with `az webapp deploy --slot` (bypasses the `azd` slot-check hang).
11. Run `scripts/smoke-test.ps1` against both slots.
12. Write the deployment outputs back into `scripts/env.conf` for the other scripts to consume.

### Useful parameters

| Parameter | Effect |
|---|---|
| `-SubscriptionId <id-or-name>` | Skip the subscription prompt. |
| `-ResourceGroup <name>` | Skip the resource group prompt. |
| `-Location <region>` | Skip the region prompt. |
| `-WorkloadName <name>` / `-EnvironmentName <name>` | Override the resource-naming prefix/suffix. |
| `-NonInteractive` | Fail instead of prompting when a required value is missing (CI mode). |
| `-SkipAppDeploy` | Provision infra only; do not build or deploy the sample app. |
| `-EnvFile <path>` | Use a different env file (default `scripts/env.conf`). |

## Step-by-step path (for teaching)

If you want to walk through the pieces individually:

```powershell
# 1. Pull the sample app
pwsh .\scripts\clone-sample-app.ps1

# 2. Create the resource group
az group create --name rg-sreinprod-app --location canadacentral

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

