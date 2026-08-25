# Module 4 Learning - Connect Observability

[← Back to the Connect Observability workshop exercise](../Workshop/4-Connect-Observability.md) | [Learning home](./README.md)

## Purpose

This companion provides the conceptual model, portal-surface reference, discussion prompts, screenshot index, and repository maintenance notes for the executable [Connect Observability workshop exercise](../Workshop/4-Connect-Observability.md).

## What this module adds (and what it does not)

| Aspect | What it is | What it is not |
| --- | --- | --- |
| **Second telemetry connector** | A scoped APM lens: `app-insights-demo` lets the agent query request volume, failure rate, exceptions, and dependencies for a specific Application Insights resource. Its KQL surface includes `requests`, `exceptions`, `dependencies`, `traces`, and `customEvents`. | A duplicate of `log-analytics-demo`. App Service logs such as `AppServiceHTTPLogs` live in the Log Analytics surface, while APM tables such as `requests` and `exceptions` are reached through Application Insights. |
| **Cited investigation prompt** | A multi-question prompt that names both connectors so the model routes each sub-question, cites its source, and reconciles the signals into a verdict. | A generic "summarize everything" prompt. A vague prompt can fall back to the built-in `monitor-client` path without making tool selection educational. |
| **View trace** | A per-thread span tree showing the model, reasoning steps, tool calls, and duration of each step. It opens from **`View trace`** in the chat footer. | Telemetry exported to your workload's Application Insights. The trace is consumed inside the SRE Agent portal. |
| **Monitor navigation** | **Session Insights**, **Resource Mapping**, **Logs**, and **Azure Managed Grafana** expose the agent's analysis, topology, self-telemetry handoff, and connected Grafana resources. | The workload's observability. Workload logs are queried through `log-analytics-demo`; agent self-observability is separate. |
| **Operations Hub** | An activity-oriented landing page with **Daily Volume by Source**, **Pending Actions**, **System Health**, and **Active Connectors**. | A replacement for Azure Monitor dashboards. It is scoped to this agent's activity, not the workload's KPIs. |

For Application Insights connector configuration details, see [Connectors in Azure SRE Agent](https://go.microsoft.com/fwlink/?linkid=2341945).

## Why two telemetry connectors

Even when Application Insights is workspace-based, the connectors represent different investigation surfaces. Application Insights answers APM questions such as request volume, failure rate, exception types, dependency behavior, and traces. Log Analytics answers platform-log questions such as App Service HTTP status distribution and console-log entries.

Naming both connectors in the prompt makes routing visible and lets each returned fact identify its evidence source. The alert-rule question intentionally uses a third path, Azure Monitor, so the final verdict must reconcile application, platform, and resource-configuration evidence.

## Permissions and least privilege

The Application Insights connector requires **Reader** on its resource group. The Log Analytics connector requires **Log Analytics Reader** on the workspace's resource group. The connector wizard reports these requirements but does not grant the assignments.

A workshop telemetry resource group can therefore need both roles. A production team should decide whether infrastructure as code grants them during agent provisioning or whether each connector receives just-in-time access. Pre-provisioning is convenient; just-in-time assignment makes least-privilege review and revocation more explicit.

## Reading the investigation trace

The expanded `meta_agent` span can contain:

| Span | What it tells you |
| --- | --- |
| **Model generation** | Which model handled the turn and how long each generation took. Multiple generations indicate tool calls followed by additional synthesis. |
| **Reasoning** | The plan between tool calls, useful for understanding why a sub-question was skipped or routed unexpectedly. |
| **Tool calls** | Function names such as `monitor-client_monitor_resource_log_query`, `monitor-client_monitor_workspace_log_query`, `RunAzCliReadCommands`, and `ManageTodoList`, with duration for each call. |
| **Agent response** | The model output incorporated into the chat reply. |

Named connectors and the built-in `monitor-client` serve related but different purposes. Named connectors provide explicit scope, source names, clearer prompts, and discrete revocation. `monitor-client` is the built-in execution path behind Azure Monitor operations, which is why trace tool names can use the `monitor-client_*` prefix. Removing a named connector does not necessarily remove an Azure-RBAC path, while removing the agent's RBAC does.

Model identifiers are implementation details and can change. The workshop records `claude-opus-4-6` as the observed model at the time of writing, but validation should focus on the presence of model generations, reasoning, and tool spans rather than treating that identifier as permanent.

## Monitor surfaces

### Session Insights

Session Insights provides a structured analysis of a chat thread, including root cause, action taken, and time to resolve. Insights are generated per thread and on demand from the chat footer; they are not produced automatically. The workshop leaves this page empty unless a facilitator chooses to demonstrate generation.

### Resource Mapping

Resource Mapping presents what the agent has touched as a canvas or table. Its filters include **`Subscription equals <name>`**, **`Primary resource type equals All`**, and **`Primary resource name equals <app-name>`**.

For the workshop, the canvas shows:

- `app-sreinprod-demo-<suffix>`: Web App, `microsoft.web/sites`, in `rg-sreinprod-demo`.
- `plan-sreinprod-demo-<suffix>`: App Service Plan.
- A **`Hosted on`** relationship from the web app to the plan.

The resource details panel includes two writable context fields:

| Field | Purpose |
| --- | --- |
| **Repository connection** | **`Connect repository`** associates an Azure resource with a GitHub or Azure DevOps repository. Module 5 uses this for code-aware suggestions. |
| **Annotation** | **`Add annotation`** records institutional knowledge that the agent should consider in chat. |

### Logs

**Logs** opens the Azure portal Log Analytics blade for the agent's own operational telemetry in a new tab. This workspace is separate from the workload workspace `log-sreinprod-demo-<suffix>` used by the named Log Analytics connector.

### Azure Managed Grafana

This entry is empty in the workshop. It is useful when a team already operates Grafana dashboards for the agent host cluster. If the navigation option is absent, the environment has no connected Azure Managed Grafana instance.

## Operations Hub reference

The Operations Hub summarizes this agent's activity:

| Card | What it shows |
| --- | --- |
| **Daily Volume by Source** | Conversations, Incidents, and Scheduled Tasks. The default range is **Last 7 days**. The workshop investigation should appear in today's Conversations bar. |
| **Pending Actions** | Human-approval work. It is empty in this module; Module 5 creates entries when a response plan requests approval. |
| **System Health** | Agent process and connector health. The expected workshop state is **`Agent Process: Healthy`** and **`Connectors Overview: 4 Healthy`**. |
| **Active Connectors (4)** | `log-analytics-demo`, built-in `monitor-client`, `app-insights-demo`, and `app-service-dotnet-agent-tutorial`, each with its service and status. |

This is the first portal surface in the workshop that exposes `monitor-client` by name. It explains the tool prefixes seen in the trace, but it does not turn Operations Hub into a workload-health dashboard.

## Discussion prompts

- Trace calls use `monitor-client_*` even though the prompt names `log-analytics-demo` and `app-insights-demo`. **Why retain named connectors?** Consider scoping, prompt clarity, RBAC fan-out, and single-source revocation.
- Application Insights requires `Reader`, while Log Analytics requires `Log Analytics Reader`. **Should infrastructure as code grant both during provisioning or just in time?**
- The idle demo tends to produce a healthy verdict. **How would you change the prompt to detect intermittent issues?** Consider percentile latency, error-budget burn rate, slot deltas, and deploy markers.
- Operations Hub reports that incidents are not configured. **When should Module 5 wire them in, and when should they remain absent?** Consider blast radius, on-call maturity, and audit requirements.
- **View trace** exposes model identity and per-step duration. **What retention or export policy should apply to these traces?** Consider investigation cost, regulation, and post-incident review.

## Full screenshot index

These files were captured against the live portal in June 2026 and live under `images/wizard/` for facilitator reuse.

| # | Screen | File |
| --- | --- | --- |
| 26 | Add connector wizard, Application Insights selected - embedded | [26-app-insights-selected.png](../images/wizard/26-app-insights-selected.png) |
| 27 | Set up App Insights connector, resource dropdown open - embedded | [27-app-insights-set-up.png](../images/wizard/27-app-insights-set-up.png) |
| 28 | Set up form filled, Reader role banner - embedded | [28-app-insights-filled.png](../images/wizard/28-app-insights-filled.png) |
| 29 | Review + add for App Insights connector - embedded | [29-app-insights-review.png](../images/wizard/29-app-insights-review.png) |
| 30 | Connectors page with both telemetry connectors - embedded | [30-connectors-with-app-insights.png](../images/wizard/30-connectors-with-app-insights.png) |
| 31 | Cited investigation chat answer - embedded | [31-investigation-chat.png](../images/wizard/31-investigation-chat.png) |
| 32 | View trace dialog header - embedded | [32-investigation-trace.png](../images/wizard/32-investigation-trace.png) |
| 33 | Trace expanded: model generation, reasoning, tool calls - embedded | [33-trace-expanded.png](../images/wizard/33-trace-expanded.png) |
| 34 | Session Insights, empty state - embedded | [34-session-insights.png](../images/wizard/34-session-insights.png) |
| 35 | Resource Mapping canvas with Web App and Plan - embedded | [35-resource-mapping.png](../images/wizard/35-resource-mapping.png) |
| 36 | Operations Hub overview tab - embedded | [36-operations-hub.png](../images/wizard/36-operations-hub.png) |

## Further reading

- [Connectors in Azure SRE Agent](https://go.microsoft.com/fwlink/?linkid=2341945): official catalog and Application Insights configuration reference.
- [Module 3: Connectors](../Workshop/3-Connectors.md): creates `log-analytics-demo`, paired here with `app-insights-demo`.
- [Module 5: Response Plans and Guardrails](../Workshop/5-Response-Plans-and-Guardrails.md): governs what the agent can do with the data, including writing to incident systems.
- [Module 6: Incident Drill](../Workshop/6-Incident-Drill.md): replays an Http5xx burst to validate connectors and alerting end to end.

## Notes for repository owners

Re-capture screenshots `26` to `36` if the portal redesigns the Application Insights connector wizard, **View trace**, the **Monitor** navigation, or **Operations Hub**. The most volatile elements are the trace span tree, because model identifiers change, and the Active Connectors list, because the built-in `monitor-client` may be renamed or expanded as new resource types ship.

[← Return to the Connect Observability workshop exercise](../Workshop/4-Connect-Observability.md) | [Learning home](./README.md)
