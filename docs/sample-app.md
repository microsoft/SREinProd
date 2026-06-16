# Sample Application

The SREinProd workshop uses
[`Azure-Samples/app-service-dotnet-agent-tutorial`](https://github.com/Azure-Samples/app-service-dotnet-agent-tutorial)
as the target workload. It is the smallest realistic surface that exercises
every capability Azure SRE Agent depends on: an App Service web app, a
deployment slot, Application Insights telemetry, and a controllable failure
mode.

## Why this app

| Requirement | How the sample meets it |
|---|---|
| Realistic web workload | .NET 9 minimal API hosted on Azure App Service (Linux) |
| Deterministic fault for drills | `INJECT_ERROR=1` app setting + `?crash=1` query string |
| Safe testing path | Failure isolated to a deployment slot; production stays healthy until you flip the switch |
| Rich telemetry surface | HTTP request metrics, App Service logs, Application Insights traces and exceptions |
| Low resource footprint | Single project, no external dependencies, runs on a Standard S1 plan |

## Behavior summary

- A counter is incremented every time a visitor sends `?crash=1` (cookie-tracked).
- When `INJECT_ERROR=1`, the **6th `?crash=1` request in a single session throws** and the platform returns HTTP 500.
- `?safe=1` resets the counter and never throws - useful for the smoke test.
- The production slot ships with `INJECT_ERROR=0` (healthy). The staging slot ships with `INJECT_ERROR=1` (faulty). `INJECT_ERROR` is registered as a slot-sticky setting, so a slot swap reliably moves the fault between slots.

## How the workshop wires it up

```text
                                   Azure App Service (Linux S1)
                                   +---------------------------+
                                   |  production (INJECT_ERROR=0)|
   Traffic / warmup script ------> |                             |
                                   |  staging    (INJECT_ERROR=1)|
                                   +---------------------------+
                                              |
                                              | logs + metrics + traces
                                              v
                              Log Analytics workspace + Application Insights
                                              |
                                              v
                                       Azure SRE Agent (Module 2)
```

The Bicep template in [`infra/main.bicep`](../infra/main.bicep) provisions
everything in the diagram except the SRE Agent itself, which is created
interactively in [Workshop Module 2](../Workshop/2-Deploy-Agent.md).

## How the code is brought in

The sample is **cloned on demand** by
[`scripts/clone-sample-app.ps1`](../scripts/clone-sample-app.ps1) into
`./sample-app/`. That directory is gitignored, so:

- this repo stays small,
- workshop runs always exercise the latest upstream code,
- license attribution stays on the upstream repo (MIT, Azure-Samples org).

`scripts/deploy-demo-env.ps1` and the `azd` `preprovision` hook both call
the clone script, so it is normally invisible to the lab participant.

## Customization knobs

| Knob | Where | What it changes |
|---|---|---|
| `SAMPLE_APP_REPO` | `scripts/env.conf` | Use a fork of the sample app. |
| `SAMPLE_APP_REF` | `scripts/env.conf` | Pin to a specific branch, tag, or commit. |
| `linuxFxVersion` | `infra/main.parameters.json` | Switch runtime (e.g. `DOTNETCORE\|8.0`) if your tenant pins the SDK. |
| `INJECT_ERROR` | `az webapp config appsettings set` | Toggle the fault for the live demo (see warmup / rollback scripts). |
| `appServicePlanSku` | `infra/main.parameters.json` | Cost vs. burst capacity tradeoff; must stay Standard+ to keep slots. |

## Demo prompts the sample supports

Once warmup has run, these prompts work well with Azure SRE Agent against
this workload:

- "We are seeing a spike of HTTP 500 errors on our production application.
  Users started reporting issues in the last few minutes. Can you investigate
  the cause of these 500 errors and identify the likely root cause?"
- "Was there a recent configuration change to this app that correlates with
  the error spike?"
- "Compare the production and staging slots - what is different in their
  application settings?"
- "Propose the safest remediation and prepare a short stakeholder summary."

The expected agent finding is that `INJECT_ERROR` differs between the two
slots, the production slot has been flipped to `1`, and reverting that app
setting (or swapping the slot back) restores service.
