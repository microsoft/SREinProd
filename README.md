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

Two equivalent deployment paths are wired up:

- **Azure Developer CLI** - one command (`azd up`). See [`AZD-SETUP.md`](./AZD-SETUP.md).
- **PowerShell + az CLI** - explicit, classroom-friendly. See [`PS-SETUP.md`](./PS-SETUP.md).

Both paths produce the same environment: a healthy production slot, a faulty staging slot, Application Insights wired up, and an Http5xx alert ready for Azure SRE Agent to investigate during [Module 5](./Workshop/5-Incident-Drill.md).

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
│   ├── 3-Connect-Observability.md
│   ├── 4-Response-Plans-and-Guardrails.md
│   ├── 5-Incident-Drill.md
│   ├── 6-Production-Rollout.md
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

