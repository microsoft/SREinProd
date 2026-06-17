# SREinProd Workshop

A half-day workshop on deploying and using Azure SRE Agent in productionThis workshop is designed for IT/Ops, SRE, and platform engineering teams who want to see how Azure SRE Agent can be deployed, connected to production signals, and used to investigate and remediate incidents.

## Suggested audience

- IT Pros
- SREs / platform engineers
- cloud operations teams
- Azure architects responsible for operating production workloads

## Suggested workshop narrative

1. **Teach it** - give the agent context, goals, and guardrails
2. **Connect it** - wire the agent to observability, incident, and code systems
3. **Let it work** - run a realistic incident and review outcomes

## Sample workload and deployment

The lab uses [`Azure-Samples/app-service-dotnet-agent-tutorial`](https://github.com/Azure-Samples/app-service-dotnet-agent-tutorial) as the target workload: a small .NET 9 minimal-API app hosted on Azure App Service with a deployment slot, Application Insights, and a controllable HTTP 500 fault (`INJECT_ERROR=1`). See [`docs/sample-app.md`](./docs/sample-app.md) for the full integration story.

### One-command deploy

Prerequisites: `az`, `git`, `pwsh` 7+, and the .NET 9 SDK on PATH.

> **Important: regional quota.** The workshop deploys an **App Service Linux Standard (S1)** plan, which requires a non-zero per-region instance quota. On many internal, sponsored, MPN, and CSP subscriptions, `eastus` and `eastus2` are capped at **0 instances** for this SKU and the deploy will fail at preflight with `SubscriptionIsOverQuotaForSku`. The interactive script therefore offers a curated picker with three regions known to have quota on typical workshop subscriptions: **`canadacentral`**, **`westus3`**, and **`swedencentral`**. If you must use a different region, request an App Service Standard Linux instance quota increase first (Portal: Subscription, Usage + quotas, App Service, region, Request increase).

```powershell
pwsh ./scripts/deploy-demo-env.ps1
```

That single command provisions the infrastructure, clones the sample, builds it, deploys both slots, and runs smoke tests. The interactive [`scripts/deploy-demo-env.ps1`](./scripts/deploy-demo-env.ps1) script:

1. Checks `az`, `git`, and the .NET 9 SDK are installed.
2. Reuses your existing `az` session, or runs `az login` only if needed.
3. Prompts for the **subscription**, **resource group**, and **region** (with `scripts/env.conf` values as defaults) and persists your choices.
4. Validates the region supports Linux App Service S1.
5. Runs `az deployment group validate` as a **preflight** so quota / SKU / region issues surface immediately, and on a quota failure offers to re-pick the region and re-validate.
6. Deploys [`infra/main.bicep`](./infra/main.bicep) (App Service plan, web app, `staging` slot, Log Analytics, Application Insights, Http5xx alert).
7. Clones the sample app into `./sample-app/` (gitignored) via [`scripts/clone-sample-app.ps1`](./scripts/clone-sample-app.ps1).
8. Builds with `dotnet publish -c Release` and deploys to both the **production** and **staging** slots with `az webapp deploy --slot` (with built-in cold-start retry for first deploys on a fresh plan).
9. Runs [`scripts/smoke-test.ps1`](./scripts/smoke-test.ps1) against both slots and writes the deployment outputs back into `scripts/env.conf` for the other workshop scripts to consume.

End state: a healthy production slot, a faulty staging slot, Application Insights wired up, and an Http5xx alert ready for Azure SRE Agent to investigate during [Module 6](./Workshop/6-Incident-Drill.md). Full parameter reference and unattended/CI usage in [`PS-SETUP.md`](./PS-SETUP.md).

### Alternate: Azure Developer CLI

If you prefer `azd`, the same infra and sample are wired up via `azure.yaml`. The `azd` flow has two known sharp edges on slot-enabled App Service apps (init-time project validation and a slot-deploy hang), so the PowerShell path above is recommended. See [`AZD-SETUP.md`](./AZD-SETUP.md) for the full steps and workarounds.

## Repo layout

```text
SREinProd/
├── README.md
├── CODE_OF_CONDUCT.md
├── LICENSE
├── SECURITY.md
├── CONTRIBUTING.md
├── azure.yaml                 # azd definition (points to ./sample-app)
├── AZD-SETUP.md
├── PS-SETUP.md
├── TROUBLESHOOTING.md
├── docs/
│   ├── architecture.md
│   ├── facilitator-guide.md
│   ├── delivery-plan.md
│   ├── demo-runbook.md
│   └── sample-app.md          # integration story for the .NET sample
├── Workshop/
│   ├── ReadMe.md
│   ├── 1-Foundation.md
│   ├── 2-Deploy-Agent.md
│   ├── 3-Connectors.md
│   ├── 4-Connect-Observability.md
│   ├── 5-Response-Plans-and-Guardrails.md
│   ├── 6-Incident-Drill.md
│   ├── 7-Production-Rollout.md
│   └── Bonus.md
├── infra/
│   ├── README.md
│   ├── main.bicep             # App Service + slot + AI + LA + Http5xx alert
│   └── main.parameters.json
├── scripts/
│   ├── env.template           # copy to env.conf (gitignored) and fill in
│   ├── clone-sample-app.ps1   # idempotent clone of the upstream sample
│   ├── deploy-demo-env.ps1    # end-to-end environment build
│   ├── deploy-to-slot.ps1     # build + zip + deploy helper
│   ├── demo-warmup.ps1        # baseline traffic + fault injection
│   ├── demo-rollback.ps1      # restore env between runs
│   └── smoke-test.ps1
└── sample-app/                # cloned on demand; gitignored
```

## Suggested workshop modules

See [Workshop/ReadMe.md](./Workshop/ReadMe.md).

## Notes

- The sample application is licensed MIT by Microsoft `Azure-Samples`. This repo ships only the infra/scripts/docs needed to integrate it.
- Tenant-specific values (subscription, region, regional quotas) belong in `scripts/env.conf`, which is gitignored.
