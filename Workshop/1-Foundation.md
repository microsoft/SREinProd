# Module 1 - Foundation

## Objective

Reset expectations before anyone touches a portal: this workshop is about **operating systems in production**, not just chatting with an agent. By the end of this module participants should be able to explain, in their own words, what Azure SRE Agent is, what problem it solves, and where it sits in their existing tooling.

> Time: ~30 min (10 min framing, 15 min discussion, 5 min recap).
> No hands-on yet; everything in this module is whiteboard, slides, and discussion. The first deploy happens in [Module 2](./2-Deploy-Agent.md).

## What Azure SRE Agent is (one paragraph)

Azure SRE Agent is a managed AI agent service that connects to your **observability stack** (Azure Monitor, Application Insights, Log Analytics, Grafana), your **incident platforms** (Azure Monitor Alerts, PagerDuty, ServiceNow), and your **source control** (GitHub, Azure DevOps), and uses that context to **triage, investigate, and (when allowed) remediate** incidents on Azure resources. It is provisioned as a first-class Azure resource (`Microsoft.App/SREAgents`), runs under a managed identity, and is governed by Azure RBAC just like any other resource. It is **not** a chatbot bolted onto Azure Monitor; the chat is the surface, the value is the closed loop behind it.

Source: [Azure SRE Agent overview on Microsoft Learn](https://learn.microsoft.com/azure/sre-agent/overview).

## The four-layer mental model

Use this slide to anchor every later module. Most teams already do layer 1; the agent's job is to make 2, 3, and 4 fast and consistent.

| # | Layer | Question it answers | Where it usually lives today | Where it lives in this workshop |
| --- | --- | --- | --- | --- |
| 1 | **Monitoring** | *Is something wrong?* | Dashboards, metric alerts | Http5xx alert in [`infra/main.bicep`](../infra/main.bicep) |
| 2 | **Investigation** | *What is wrong, and why?* | Tribal knowledge + 6 browser tabs | SRE Agent chat ([Module 5](./5-Incident-Drill.md)) |
| 3 | **Remediation** | *How do we make it stop?* | Runbooks, on-call ad-hoc CLI | Agent guardrails + RBAC ([Module 4](./4-Response-Plans-and-Guardrails.md)) |
| 4 | **Institutional learning** | *How do we not see this again?* | Post-mortem docs nobody re-reads | Agent memory ([Bonus](./Bonus.md)) |

> **The workshop's central claim:** dashboards are necessary but not sufficient. They tell you *that* something is wrong; they don't tell you *what changed* across resource configuration, code, deployments, and alerts at the same time. SRE Agent's differentiator is correlating those signals **and** remembering what worked last time.

## Why incidents take too long today

Walk through these as a mini-diagnostic of the room. Most teams will recognize at least three of the four.

1. **Signal sprawl.** Telemetry is split across Application Insights, App Service logs, Activity Log, alert rules, and the deployment pipeline. Each lives in its own pane of glass and uses its own query language.
2. **Cross-layer RCA is slow.** A spike of HTTP 500s could be code, configuration, infra, or upstream dependency. Correlating "an app setting changed at 14:02" with "5xx started at 14:03" is currently a human's pattern-matching job.
3. **Context is trapped.** The engineer who last debugged this exact failure mode in March is on PTO. The post-mortem doc is in a wiki nobody opened since.
4. **Action is gated by access.** Even when the fix is obvious, the on-call may not have the role to flip the app setting and is paging someone who does.

SRE Agent attacks each of these directly: it queries every observability surface from one prompt (1), correlates change/telemetry/code in a single investigation (2), persists what it learns across conversations (3), and runs under its own RBAC-scoped identity that *you* control the blast radius of (4).

## What makes SRE Agent different from a "smart dashboard"

| Dimension | Monitoring dashboard | LLM chatbot bolt-on | **Azure SRE Agent** |
| --- | --- | --- | --- |
| Asks queries on your behalf | No | Sometimes | **Yes** (KQL, ARM, REST, az CLI) |
| Correlates across services | Manual | Hallucination-prone | **Grounded in your resources via RBAC** |
| Remembers past investigations | No | Per-session only | **Persistent agent memory** |
| Can take action | No | No | **Yes, when granted RBAC + an approved response plan** |
| Governed by Azure identity & policy | N/A | N/A | **Managed identity + role assignments + audit log** |
| Extensible | Custom dashboards | Custom prompts | **Custom runbooks, sub-agents, MCP servers** |

The "can take action, but only when permitted" row is the one that matters for production use, and it's the one that drives the workshop's emphasis on guardrails in Module 4.

## How the agent actually works (under the hood)

Capture this on the whiteboard as you talk through the architecture. The same picture is reinforced in [`docs/architecture.md`](../docs/architecture.md).

```text
                       +---------------------------+
   You / on-call --->  |  SRE Agent chat surface   |
                       +-------------+-------------+
                                     |
                                     v
                  +----------------------------------+
                  |  Reasoning loop (Anthropic / AOAI) |
                  |  + agent memory (per agent)        |
                  +----+--------------+--------------+
                       |              |              |
       Azure RBAC      |   GitHub /   |  Incident /  |  Custom
     (managed identity)|  Azure DevOps|  Monitoring  |  runbooks
                       v              v              v
                +-----------+   +-----------+   +-----------+
                |  Azure    |   |  Code &   |   | Alerts,   |
                |  resources|   |  changes  |   | logs,     |
                |  (ARM/REST|   |  (repos)  |   | metrics   |
                |  /az CLI) |   +-----------+   +-----------+
                +-----------+
```

Three things to call out from this diagram:

- The **agent is an Azure resource**, not a SaaS endpoint. Creating one auto-provisions a Managed Identity, an Application Insights instance, and a Log Analytics workspace for the agent's own telemetry. You'll see those appear during [Module 2](./2-Deploy-Agent.md).
- It only sees what **you grant it** via Azure RBAC. The workshop uses RG-scoped Privileged-mode permissions on `rg-sreinprod-app`, which is the *least-privilege* path that still lets the agent execute approved remediations.
- The **memory** belongs to the agent resource. Delete the agent and the memory goes with it; that's why production rollout (Module 6) treats the agent as a long-lived first-class resource, not a sandbox.

## The supported integration surface (today)

This is the catalog of "places the agent can pull context from", useful when participants ask *"can it talk to X?"* during discussion. Source: the **Integrations** section of the [official overview](https://learn.microsoft.com/azure/sre-agent/overview).

| Category | Built-in integrations |
| --- | --- |
| **Monitoring & observability** | Azure Monitor (metrics, logs, alerts, workbooks), Application Insights, Log Analytics, Grafana |
| **Incident management** | Azure Monitor Alerts, PagerDuty, ServiceNow |
| **Source control / CI-CD** | GitHub (repositories, issues), Azure DevOps (repos, work items) |
| **Data sources** | Azure Data Explorer (Kusto) clusters, Model Context Protocol (MCP) servers |
| **Azure service management** | Compute (VMs, App Service, ACA, AKS, Functions), Storage, Networking, SQL/Cosmos/PostgreSQL/MySQL/Redis, Azure Monitor / Resource Manager, all managed via Azure CLI and REST APIs |

> Anything not in this table is reachable via **custom runbooks** (any az CLI / REST call) or **sub-agents / MCP** for non-Azure systems. Module 6 covers when to reach beyond this list.

## Where each capability shows up in this workshop

| Capability | Demonstrated in |
| --- | --- |
| Provisioning the agent + RBAC scoping | [Module 2: Deploy the Agent](./2-Deploy-Agent.md) |
| Connecting telemetry sources & code | [Module 3: Connect Observability](./3-Connect-Observability.md) |
| Approval-gated remediation, response plans, guardrails | [Module 4: Response Plans and Guardrails](./4-Response-Plans-and-Guardrails.md) |
| End-to-end investigation against a real fault | [Module 5: Incident Drill](./5-Incident-Drill.md) |
| Multi-environment rollout, custom runbooks, sub-agents | [Module 6: Production Rollout](./6-Production-Rollout.md) |
| Memory, scheduled tasks, MCP extensibility | [Bonus](./Bonus.md) |

## Key discussion points

Use these as the framing for the room before going any further. The workshop's value-per-minute is highest when participants come to Module 5 having already articulated the gap between *dashboards* and *operating systems*.

- **Why incidents take too long to resolve.** Where does *your* MTTR actually go: detection, triage, RCA, fix, or comms?
- **Why dashboards alone are not enough.** A dashboard tells you *something* is wrong; what tells you *why*?
- **Why cross-layer RCA is slow.** When a 5xx fires, how many panes of glass does your on-call open?
- **Why context and guardrails matter.** What stops you from just letting an LLM `az webapp restart` everything? (Answer that becomes Module 4.)

## Facilitator prompts

Open-ended versions of the discussion points above. Pick 2 to 3 based on the room.

- *"What slows your team down during incidents today?"* This usually surfaces tooling sprawl and access bottlenecks.
- *"Which tools do you switch between most often during an investigation?"* This maps directly to the Integrations table above.
- *"What knowledge is usually trapped in past incidents?"* This leads into the memory discussion.
- *"What's the smallest action you'd be willing to let an agent take unattended?"* This primes Module 4's guardrail conversation.
- *"If your best on-call engineer left tomorrow, what would you lose?"* This primes the *Knowledge that never leaves* slide for [Bonus](./Bonus.md).

## What the agent will *not* do (managing expectations)

Worth saying out loud before anyone gets into the chat in Module 2. Source: [Considerations](https://learn.microsoft.com/azure/sre-agent/overview#considerations) on the overview page, plus workshop experience.

- It's **English-only** in chat today.
- It will **not** take destructive actions outside the RBAC surface you granted it. If you used Reader-mode permissions in Module 2, the agent will *propose* fixes but not *apply* them.
- It will **not** automatically connect to systems you didn't explicitly wire up. There's no implicit network discovery.
- It is **regional**. Today it's available in *East US 2*, *Sweden Central*, and *Australia East* (the workshop uses East US 2). Availability also varies by tenant configuration.
- It is **not a replacement for your monitoring stack**. It sits on top of it and makes it useful.

## Expected outcome

By the end of Module 1 every participant should be able to explain, **without looking at slides**, the difference between:

- **monitoring** (the dashboard tells me something is off),
- **investigation** (something correlates the signals and tells me why),
- **remediation** (something safely takes the action that fixes it), and
- **institutional learning** (what we learned from this incident is available the next time it happens, even to someone who wasn't on call).

If the room can articulate that distinction in their own words, you're ready for [Module 2](./2-Deploy-Agent.md).

## Further reading (optional, for the curious)

- [Azure SRE Agent: Overview](https://learn.microsoft.com/azure/sre-agent/overview): the official feature catalog.
- [Memory and knowledge](https://learn.microsoft.com/azure/sre-agent/memory): how the agent persists what it learns.
- [Sub-agents](https://learn.microsoft.com/azure/sre-agent/sub-agents): extending the agent to specialized domains.
- [`docs/architecture.md`](../docs/architecture.md): how this specific workshop's demo environment is wired.
- [`docs/sample-app.md`](../docs/sample-app.md): the .NET sample app and the deterministic `INJECT_ERROR` fault used in Module 5.
