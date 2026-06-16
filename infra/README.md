# Infrastructure

Bicep template for the SREinProd workshop demo workload.

Sample app: [`Azure-Samples/app-service-dotnet-agent-tutorial`](https://github.com/Azure-Samples/app-service-dotnet-agent-tutorial)
(.NET 9 minimal API that simulates HTTP 500 errors when `INJECT_ERROR=1`).

## What gets deployed

| Resource | Purpose |
|---|---|
| `Microsoft.Web/serverfarms` (Linux, S1 default) | Plan that hosts the demo app. S-tier is required to use deployment slots. |
| `Microsoft.Web/sites` (`DOTNETCORE\|9.0`) | Production slot of the demo web app. Ships with `INJECT_ERROR=0`. |
| `Microsoft.Web/sites/slots` (`staging`) | Fault-injection slot. Ships with `INJECT_ERROR=1` (slot-sticky). |
| `Microsoft.OperationalInsights/workspaces` | Log Analytics workspace backing Application Insights and diagnostic settings. |
| `Microsoft.Insights/components` (workspace-based) | Application Insights used by Azure SRE Agent for telemetry investigation. |
| `Microsoft.Insights/diagnosticSettings` (x2) | Stream `AppServiceHTTPLogs`, `AppServiceAppLogs`, `AppServiceConsoleLogs`, platform logs, and metrics from both slots to Log Analytics. |
| `Microsoft.Insights/metricAlerts` | Fires when `Http5xx` >= 5 in 5 minutes. Gives SRE Agent a real signal to investigate. |

## Slot-sticky setting

`INJECT_ERROR` is registered in `slotConfigNames.appSettingNames`. That means the
**setting stays with the slot when you swap**, which is exactly what the demo
relies on:

- swap staging -> production reproduces the fault in production
- swap back restores the healthy production configuration

## Deploy

The deployment is normally driven by [`scripts/deploy-demo-env.ps1`](../scripts/deploy-demo-env.ps1)
(or `azd up` - see [`AZD-SETUP.md`](../AZD-SETUP.md)). To run the Bicep
template directly:

```powershell
$rg = 'rg-sreinprod-app'
az group create --name $rg --location eastus2
az deployment group create `
  --resource-group $rg `
  --template-file ./infra/main.bicep `
  --parameters ./infra/main.parameters.json
```

## Parameters

| Name | Default | Notes |
|---|---|---|
| `location` | `eastus2` | Any region with App Service Linux + AI. |
| `workloadName` | `sreinprod` | 3-12 lowercase chars; drives resource names. |
| `environmentName` | `demo` | Up to 6 chars (e.g. `demo`, `lab`, `dev`). |
| `appServicePlanSku` | `S1` | Must be Standard or PremiumV3 (slots require it). |
| `linuxFxVersion` | `DOTNETCORE\|9.0` | Match the sample app's target framework. |
| `stagingSlotName` | `staging` | Name of the fault-injection slot. |

## Outputs

The template emits everything the workshop scripts and SRE Agent setup need:
`webAppName`, `webAppUrl`, `stagingUrl`, `appInsightsName`,
`appInsightsConnectionString`, `logAnalyticsWorkspaceName`, etc.

