# SREinProd Workshop

A half-day workshop on deploying and using Azure SRE Agent in production.

This scaffold is intentionally modeled after the structure used in the `microsoft/AIforITOps` repository:

- a top-level README
- deployment/setup guides
- a `Workshop/` folder with numbered exercises
- `infra/` and `scripts/` folders for environment setup
- troubleshooting and facilitator assets

## What this repo is for

This workshop is designed for IT/Ops, SRE, and platform engineering teams who want to see how Azure SRE Agent can be deployed, connected to production signals, and used to investigate and remediate incidents.

## Sample workload

The lab uses [`Azure-Samples/app-service-dotnet-agent-tutorial`](https://github.com/Azure-Samples/app-service-dotnet-agent-tutorial) as the target workload: a small .NET 9 minimal-API app hosted on Azure App Service with a deployment slot, Application Insights, and a controllable HTTP 500 fault (`INJECT_ERROR=1`). See [`docs/sample-app.md`](./docs/sample-app.md) for the full integration story.

The sample is cloned on demand into `./sample-app/` by [`scripts/clone-sample-app.ps1`](./scripts/clone-sample-app.ps1) (gitignored). The supporting infrastructure - App Service plan, web app, staging slot, Log Analytics, Application Insights, and an Http5xx metric alert - is provisioned by [`infra/main.bicep`](./infra/main.bicep).

## Suggested audience

- IT Pros
- SREs / platform engineers
- cloud operations teams
- Azure architects responsible for operating production workloads

## Suggested workshop narrative

1. **Teach it** - give the agent context, goals, and guardrails
2. **Connect it** - wire the agent to observability, incident, and code systems
3. **Let it work** - run a realistic incident and review outcomes

## Quick start

Two deployment paths are wired up.

### PowerShell + az CLI (recommended)

```powershell
pwsh ./scripts/deploy-demo-env.ps1
```

Full details in [`PS-SETUP.md`](./PS-SETUP.md). The interactive [`scripts/deploy-demo-env.ps1`](./scripts/deploy-demo-env.ps1) script:

1. Checks `az`, `git`, and the .NET 9 SDK are installed.
2. Reuses your existing `az` session, or runs `az login` only if needed.
3. Prompts for the **subscription**, **resource group**, and **region** (with `scripts/env.conf` values as defaults) and persists your choices.
4. Validates the region supports Linux App Service S1.
5. Runs `az deployment group validate` as a **preflight** so quota / SKU / region issues surface immediately - and, on a quota failure, offers to re-pick the region and re-validate.
6. Deploys [`infra/main.bicep`](./infra/main.bicep) (App Service plan, web app, `staging` slot, Log Analytics, Application Insights, Http5xx alert).
7. Clones the sample app into `./sample-app/`.
8. Builds with `dotnet publish -c Release` and deploys to both the **production** and **staging** slots with `az webapp deploy --slot` (with built-in cold-start retry for first deploys on a fresh plan).
9. Runs `scripts/smoke-test.ps1` against both slots and writes the deployment outputs back into `scripts/env.conf` for the other workshop scripts to consume.

### Azure Developer CLI

```powershell
pwsh ./scripts/clone-sample-app.ps1   # required before `azd up`
azd up
```

Full details in [`AZD-SETUP.md`](./AZD-SETUP.md). Note the [two known sharp edges](./AZD-SETUP.md#known-issues-with-the-azd-path) on slot-enabled App Service apps (init-time project validation and a slot-deploy hang).

Both paths produce the same environment: a healthy production slot, a faulty staging slot, Application Insights wired up, and an Http5xx alert ready for Azure SRE Agent to investigate during [Module 6](./Workshop/6-Incident-Drill.md).

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
