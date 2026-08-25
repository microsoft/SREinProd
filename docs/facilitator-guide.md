# Facilitator Guide

## Delivery style

- Optimize for operators, not feature tours.
- Show what happens during an actual incident.
- Minimize manual portal clicking where possible.
- Use a pre-provisioned environment when time is constrained.

## Facilitation tips

- Start with review mode.
- Explain why guardrails matter.
- Narrate the evidence chain the agent is using.

## Sample workload

The lab uses [`Azure-Samples/app-service-dotnet-agent-tutorial`](https://github.com/Azure-Samples/app-service-dotnet-agent-tutorial) (.NET 9 minimal API on App Service). See [`docs/sample-app.md`](./sample-app.md) for the integration story and [`docs/demo-runbook.md`](./demo-runbook.md) for the live drill steps.

## Pre-event runtime checklist

- [ ] `pwsh ./scripts/deploy-demo-env.ps1` (or `azd up`) ran cleanly within the last 24 hours.
- [ ] `pwsh ./scripts/smoke-test.ps1` returns 200 on both slots.
- [ ] Azure SRE Agent is created and attached to `APP_RESOURCE_GROUP`.
- [ ] You have run the full Module 6 drill end-to-end at least once, including `demo-rollback.ps1`.
