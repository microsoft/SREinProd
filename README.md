# SREinProd Workshop

A proposed repository scaffold for a half-day workshop on deploying and using Azure SRE Agent in production.

This scaffold is intentionally modeled after the structure used in the `microsoft/AIforITOps` repository:
- a top-level README
- deployment/setup guides
- a `Workshop/` folder with numbered exercises
- `infra/` and `scripts/` folders for environment setup
- troubleshooting and facilitator assets

## What this repo is for

This workshop is designed for IT/Ops, SRE, and platform engineering teams who want to see how Azure SRE Agent can be deployed, connected to production signals, and used to investigate and remediate incidents.

## Suggested audience
- IT Pros
- SREs / platform engineers
- cloud operations teams
- Azure architects responsible for operating production workloads

## Suggested workshop narrative
1. **Teach it** – give the agent context, goals, and guardrails
2. **Connect it** – wire the agent to observability, incident, and code systems
3. **Let it work** – run a realistic incident and review outcomes

## Repo layout

```text
SREinProd/
├── README.md
├── CODE_OF_CONDUCT.md
├── LICENSE
├── SECURITY.md
├── CONTRIBUTING.md
├── azure.yaml
├── AZD-SETUP.md
├── PS-SETUP.md
├── TROUBLESHOOTING.md
├── docs/
│   ├── architecture.md
│   ├── facilitator-guide.md
│   ├── delivery-plan.md
│   └── demo-runbook.md
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
│   ├── main.bicep
│   └── main.parameters.json
├── scripts/
│   ├── env.template
│   ├── deploy-demo-env.ps1
│   ├── demo-warmup.ps1
│   ├── demo-rollback.ps1
│   └── smoke-test.ps1
└── images/
    └── .gitkeep
```

## Suggested workshop modules
See [Workshop/ReadMe.md](./Workshop/ReadMe.md).

## Notes
- This scaffold uses placeholders where environment-specific values are required.
- It is meant to accelerate content creation, not represent a finished production implementation.
