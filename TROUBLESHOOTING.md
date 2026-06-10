# Troubleshooting

## Setup issues

### `clone-sample-app.ps1` says the directory already exists and is not empty
Re-run with `-Force` to wipe `./sample-app/` and clone fresh:
```powershell
pwsh ./scripts/clone-sample-app.ps1 -Force
```

### `dotnet publish` fails with an SDK mismatch
The sample targets `net9.0`. Install the .NET 9 SDK (`dotnet --list-sdks`).
If your tenant pins to .NET 8, change `linuxFxVersion` to `DOTNETCORE|8.0`
in `infra/main.parameters.json` and update `TargetFramework` in the cloned
sample's `.csproj`.

### `az webapp deploy` returns 403
Confirm `az account show` matches the subscription that owns the resource
group and that your identity has at least `Website Contributor` on the
web app.

### Bicep deployment fails with `SkuNotAvailable`
The demo defaults to S1 Linux. Switch `appServicePlanSku` (parameter file)
or `AZURE_LOCATION` (`scripts/env.conf`) to a region where the SKU is
available.

## Workshop runtime issues

### Agent cannot see the workload
- Verify `APP_RESOURCE_GROUP` is attached to the agent (Module 2).
- Verify the agent's managed identity has the required RBAC assignments on that resource group.

### No telemetry appears during the workshop
- Confirm Application Insights is connected to the web app (the Bicep template wires this for you; verify the `APPLICATIONINSIGHTS_CONNECTION_STRING` app setting is present on both slots).
- Re-run `scripts/demo-warmup.ps1` to generate fresh traffic.
- Application Insights ingestion can take 1-3 minutes; wait before refreshing the Failures blade.

### Fault injection does not trigger the expected incident
- Check `INJECT_ERROR` on the production slot: `az webapp config appsettings list -g <rg> -n <app> --query "[?name=='INJECT_ERROR']"`.
- The sample only throws after the **6th** `?crash=1` request **in a single session** (cookie-tracked). The warmup script opens multiple sessions for this reason - increase `-Sessions` or `-FaultRequests` if alerts do not fire.
- The Http5xx metric alert requires >=5 failures in 5 minutes; if you only generated a few, raise the volume.

### Remediation suggestion is incomplete
- Confirm the response plan from Module 4 is attached.
- Check that App Insights, Log Analytics, and (optionally) the code repo are all connected.
- Re-prompt the agent for a step-by-step remediation plan referencing the most recent change.

### Smoke test shows HTTP 500 on the staging slot
Expected. Staging ships with `INJECT_ERROR=1`. A bare GET on `/` returns
200; only sustained `?crash=1` traffic in one session reproduces the 500.

