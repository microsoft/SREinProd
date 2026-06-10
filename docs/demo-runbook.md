# Demo Runbook (generalized starter)

This starter runbook is inspired by an existing internal demo flow, but it uses placeholders so it can be reused safely.

## Scenario
- Baseline application is healthy
- Workshop warmup generates normal traffic
- Fault injection flips an application setting or swaps a broken slot
- Azure SRE Agent investigates, identifies the root cause, and proposes remediation

## Pre-demo checklist
- Open the Azure SRE Agent portal
- Sign in with an account that has the necessary RBAC roles
- Verify the agent is attached to the workshop resource group
- Verify the observability connector is healthy
- Run `scripts/demo-warmup.ps1`
- Wait for telemetry to appear before starting the live walkthrough

## Investigation prompt
```text
We are seeing a spike of HTTP 500 errors on our production application.
Users started reporting issues in the last few minutes.
Can you investigate the cause of these 500 errors and identify the likely root cause?
```

## Remediation prompt
```text
Please proceed with the safest remediation you recommend and provide a concise incident summary I can share with stakeholders.
```
