# Architecture

## Demo environment

The workshop deploys a small but realistic web workload that exercises
every surface Azure SRE Agent depends on. The target workload is
[`Azure-Samples/app-service-dotnet-agent-tutorial`](https://github.com/Azure-Samples/app-service-dotnet-agent-tutorial)
(.NET 9 minimal API).

```text
  Resource group: rg-sreinprod-app
  +-----------------------------------------------------+
  |  App Service plan (Linux, S1)                       |
  |    +---------------------------+                    |
  |    | Web app                   |  INJECT_ERROR=0    |  <- healthy production
  |    |  (production slot)        |                    |
  |    +---------------------------+                    |
  |    | Web app - 'staging' slot  |  INJECT_ERROR=1    |  <- fault source
  |    +---------------------------+                    |
  |          |                                          |
  |          | logs + metrics                           |
  |          v                                          |
  |    Log Analytics workspace                          |
  |          ^                                          |
  |          |                                          |
  |    Application Insights (workspace-based)           |
  |          ^                                          |
  |          | metrics                                  |
  |    Http5xx metric alert (>=5 / 5 min)               |
  +-----------------------------------------------------+
                          ^
                          |
  Resource group: rg-sreinprod-agent
  +-----------------------------------------------------+
  |  Azure SRE Agent (created in Workshop Module 2)     |
  |    - attached to rg-sreinprod-app                   |
  |    - reads from Log Analytics + App Insights        |
  |    - investigates Http5xx alert                     |
  +-----------------------------------------------------+
```

## Components

- **Demo application** - .NET 9 minimal API on Azure App Service Linux (S1).
- **Deployment slot** (`staging`) - same code, but `INJECT_ERROR=1` is
  slot-sticky, so a slot swap reliably moves the fault between slots.
- **Application Insights** (workspace-based) - request, exception, and
  dependency telemetry from both slots.
- **Log Analytics workspace** - destination for App Service diagnostic
  settings (HTTP, app, console, platform logs + metrics).
- **Http5xx metric alert** - fires when the production slot emits >=5
  HTTP 5xx responses in 5 minutes. This is the signal SRE Agent picks up
  during Module 6.
- **Azure SRE Agent** (created in Module 2) - attaches to the application
  resource group and uses the resources above as its evidence sources.
- **Optional integrations** - GitHub or Azure DevOps repository (for
  change-correlation reasoning) and an incident platform (for handoff).

## Core learning outcome

Participants should understand that SRE Agent is not just a chat surface.
It becomes useful when it has:

1. telemetry,
2. operating context,
3. response plans,
4. permissioned action paths.

The sample workload was chosen because it offers all four with the
smallest possible footprint: one app, one slot, one app setting,
one alert.
