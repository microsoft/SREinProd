# Module 1 - Foundation

[← Workshop home](./ReadMe.md) | [Next: Module 2 →](./2-Deploy-Agent.md)

[Learning companion: Foundation concepts and reference](../Learning/1-Foundation.md)

## Objective

Explain, in your own words, what Azure SRE Agent is, what problem it solves, and where it sits in your existing tooling before anyone touches a portal.

> Time: ~30 min (10 min framing, 15 min discussion, 5 min recap).
> No hands-on yet; everything in this module is whiteboard, slides, and discussion. The first deploy happens in [Module 2](./2-Deploy-Agent.md).

## Essential mental model

Azure SRE Agent is a managed AI agent service that connects to your **observability stack** (Azure Monitor, Application Insights, Log Analytics, Grafana), your **incident platforms** (Azure Monitor Alerts, PagerDuty, ServiceNow), and your **source control** (GitHub, Azure DevOps), and uses that context to **triage, investigate, and (when allowed) remediate** incidents on Azure resources. It is provisioned as a first-class Azure resource (`Microsoft.App/SREAgents`), runs under a managed identity, and is governed by Azure RBAC just like any other resource. It is **not** a chatbot bolted onto Azure Monitor; the chat is the surface, the value is the closed loop behind it.

| # | Layer | Question it answers | Where it usually lives today | Where it lives in this workshop |
| --- | --- | --- | --- | --- |
| 1 | **Monitoring** | *Is something wrong?* | Dashboards, metric alerts | Http5xx alert in [`infra/main.bicep`](../infra/main.bicep) |
| 2 | **Investigation** | *What is wrong, and why?* | Tribal knowledge + 6 browser tabs | SRE Agent chat ([Module 6](./6-Incident-Drill.md)) |
| 3 | **Remediation** | *How do we make it stop?* | Runbooks, on-call ad-hoc CLI | Agent guardrails + RBAC ([Module 5](./5-Response-Plans-and-Guardrails.md)) |
| 4 | **Institutional learning** | *How do we not see this again?* | Post-mortem docs nobody re-reads | Agent memory |

> **The workshop's central claim:** dashboards are necessary but not sufficient. They tell you *that* something is wrong; they don't tell you *what changed* across resource configuration, code, deployments, and alerts at the same time. SRE Agent's differentiator is correlating those signals **and** remembering what worked last time.

For the architecture, integration catalog, limitations, and detailed comparisons, use the [Foundation learning companion](../Learning/1-Foundation.md).

## Guided foundation exercise

1. **Map your current incident path.** On a whiteboard, write the four layers above. For a recent incident, name the tool or person your team relied on at each layer.
2. **Locate the delay.** Decide where most of your MTTR went: detection, triage, root cause analysis, remediation, or communication.
3. **Count the context switches.** List the dashboards, logs, deployment systems, source repositories, and people an on-call engineer had to consult.
4. **Set a guardrail boundary.** Name the smallest production action you would allow an agent to take, and the approval or RBAC boundary you would require.

Use these prompts if the room needs a starting point:

- What tells you *why* an alert fired, rather than only *that* it fired?
- What incident knowledge would disappear if your most experienced on-call engineer left?
- Which investigation step could become faster without increasing the remediation blast radius?

## Expected outcome

By the end of Module 1 every participant should be able to explain, **without looking at slides**, the difference between:

- **monitoring** (the dashboard tells me something is off),
- **investigation** (something correlates the signals and tells me why),
- **remediation** (something safely takes the action that fixes it), and
- **institutional learning** (what we learned from this incident is available the next time it happens, even to someone who wasn't on call).

If the room can articulate that distinction in their own words, you're ready for [Module 2](./2-Deploy-Agent.md).

## Learning summary

Azure SRE Agent sits above the monitoring stack and uses explicitly connected context plus Azure RBAC to support investigation, controlled remediation, and reusable incident knowledge. The next module turns that model into a deployed agent with a deliberately scoped identity.

[Read the deeper Foundation concepts and reference →](../Learning/1-Foundation.md)

[← Workshop home](./ReadMe.md) | [Next: Module 2 →](./2-Deploy-Agent.md)
