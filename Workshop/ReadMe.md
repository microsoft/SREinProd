# Welcome to the SREinProd Workshop

This workshop is designed to help IT/Ops and SRE teams understand how Azure SRE Agent can be used with production-style signals, context, and guardrails.

The lab is built around a real workload - [`Azure-Samples/app-service-dotnet-agent-tutorial`](https://github.com/Azure-Samples/app-service-dotnet-agent-tutorial) - deployed by the Bicep template in this repo. See [`docs/sample-app.md`](../docs/sample-app.md) for the integration details, and [`AZD-SETUP.md`](../AZD-SETUP.md) or [`PS-SETUP.md`](../PS-SETUP.md) for the deployment.

## How to use these materials

The pages in this folder are the hands-on path: follow them in order during the workshop. They contain the actions, required context, safety notes, troubleshooting, and validation needed to complete each exercise.

For deeper explanations, discussion prompts, reference tables, and facilitator material, use the [Learning companion](../Learning/README.md). Each content-heavy exercise links to its matching companion page.

## Objectives

- Understand what Azure SRE Agent is and how it is different from a monitoring dashboard
- Deploy or review a working agent configuration
- Connect the agent to observability and operational systems
- Define safe response plans
- Run a realistic incident drill on the sample app
- Leave with a rollout plan for production

## Before you start

Deploy the demo environment **before** Module 1 so the agent has something real to look at. On the repo root folder, run:

```powershell
pwsh .\scripts\deploy-demo-env.ps1
```

or `azd up`. Either path produces:

- A healthy production slot of the sample web app,
- A faulty staging slot (`INJECT_ERROR=1`),
- Application Insights + Log Analytics,
- An Http5xx metric alert ready to fire during Module 6.

## Exercises

1. [Foundation](./1-Foundation.md)
2. [Deploy the Agent](./2-Deploy-Agent.md)
3. [Connectors](./3-Connectors.md)
4. [Connect Observability](./4-Connect-Observability.md)
5. [Response Plans and Guardrails](./5-Response-Plans-and-Guardrails.md)
6. [Incident Drill](./6-Incident-Drill.md)
