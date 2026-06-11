# Troubleshooting

## Setup issues

### Preflight validation fails with `SubscriptionIsOverQuotaForSku`
`scripts/deploy-demo-env.ps1` runs `az deployment group validate` before
the real deploy specifically to catch this. The error message also names
the limit (for example, *"Current Limit (Total VMs): 1, Current Usage: 1"*).
In interactive mode the script offers to **pick a different region** and
re-validates. To skip the prompt loop on CI, choose the region up-front:

```powershell
pwsh ./scripts/deploy-demo-env.ps1 -Location canadacentral -NonInteractive ...
```

If you must stay in the original region, request a quota increase before
re-running:
[Microsoft Learn: request a quota increase](https://learn.microsoft.com/azure/quotas/quickstart-increase-quota-portal).

### `azd up` fails with `could not locate a dotnet project file for service app`
`azd` validates the `services.app.project` path at init time, *before* any
hook can fire. The sample must already be on disk. Run the clone script
first, then re-run `azd up`:

```powershell
pwsh ./scripts/clone-sample-app.ps1
azd up
```

### `azd deploy` hangs on `Checking deployment slots`
Known issue on slot-enabled App Service apps: `azd`'s App Service publisher
can stall here for tens of minutes and then time out. Use the PowerShell
path instead - it deploys both slots directly with `az webapp deploy
--slot`, which completes in under a minute per slot:

```powershell
pwsh ./scripts/deploy-demo-env.ps1
```

### `clone-sample-app.ps1` says the directory already exists and is not empty
The script is idempotent for the normal cases (empty dir, existing git
clone, dir containing only `PLACEHOLDER.md`). If you hit this error after
a partial / aborted run, wipe and re-clone:
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
available. `scripts/deploy-demo-env.ps1` also runs `az appservice
list-locations --linux-workers-enabled --sku S1` to validate the region
before submitting the deployment.

### `az login` fails / loops across many tenants
`scripts/deploy-demo-env.ps1` only calls `az login` when `az account show`
returns no context, so a working `az` session is reused. If you have
several tenants with Conditional Access policies and the script does
trigger a login, sign in to the **specific tenant** that owns your
subscription:

```powershell
az logout
az login --tenant <your-tenant-id-or-domain>
pwsh ./scripts/deploy-demo-env.ps1 -SubscriptionId <id>
```

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

