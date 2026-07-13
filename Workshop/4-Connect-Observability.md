# Module 4 - Connect Observability

[← Module 3: Connectors](./3-Connectors.md) | [Workshop home](./ReadMe.md) | [Next: Module 5 →](./5-Response-Plans-and-Guardrails.md)

## Objective

Take the connector you added in Module 3 and turn it into an **incident-investigation workflow**. In this module the participants:

1. Add a **second** telemetry connector, **Application Insights**, so the agent has two named telemetry surfaces (`log-analytics-demo` for App Service logs and `app-insights-demo` for APM signals).
2. Run a single chat prompt that forces the agent to cite **which connector each fact came from**, then reach a healthy / unhealthy verdict.
3. Inspect the resulting **trace** to see exactly which tools the model invoked and how long each step took.
4. Tour the agent's **Monitor** surfaces (`Session Insights`, `Resource Mapping`, `Logs`) and the **Operations Hub** so participants know where to look when an incident is in flight.

> Time: ~30 min (5 min framing, 20 min hands-on, 5 min discussion).
> Prereq: Module 3 complete with `log-analytics-demo` showing **Connected** in the Telemetry group, and an Application Insights resource `appi-sreinprod-demo-<suffix>` (created by Module 1 / `infra/main.bicep`, surfaced in `scripts/env.conf` as `APP_INSIGHTS_NAME`).

## What this module adds (and what it does not)

| Aspect | What it is | What it is not |
| --- | --- | --- |
| **Second telemetry connector** | A scoped APM lens: `app-insights-demo` lets the agent query request volume, failure rate, exceptions, and dependencies for a specific Application Insights resource. The KQL surface is `requests`, `exceptions`, `dependencies`, `traces`, `customEvents`. | A duplicate of `log-analytics-demo`. Even when both are workspace-based, the App Service logs (`AppServiceHTTPLogs`, etc.) live in the Log Analytics surface, while APM tables (`requests`, `exceptions`) are reached via the App Insights surface. The agent picks the one whose tables answer the question. |
| **Cited investigation prompt** | A multi-question prompt that names both connectors so the model has to (a) route each sub-question to the right tool, (b) cite the connector per fact, and (c) reconcile signals into a verdict. | A "summarise everything" prompt. The point of the workshop prompt is to make tool selection visible. A vague prompt would let the agent fall back to its built-in `monitor-client` connector and the trace would not be educational. |
| **View trace** | A per-thread span tree showing model name, reasoning steps, and every tool call with its duration. Lives behind the `View trace` button in the chat thread footer. | Telemetry you ship to your own Application Insights. The agent's trace is consumed inside the SRE Agent portal only. |
| **Monitor sub-nav** | Three pages reachable from the agent's left rail under **Monitor**: **Session Insights** (per-thread analyses you generate on demand), **Resource Mapping** (a topology view of what the agent has touched), and **Logs** (an external-link hand-off to the Azure portal Log Analytics blade backing the agent itself). | The agent's *own* observability is separate from the workload's observability. The workload's logs are the ones you queried in Module 3 via `log-analytics-demo`. |
| **Operations Hub** | The agent's landing page once you have done one or two investigations: **Daily Volume by Source** chart, **Pending Actions** queue, **System Health** card, **Active Connectors** list. | A replacement for Azure Monitor dashboards. It scopes to *this agent's* activity, not your workload's KPIs. |

For Application Insights connector configuration details, see [Connectors in Azure SRE Agent](https://go.microsoft.com/fwlink/?linkid=2341945).

## Lab steps

> All lab steps run against the live agent at `https://sre.azure.com/agents/subscriptions/<subId>/resourceGroups/rg-sreinprod-agent/providers/Microsoft.App/agents/sreagent-sreinprod`.

### At a glance

The lab is 7 steps. Each step below adds the context and the *why*.

1. **Step 1:** **`Builder`** -> **`Connectors`** -> **`+ Add connector`** -> tick **`Application Insights`** -> **`Next`**.
2. **Step 2:** Fill **Name** = `app-insights-demo`, pick the workshop App Insights resource, leave **Managed identity** = `System assigned`, click **`Next`**. (If needed, grant **Reader** to the agent's MI on the App Insights RG first.)
3. **Step 3:** On **Review + add**, click **`Add connector`**.
4. **Step 4:** Open a **`+ New Chat Thread`** and paste the cited investigation prompt verbatim.
5. **Step 5:** Click **`View trace`** in the chat footer to inspect the span tree.
6. **Step 6:** Tour the **Monitor** sub-nav: **Session Insights**, **Resource Mapping**, **Logs**, **Azure Managed Grafana**.
7. **Step 7:** Open **`Operations Hub`** and verify the **`Active Connectors (4)`** card and the **`Daily Volume by Source`** chart.

### Step 1: Add the **Application Insights** connector

> **Action:** In the agent's left rail, expand **`Builder`** and click **`Connectors`**.

The page from Module 3 should already show **Telemetry (1)** with `log-analytics-demo` and **Code Repository (1)** with `app-service-dotnet-agent-tutorial`.

> **Action:** Click **`+ Add connector`**.

The same 3-step wizard from Module 3 opens. On the **`Choose a connector`** step, leave the **`Telemetry`** tab selected and pick the **`Application Insights`** tile. The tile's description reads:

> *"Query application telemetry, trace requests, analyze dependencies, and monitor performance metrics. Read-only."*

![Add connector wizard, Application Insights tile selected](../images/wizard/26-app-insights-selected.png)

> 🐞 **Same gotcha as Module 3.** Clicking the body of the tile sometimes only highlights it. If `Next` stays disabled, click the small checkbox at the top-left corner of the tile.

> **Action:** Tick the **`Application Insights`** tile and click **`Next`**.

### Step 2: **Set up Application Insights connector**

The header changes to **"Set up Application Insights connector"**. Three required fields:

![Application Insights resource dropdown open](../images/wizard/27-app-insights-set-up.png)

| Field | Workshop value | Notes |
| --- | --- | --- |
| **Name\*** | `app-insights-demo` | The chat-friendly name. Lowercase, hyphenated. The agent will refer to this connector by this exact string in trace data. |
| **Application Insights resource\*** | `appi-sreinprod-demo-<suffix>` (resource group `rg-sreinprod-demo`) | Combobox listing every App Insights resource the agent's identity can already see. Pick the workshop one. |
| **Managed identity\*** | **`System assigned`** *(default)* | Same identity the agent was deployed with in Module 2. Leave the default. |

> ℹ️ **The required role differs from Module 3.** Once you pick the resource, an info banner reads:
>
> > *"Reader role needed on: rg-sreinprod-demo"*
>
> ![App Insights set up form filled, banner showing Reader role required](../images/wizard/28-app-insights-filled.png)
>
> The Application Insights connector requires plain **`Reader`** on the resource group, not the **`Log Analytics Reader`** role that Module 3's connector required. If your security policy uses RBAC-as-code, this means **two** role assignments per workshop telemetry RG. As with Module 3, the wizard is informational only and does not create the role assignment for you. If the agent's identity does not already have `Reader` on `rg-sreinprod-demo`:
>
> ```powershell
> $miId = az resource show `
>   --resource-group rg-sreinprod-agent `
>   --name sreagent-sreinprod `
>   --resource-type "Microsoft.App/SREAgents" `
>   --query "identity.principalId" -o tsv
> az role assignment create `
>   --assignee-object-id $miId `
>   --assignee-principal-type ServicePrincipal `
>   --role "Reader" `
>   --scope "/subscriptions/<subId>/resourceGroups/rg-sreinprod-demo"
> ```

> **Action:** Fill the three fields above, then click **`Next`**.

### Step 3: **Review + add**

The **Review + add** pane echoes back the four values you set. Verify the **Application Insights resource** matches `APP_INSIGHTS_NAME` from `scripts/env.conf`.

![Review + add pane for the App Insights connector](../images/wizard/29-app-insights-review.png)

> **Action:** Click **`Add connector`**.

The dialog closes and the **Connectors** page now lists two telemetry connectors:

![Connectors page showing both telemetry connectors](../images/wizard/30-connectors-with-app-insights.png)

| Group | Row | Service | Status | Source |
| --- | --- | --- | --- | --- |
| **Telemetry (2)** | `app-insights-demo` | Application Insights | ✅ Connected | Agent |
| **Telemetry (2)** | `log-analytics-demo` | Log Analytics | ✅ Connected | Agent |
| **Code Repository (1)** | `app-service-dotnet-agent-tutorial` | GitHub | ✅ Connected | Agent |

> ⚠️ If `app-insights-demo` lands in **Failed** rather than **Connected**, hover the status: missing **`Reader`** on `rg-sreinprod-demo` is the dominant cause. Grant it via the snippet in Step 2 and click **`↻ Refresh`** on the toolbar.

### Step 4: Run the cited investigation prompt

> **Action:** Open a **`+ New Chat Thread`** and paste the prompt **verbatim**:

```text
Investigate app-sreinprod-demo-<suffix> for the last 1 hour. Use the
app-insights-demo connector for request volume, failure rate, and the
top 3 exception types. Use the log-analytics-demo connector for the
AppServiceHTTPLogs status-code distribution and the most recent
AppServiceConsoleLogs entry. Also list the App Service alert rules
currently configured. Then summarise: is this app healthy right now?
Cite which connector each fact came from.
```

Replace `<suffix>` with the value from `scripts/env.conf` (`WEBAPP_NAME` minus the `app-sreinprod-demo-` prefix).

A correct answer auto-titles the thread something like **"App Service Health Diagnostics"** and replies with a table that **names the connector for every row**, plus an explicit verdict at the bottom:

![Investigation chat answer with per-fact connector citations](../images/wizard/31-investigation-chat.png)

A passable answer for a healthy demo workload looks like this (your numbers will vary):

| Signal | Value | Source |
| --- | --- | --- |
| Alert rules | `alert-sreinprod-demo-http5xx` (Sev 2, enabled, condition `Http5xx > 5`) | Azure Monitor |
| Failure rate | 0% | `app-insights-demo` |
| HTTP status distribution | 23 × 200 | `log-analytics-demo` |
| Latest console log entry | No entries | `log-analytics-demo` |
| Request volume | 142 requests | `app-insights-demo` |
| Top 3 exception types | None | `app-insights-demo` |

Followed by a **Verdict: healthy** paragraph that lists the data points it used.

**Why this prompt:** every sub-question maps to a different surface. **Request volume / failure rate / exceptions** force `app-insights-demo` (the AppServiceHTTPLogs table cannot answer those at the same fidelity). **HTTP status distribution / console logs** force `log-analytics-demo`. **Alert rules** force the agent to fall through to its built-in `monitor-client` connector. If the answer skips a citation or refuses a sub-question, the connector wiring is wrong (most often: missing `Reader` on `rg-sreinprod-demo`).

> 💡 **Cross-check.** The `Alert rules` row should match Module 1's `infra/main.bicep` exactly: rule name `alert-sreinprod-demo-http5xx`, severity 2, enabled, condition `Http5xx > 5`. If the rule is missing, Module 1 was not deployed correctly and Module 6's smoke test will fail.

### Step 5: Inspect the trace via **`View trace`**

> **Action:** In the chat thread's footer, click **`View trace`**.

A modal opens with the thread ID, the agent name, your user identity, and a span tree:

![View trace dialog header, span tree collapsed](../images/wizard/32-investigation-trace.png)

> **Action:** Expand the **`meta_agent`** span.

The tree shows:

![View trace dialog, meta_agent span expanded](../images/wizard/33-trace-expanded.png)

| Span | What it tells you |
| --- | --- |
| **Model generation** (`claude-opus-4-6`) | Which model handled the turn and how long each generation took. Multiple generations per turn means the model called tools, got results, and asked the model to summarise again. |
| **Reasoning** (e.g. *"Investigating app performance metrics"*) | The agent's plan-of-attack between tool calls. Useful when an answer surprises you: the reasoning shows whether the model decided to skip a sub-question. |
| **Tool calls** | The actual function names: `monitor-client_monitor_resource_log_query`, `monitor-client_monitor_workspace_log_query`, `RunAzCliReadCommands`, `ManageTodoList`. Each row shows duration. |
| **Agent response** | The model output that became part of the chat reply. |

> 🔍 **Interesting nuance:** even though you added named connectors `log-analytics-demo` and `app-insights-demo`, the trace shows tool names prefixed with **`monitor-client_*`**. The `monitor-client` connector is a built-in default that ships with every agent. Your **named connectors scope what the model is allowed to query**; the **`monitor-client`** connector is the underlying execution path. This is why **deleting `log-analytics-demo`** does not break Module 6's smoke test, but **deleting the agent's RBAC** does.

Close the trace dialog.

### Step 6: Tour the **Monitor** sub-nav

> **Action:** Collapse **Builder** in the left rail and expand **Monitor**.

Three pages plus an external link:

#### Session Insights

![Session Insights page, empty state](../images/wizard/34-session-insights.png)

Page header: **"Session Insights"**. Subtitle: *"Review insights generated from agent session activity."*

Empty state copy: *"No session insights found. Generate insights for a thread by clicking the chart icon (📊) in the chat footer."*

Use this when you want a structured analysis of what a chat thread accomplished (root cause, action taken, time-to-resolve). Insights are generated **per-thread, on demand** from the chat footer; they are not produced automatically. For the workshop, leave it empty - facilitators can demo the chart icon if there is time.

#### Resource Mapping

![Resource Mapping canvas view with Web App and App Service Plan](../images/wizard/35-resource-mapping.png)

Three filter chips at the top: **`Subscription equals <name>`**, **`Primary resource type equals All`**, **`Primary resource name equals <app-name>`**. Toggle: **`Canvas view`** / **`Table view`**.

For the workshop, the canvas should show two boxes connected by a **`Hosted on`** arrow:

- `app-sreinprod-demo-<suffix>` (Web App, `microsoft.web/sites`, `rg-sreinprod-demo`)
- `plan-sreinprod-demo-<suffix>` (App Service Plan)

The right-hand details panel exposes two **per-resource** writeable fields the agent will use later:

| Field | What it does |
| --- | --- |
| **Repository connection** | A **`Connect repository`** link that ties this Azure resource to a specific GitHub or Azure DevOps repo. Module 5 uses this to scope code-aware suggestions. |
| **Annotation** | A free-text **`Add annotation`** link. Use it to capture institutional knowledge ("staging slot is read-only on Mondays") that the agent should consider in chat. |

#### Logs (external link)

`Logs` has an external-link icon next to its label and opens a **new browser tab** redirecting to the Azure portal's Log Analytics blade backing the agent itself. This is the agent's *own* operational telemetry (its workspace, separate from the workload's `log-sreinprod-demo-<suffix>`). For the workshop, **skip the redirect** - close the new tab.

#### Azure Managed Grafana

Below `Logs` sits **`Azure Managed Grafana`**. Empty for the workshop. Use it if your team already runs Grafana dashboards for the agent host cluster.

### Step 7: Land on the **Operations Hub**

> **Action:** Click the **`Operations Hub`** entry near the top of the left rail.

This is the agent's landing page once you have done a couple of investigations:

![Operations Hub overview tab](../images/wizard/36-operations-hub.png)

Page header: **"Operations Hub"**. Subtitle: *"View key metrics, insights, and incident analytics for your agent at a glance."* Three tabs at the top: **`Overview`** *(default)*, **`Incident Analytics`**, **`Automation`**.

Setup-status row reads **"Incidents are not configured"** and shows green checks for `Incidents`, `Code`, `Logs`, `Azure resources`, `Knowledge files`, with a **`Complete setup`** link. The check on `Incidents` here means *the agent is allowed to surface incidents*; the leading text saying they are *not* configured means *no incident system (PagerDuty, ServiceNow) is wired in yet*. Module 5 covers that wiring.

Useful cards on this tab:

| Card | What to look for |
| --- | --- |
| **Daily Volume by Source** *(chart)* | Three legend entries: **Conversations**, **Incidents**, **Scheduled Tasks**. Default time range: **Last 7 days**. The chat thread you ran in Step 4 should appear as a blue (Conversations) bar on today's date. |
| **Pending Actions** | Empty for the workshop *("No pending actions / Your queue is currently clear.")*. Module 5 will create entries here when a response plan asks for human approval. |
| **System Health** | **`Agent Process: Healthy`** and **`Connectors Overview: 4 Healthy`**. The 4 includes the named connectors plus the built-in `monitor-client`. |
| **Active Connectors (4)** | A row per connector with its status. For the workshop you should see exactly: `log-analytics-demo` (Log Analytics, Connected), `monitor-client` (Log Analytics & App Insights, Connected, **built-in**), `app-insights-demo` (Application Insights, Connected), `app-service-dotnet-agent-tutorial` (GitHub, Connected). |

> 🔬 **The `monitor-client` reveal.** This is the first place in the portal that surfaces the built-in connector by name. The trace from Step 5 named tools that began with `monitor-client_*`; this card explains why. Treat **`monitor-client`** as the agent's default execution path for Azure Monitor questions - your named connectors are scoping aliases on top of it.

## Discussion prompts

- The trace surfaces tool calls prefixed `monitor-client_*` even though the prompt named `log-analytics-demo` and `app-insights-demo`. **Why have named connectors at all if `monitor-client` is the actual execution path?** *(Hints: scoping, naming in chat for clarity, RBAC fan-out per resource group, easier to revoke a single source.)*
- The Application Insights connector requires `Reader` while the Log Analytics connector requires `Log Analytics Reader`. **Should your IaC repo grant both at agent provisioning time, or just-in-time per connector?** *(Discuss the trade-off: provisioning convenience vs. least privilege.)*
- The chat answer was a clean *Healthy* verdict because the demo app is idle. **What would you change about the prompt to make the agent flag intermittent issues, not just steady-state failures?** *(Hints: percentile latencies, error budget burn rate, slot deltas, recent deploy markers.)*
- **Operations Hub** shows "Incidents are not configured". **When would you wire that in (Module 5) vs leave it empty?** *(Hints: blast radius, on-call rotation maturity, audit trail expectations.)*
- **View trace** exposes model name and per-step duration. **What is your team's policy for storing or exporting these traces?** *(Hints: cost per investigation, regulatory retention, post-incident review pipeline.)*

## Validation checklist

- [ ] **Connectors** page shows **Telemetry (2)** with both `log-analytics-demo` and `app-insights-demo` reading **Connected**.
- [ ] The agent's managed identity holds `Reader` on `rg-sreinprod-demo` and `Log Analytics Reader` on the RG containing `log-sreinprod-demo-<suffix>`.
- [ ] In a fresh chat thread, the cited investigation prompt returns a **table** with **per-fact connector attribution** and an explicit verdict.
- [ ] **`View trace`** opens a span tree with model name (`claude-opus-4-6` at the time of writing), reasoning steps, and tool calls prefixed `monitor-client_*`.
- [ ] **Operations Hub** lists exactly **4 Active Connectors**: `log-analytics-demo`, `monitor-client` (built-in), `app-insights-demo`, `app-service-dotnet-agent-tutorial`. Agent Process is **`Healthy`**.
- [ ] **Resource Mapping** shows the Web App / App Service Plan pair from Module 1. The right-hand details panel exposes **`Connect repository`** and **`Add annotation`** links.

## Reference: full screenshot index

Captured against the live portal in June 2026. Files live under `images/wizard/` so facilitators can reuse them in slides.

| # | Screen | File |
| --- | --- | --- |
| 26 | Add connector wizard, Application Insights tile selected ⭐ embedded | [26-app-insights-selected.png](../images/wizard/26-app-insights-selected.png) |
| 27 | Set up App Insights connector, resource dropdown open ⭐ embedded | [27-app-insights-set-up.png](../images/wizard/27-app-insights-set-up.png) |
| 28 | Set up form filled, Reader role banner ⭐ embedded | [28-app-insights-filled.png](../images/wizard/28-app-insights-filled.png) |
| 29 | Review + add for App Insights connector ⭐ embedded | [29-app-insights-review.png](../images/wizard/29-app-insights-review.png) |
| 30 | Connectors page with both telemetry connectors ⭐ embedded | [30-connectors-with-app-insights.png](../images/wizard/30-connectors-with-app-insights.png) |
| 31 | Cited investigation chat answer ⭐ embedded | [31-investigation-chat.png](../images/wizard/31-investigation-chat.png) |
| 32 | View trace dialog header ⭐ embedded | [32-investigation-trace.png](../images/wizard/32-investigation-trace.png) |
| 33 | Trace expanded: model generation, reasoning, tool calls ⭐ embedded | [33-trace-expanded.png](../images/wizard/33-trace-expanded.png) |
| 34 | Session Insights, empty state ⭐ embedded | [34-session-insights.png](../images/wizard/34-session-insights.png) |
| 35 | Resource Mapping canvas with Web App + Plan ⭐ embedded | [35-resource-mapping.png](../images/wizard/35-resource-mapping.png) |
| 36 | Operations Hub overview tab ⭐ embedded | [36-operations-hub.png](../images/wizard/36-operations-hub.png) |

## Further reading

- [Connectors in Azure SRE Agent](https://go.microsoft.com/fwlink/?linkid=2341945): the official catalog and configuration reference, including Application Insights specifics.
- [Module 3: Connectors](./3-Connectors.md) wired up `log-analytics-demo`, which this module pairs with `app-insights-demo`.
- [Module 5: Response Plans and Guardrails](./5-Response-Plans-and-Guardrails.md) governs what the agent can do **with** the data it now sees, including writing back to incident systems.
- [Module 6: Production Rollout](./6-Production-Rollout.md) replays a real Http5xx burst to prove the connectors and the alert rule work end-to-end.

## Notes for repo owners

Re-capture screenshots `26` to `36` if the portal redesigns the **Add connector** wizard for App Insights, the **`View trace`** dialog, the **Monitor** sub-nav, or the **Operations Hub**. The most volatile elements are the trace span tree (model identifiers change as the agent's underlying model is updated) and the **Active Connectors** list on Operations Hub (the built-in `monitor-client` may be renamed or its surface expanded as new resource types ship).
