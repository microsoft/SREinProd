# Demo Runbook

Live runbook for the SREinProd workshop incident drill. The workload is
the .NET 9 sample app deployed by `infra/main.bicep` (see
[`docs/sample-app.md`](./sample-app.md)).

## Scenario

- Production slot of the demo app is healthy (`INJECT_ERROR=0`).
- Workshop warmup generates baseline traffic.
- Fault injection flips `INJECT_ERROR=1` on the production slot **or**
  swaps the staging slot (which already has `INJECT_ERROR=1`) into
  production. Both routes produce the same symptom: HTTP 500 on the 6th
  `?crash=1` request per session.
- Application Insights records the exception trace and request failures.
- The Http5xx metric alert fires within ~5 minutes.
- Azure SRE Agent investigates, correlates the recent app-setting change
  with the error spike, and proposes reverting the change.

## Pre-demo checklist

- [ ] `scripts/env.conf` exists and contains the deployment outputs.
- [ ] `pwsh ./scripts/smoke-test.ps1` returns 200 on both slots.
- [ ] Azure SRE Agent is created (Module 2) and attached to `APP_RESOURCE_GROUP`.
- [ ] Application Insights connection is healthy (Module 4).
- [ ] Response plan from Module 5 is saved and in review mode.
- [ ] Workshop chat / portal tab is open on the SRE Agent.

## Drill steps

```powershell
# 1. Drive baseline traffic and inject the fault
pwsh ./scripts/demo-warmup.ps1

# 2. Wait ~3-5 minutes for the alert to fire and AI to ingest exceptions.
#    Watch the alert and the Failures blade in App Insights while you wait.

# 3. Ask the agent to investigate.
```

## Investigation prompt

```text
We are seeing a spike of HTTP 500 errors on our production application.
Users started reporting issues in the last few minutes.
Can you investigate the cause of these 500 errors and identify the likely
root cause?
```

Expected agent findings:

- HTTP 5xx rate increased on the production slot of the `app-sreinprod-*` web app.
- Exception traces in Application Insights show `Simulated error after 5 button clicks!` thrown from `Program.cs`.
- The `INJECT_ERROR` app setting on the production slot was recently changed from `0` to `1`.
- Safest remediation: set `INJECT_ERROR=0` on the production slot (or swap the slot back).

## Remediation prompt

```text
Please proceed with the safest remediation you recommend and provide a
concise incident summary I can share with stakeholders.
```

## Reset between runs

```powershell
pwsh ./scripts/demo-rollback.ps1
```

This sets `INJECT_ERROR=0` on production, re-asserts `INJECT_ERROR=1` on
staging, and runs the smoke test.
