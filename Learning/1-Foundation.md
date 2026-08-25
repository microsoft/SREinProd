# Module 1 Learning - Foundation

[← Back to the Foundation workshop exercise](../Workshop/1-Foundation.md) | [Learning home](./README.md)

## Purpose

This companion provides the deeper concepts and discussion material behind the guided [Foundation workshop exercise](../Workshop/1-Foundation.md). The exercise is about **operating systems in production**, not just chatting with an agent.

## What Azure SRE Agent is

Azure SRE Agent is a managed AI agent service that connects to your **observability stack** (Azure Monitor, Application Insights, Log Analytics, Grafana), your **incident platforms** (Azure Monitor Alerts, PagerDuty, ServiceNow), and your **source control** (GitHub, Azure DevOps), and uses that context to **triage, investigate, and (when allowed) remediate** incidents on Azure resources. It is provisioned as a first-class Azure resource (`Microsoft.App/SREAgents`), runs under a managed identity, and is governed by Azure RBAC just like any other resource. It is **not** a chatbot bolted onto Azure Monitor; the chat is the surface, the value is the closed loop behind it.

Source: [Azure SRE Agent overview on Microsoft Learn](https://learn.microsoft.com/azure/sre-agent/overview).

## The four-layer mental model

Use this model to anchor every later module. Most teams already do layer 1; the agent's job is to make 2, 3, and 4 fast and consistent.

| # | Layer | Question it answers | Where it usually lives today | Where it lives in this workshop |
| --- | --- | --- | --- | --- |
| 1 | **Monitoring** | *Is something wrong?* | Dashboards, metric alerts | Http5xx alert in [`infra/main.bicep`](../infra/main.bicep) |
| 2 | **Investigation** | *What is wrong, and why?* | Tribal knowledge + 6 browser tabs | SRE Agent chat ([Module 6](../Workshop/6-Incident-Drill.md)) |
| 3 | **Remediation** | *How do we make it stop?* | Runbooks, on-call ad-hoc CLI | Agent guardrails + RBAC ([Module 5](../Workshop/5-Response-Plans-and-Guardrails.md)) |
| 4 | **Institutional learning** | *How do we not see this again?* | Post-mortem docs nobody re-reads | Agent memory |

> **The workshop's central claim:** dashboards are necessary but not sufficient. They tell you *that* something is wrong; they don't tell you *what changed* across resource configuration, code, deployments, and alerts at the same time. SRE Agent's differentiator is correlating those signals **and** remembering what worked last time.

## Why incidents take too long today

Walk through these as a mini-diagnostic of the room. Most teams will recognize at least three of the four.

1. **Signal sprawl.** Telemetry is split across Application Insights, App Service logs, Activity Log, alert rules, and the deployment pipeline. Each lives in its own pane of glass and uses its own query language.
2. **Cross-layer root cause analysis is slow.** A spike of HTTP 500s could be code, configuration, infra, or upstream dependency. Correlating "an app setting changed at 14:02" with "5xx started at 14:03" is currently a human's pattern-matching job.
3. **Context is trapped.** The engineer who last debugged this exact failure mode in March is on PTO. The post-mortem doc is in a wiki nobody opened since.
4. **Action is gated by access.** Even when the fix is obvious, the on-call may not have the role to flip the app setting and is paging someone who does.

SRE Agent attacks each of these directly: it queries every observability surface from one prompt (1), correlates change/telemetry/code in a single investigation (2), persists what it learns across conversations (3), and runs under its own RBAC-scoped identity that *you* control the blast radius of (4).

## What makes SRE Agent different from a smart dashboard

| Dimension | Monitoring dashboard | LLM chatbot bolt-on | **Azure SRE Agent** |
| --- | --- | --- | --- |
| Asks queries on your behalf | No | Sometimes | **Yes** (KQL, ARM, REST, az CLI) |
| Correlates across services | Manual | Hallucination-prone | **Grounded in your resources via RBAC** |
| Remembers past investigations | No | Per-session only | **Persistent agent memory** |
| Can take action | No | No | **Yes, when granted RBAC + an approved response plan** |
| Governed by Azure identity & policy | N/A | N/A | **Managed identity + role assignments + audit log** |
| Extensible | Custom dashboards | Custom prompts | **Custom runbooks, sub-agents, MCP servers** |

The "can take action, but only when permitted" row is the one that matters for production use, and it drives the workshop's emphasis on guardrails in Module 5.

## How the agent works

The same architecture is documented in [`docs/architecture.md`](../docs/architecture.md).

```text
                       +---------------------------+
   You / on-call --->  |  SRE Agent chat surface   |
                       +-------------+-------------+
                                     |
                                     v
                  +------------------------------------+
                  |  Reasoning loop (Anthropic / AOAI) |
                  |  + agent memory (per agent)        |
                  +----+--------------+----------------+
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

- The **agent is an Azure resource**, not a SaaS endpoint. Creating one auto-provisions a Managed Identity, an Application Insights instance, and a Log Analytics workspace for the agent's own telemetry. You'll see those appear during [Module 2](../Workshop/2-Deploy-Agent.md).
- It only sees what **you grant it** via Azure RBAC. The workshop uses RG-scoped Privileged-mode permissions on `rg-sreinprod-app`, which is the *least-privilege* path that still lets the agent execute approved remediations.
- The **memory** belongs to the agent resource. Delete the agent and the memory goes with it, so production deployments should treat the agent as a long-lived first-class resource rather than a sandbox.

## Supported integration surface

This catalog answers the common question, *"Can it talk to X?"* Source: the **Integrations** section of the [official overview](https://learn.microsoft.com/azure/sre-agent/overview).

| Category | Built-in integrations |
| --- | --- |
| **Monitoring & observability** | Azure Monitor (metrics, logs, alerts, workbooks), Application Insights, Log Analytics, Grafana |
| **Incident management** | Azure Monitor Alerts, PagerDuty, ServiceNow |
| **Source control / CI-CD** | GitHub (repositories, issues), Azure DevOps (repos, work items) |
| **Data sources** | Azure Data Explorer (Kusto) clusters, Model Context Protocol (MCP) servers |
| **Azure service management** | Compute (VMs, App Service, ACA, AKS, Functions), Storage, Networking, SQL/Cosmos/PostgreSQL/MySQL/Redis, Azure Monitor / Resource Manager, all managed via Azure CLI and REST APIs |

> Anything not in this table may be reachable through **custom runbooks** (az CLI / REST) or **sub-agents / MCP** for non-Azure systems.

## Where each capability appears

| Capability | Demonstrated in |
| --- | --- |
| Provisioning the agent + RBAC scoping | [Module 2: Deploy the Agent](../Workshop/2-Deploy-Agent.md) |
| Adding connectors for incident automation | [Module 3: Connectors](../Workshop/3-Connectors.md) |
| Connecting telemetry sources & code | [Module 4: Connect Observability](../Workshop/4-Connect-Observability.md) |
| Approval-gated remediation, response plans, guardrails | [Module 5: Response Plans and Guardrails](../Workshop/5-Response-Plans-and-Guardrails.md) |
| End-to-end investigation against a real fault | [Module 6: Incident Drill](../Workshop/6-Incident-Drill.md) |

## Discussion and facilitator material

Use these points to frame the room before going further. The workshop's value-per-minute is highest when participants come to Module 6 having already articulated the gap between *dashboards* and *operating systems*.

- **Why incidents take too long to resolve.** Where does *your* MTTR actually go: detection, triage, root cause analysis, fix, or comms?
- **Why dashboards alone are not enough.** A dashboard tells you *something* is wrong; what tells you *why*?
- **Why cross-layer root cause analysis is slow.** When a 5xx fires, how many panes of glass does your on-call open?
- **Why context and guardrails matter.** What stops you from just letting an LLM `az webapp restart` everything? The answer becomes Module 5.

Open-ended facilitator prompts follow. Pick 2 to 3 based on the room.

- *"What slows your team down during incidents today?"* This usually surfaces tooling sprawl and access bottlenecks.
- *"Which tools do you switch between most often during an investigation?"* This maps directly to the integrations table above.
- *"What knowledge is usually trapped in past incidents?"* This leads into the memory discussion.
- *"What's the smallest action you'd be willing to let an agent take unattended?"* This primes Module 5's guardrail conversation.
- *"If your best on-call engineer left tomorrow, what would you lose?"* This opens a discussion about durable operational knowledge.

## What the agent will not do

These expectations are worth stating before anyone gets into the chat in Module 2. Source: [Considerations](https://learn.microsoft.com/azure/sre-agent/overview#considerations) on the overview page, plus workshop experience.

- It's **English-only** in chat today.
- It will **not** take destructive actions outside the RBAC surface you granted it. If you used Reader-mode permissions in Module 2, the agent will *propose* fixes but not *apply* them.
- It will **not** automatically connect to systems you didn't explicitly wire up. There's no implicit network discovery.
- It is **regional**. Today it's available in *East US 2*, *Sweden Central*, and *Australia East* (the workshop uses East US 2). Availability also varies by tenant configuration.
- It is **not a replacement for your monitoring stack**. It sits on top of it and makes it useful.

## Further reading

- [Azure SRE Agent: Overview](https://learn.microsoft.com/azure/sre-agent/overview): the official feature catalog.
- [Memory and knowledge](https://learn.microsoft.com/azure/sre-agent/memory): how the agent persists what it learns.
- [Sub-agents](https://learn.microsoft.com/azure/sre-agent/sub-agents): extending the agent to specialized domains.
- [`docs/architecture.md`](../docs/architecture.md): how this specific workshop's demo environment is wired.
- [`docs/sample-app.md`](../docs/sample-app.md): the .NET sample app and the deterministic `INJECT_ERROR` fault used in Module 6.

[← Return to the Foundation workshop exercise](../Workshop/1-Foundation.md) | [Learning home](./README.md)
