# Welcome to the SREinProd Workshop

This workshop is designed to help IT/Ops and SRE teams understand how Azure SRE Agent can be used with production-style signals, context, and guardrails.

The lab is built around a real workload - [`Azure-Samples/app-service-dotnet-agent-tutorial`](https://github.com/Azure-Samples/app-service-dotnet-agent-tutorial) - deployed by the Bicep template in this repo. See [`docs/sample-app.md`](../docs/sample-app.md) for the integration details, and [`AZD-SETUP.md`](../AZD-SETUP.md) or [`PS-SETUP.md`](../PS-SETUP.md) for the deployment.

## Objectives

- understand what Azure SRE Agent is and how it is different from a monitoring dashboard
- deploy or review a working agent configuration
- connect the agent to observability and operational systems
- define safe response plans
- run a realistic incident drill on the sample app
- leave with a rollout plan for production

## Before you start

Deploy the demo environment **before** Module 1 so the agent has something real to look at:

```powershell
Copy-Item ..\scripts\env.template ..\scripts\env.conf
pwsh ..\scripts\deploy-demo-env.ps1
```

or `azd up`. Either path produces:

- a healthy production slot of the sample web app,
- a faulty staging slot (`INJECT_ERROR=1`),
- Application Insights + Log Analytics,
- an Http5xx metric alert ready to fire during Module 6.

## Exercises

1. [Foundation](./1-Foundation.md)
2. [Deploy the Agent](./2-Deploy-Agent.md)
3. [Connectors](./3-Connectors.md)
4. [Connect Observability](./4-Connect-Observability.md)
5. [Response Plans and Guardrails](./5-Response-Plans-and-Guardrails.md)
6. [Incident Drill](./6-Incident-Drill.md)
7. [Production Rollout](./7-Production-Rollout.md)
8. [Bonus](./Bonus.md)
