# PowerShell Setup

**Primary deployment path** for the SREinProd workshop. Uses `az` + PowerShell and is more reliable than the [`azd up`](./AZD-SETUP.md) flow on slot-enabled App Service apps.

Sample workload: [`Azure-Samples/app-service-dotnet-agent-tutorial`](https://github.com/Azure-Samples/app-service-dotnet-agent-tutorial)

## What the PowerShell deploy does in this repo

[`scripts/deploy-demo-env.ps1`](./scripts/deploy-demo-env.ps1) is a single, idempotent entry point that goes from "freshly cloned repo" to "workshop ready" without any further interaction:

1. **Tooling check.** Verifies `az`, `git`, and a .NET 9 SDK are on PATH.
2. **Env file.** Seeds [`scripts/env.conf`](./scripts/env.template) from `env.template` if it does not exist.
3. **Azure context.** Uses the current `az` session; **only triggers `az login` when `az account show` returns nothing** (avoids MFA loops across multiple tenants).
4. **Interactive prompts.** Asks for **subscription**, **region**, and **resource group**, showing the values already in `env.conf` as defaults. All chosen values are persisted to `env.conf` immediately so the next run is unattended.
5. **Region validation.** Confirms the chosen region offers Linux App Service S1 via `az appservice list-locations --linux-workers-enabled --sku S1`.
6. **Resource group.** Creates `APP_RESOURCE_GROUP` with the workshop tags.
7. **Preflight.** Runs `az deployment group validate` against [`infra/main.bicep`](./infra/main.bicep) so quota / SKU / region issues surface in seconds. On `SubscriptionIsOverQuotaForSku`, the script **offers to pick a different region** and re-validates in a loop.
8. **Infra deploy.** `az deployment group create` for [`infra/main.bicep`](./infra/main.bicep) - App Service plan (Linux S1), web app, `staging` slot, Log Analytics workspace, Application Insights, diagnostic settings, and an Http5xx metric alert. The Bicep seeds slot config so the **production slot is healthy** and the **staging slot has `INJECT_ERROR=1`** (slot-sticky).
9. **Clone sample.** Idempotently clones [`Azure-Samples/app-service-dotnet-agent-tutorial`](https://github.com/Azure-Samples/app-service-dotnet-agent-tutorial) into `./sample-app/` via [`scripts/clone-sample-app.ps1`](./scripts/clone-sample-app.ps1).
10. **App deploy - production slot.** `dotnet publish -c Release` + `Compress-Archive` + `az webapp deploy --type zip` via [`scripts/deploy-to-slot.ps1`](./scripts/deploy-to-slot.ps1). Built-in cold-start retry: if `az` reports the 10-minute polling timeout on a first deploy, the script probes the slot URL for an extra 5 minutes before failing.
11. **App deploy - staging slot.** Same helper with `--slot staging`.
12. **Smoke test.** [`scripts/smoke-test.ps1`](./scripts/smoke-test.ps1) hits both slots and prints the status.
13. **Outputs back to `env.conf`.** Writes `APP_NAME`, `APP_URL`, `STAGING_URL`, `APP_INSIGHTS_NAME`, and `LOG_ANALYTICS_WORKSPACE` so [`scripts/demo-warmup.ps1`](./scripts/demo-warmup.ps1), [`scripts/demo-rollback.ps1`](./scripts/demo-rollback.ps1), and the other workshop scripts work without further configuration.

When the script finishes you have:

- **Production URL** - healthy; suitable for the baseline traffic generator.
- **Staging URL** - configured with `INJECT_ERROR=1`; the 6th `?crash=1` request per session throws.
- **Application Insights** - already wired; SRE Agent picks this up in Module 4.
- **Http5xx metric alert** - fires on >=5 failures in 5 minutes; the signal SRE Agent investigates in Module 6.

## Prerequisites

- PowerShell 7+ (`pwsh --version`)
- Azure CLI (`az --version`)
- .NET 9 SDK (`dotnet --list-sdks`)
- Git (`git --version`)
- Permissions to create resource groups in your target subscription

## One-shot path (recommended for live demos and CI)

> This is the **primary** deployment path for the workshop. It is more reliable than the [`azd up`](./AZD-SETUP.md) flow on slot-enabled App Service apps (`azd` is known to hang on "Checking deployment slots").

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

See [What the PowerShell deploy does in this repo](#what-the-powershell-deploy-does-in-this-repo) above for the step-by-step breakdown of what the script does behind the scenes.

### Useful parameters

| Parameter | Effect |
| --- | --- |
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
| --- | --- | --- |
| `scripts/clone-sample-app.ps1` | Idempotently clones the upstream sample into `./sample-app/`. | Setup, azd preprovision hook |
| `scripts/deploy-demo-env.ps1` | End-to-end build of the workshop environment. | Setup |
| `scripts/deploy-to-slot.ps1` | `dotnet publish` + zip + `az webapp deploy` for a named slot. | Setup, azd postdeploy hook |
| `scripts/smoke-test.ps1` | Verifies production and staging slots respond. | Setup, between runs |
| `scripts/demo-warmup.ps1` | Baseline traffic + flips `INJECT_ERROR=1` + drives `?crash=1` traffic. | Workshop Module 6 |
| `scripts/demo-rollback.ps1` | Restores `INJECT_ERROR=0` on production and re-asserts `INJECT_ERROR=1` on staging. | Workshop Module 6 / between runs |

## Tearing it down

```powershell
az group delete --name rg-sreinprod-app --yes --no-wait
```
