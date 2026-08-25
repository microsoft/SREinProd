# Module 6 Learning - Incident Drill

[← Back to the Incident Drill workshop exercise](../Workshop/6-Incident-Drill.md) | [Learning home](./README.md)

## Purpose

This companion explains the alert paths, evidence interpretation, trace model, operational tradeoffs, discussion prompts, screenshot index, and repository maintenance notes behind the executable [Incident Drill workshop exercise](../Workshop/6-Incident-Drill.md).

## What this module adds (and what it does not)

| Aspect | What it is | What it is not |
| --- | --- | --- |
| **Two alert paths firing in parallel** | The Bicep metric alert `alert-sreinprod-demo-http5xx` is Sev2 and evaluates `Http5xx >= 5` over PT5M. The Application Insights smart detector `Failure Anomalies - appi-sreinprod-demo-<suffix>` is Sev3 and reacts to an exception-rate anomaly. | One inbox path. Only the Sev3 detector matches Module 5's plan filter; the Sev2 alert remains a human paging signal. |
| **Autonomous and interactive paths sharing one cause** | The response plan performs read-only Sev3 diagnosis while a human can investigate the same event in chat and decide whether to approve remediation. Both use App Insights, Activity Log, and connector evidence. | Duplicate evidence collection. Chat can add source-code reads from the GitHub connector that the response plan's allow-list might omit. |
| **View trace** | A debugging surface for model generations, reasoning, responses, tool calls, their order, inputs, outputs, and durations. | A complete approval audit. Approval text lives in chat; a trace does not retroactively annotate an earlier proposal with the approving user and timestamp. |
| **Operations Hub volume** | A daily aggregation of Conversations, Incidents, and Scheduled Tasks across the agent's surfaces. | A real-time signal. It updates on a multi-minute cadence; use Incidents, chat, or Azure Monitor metrics for immediate state. |

## Why the drill produces two alerts

The same injected fault creates two independently evaluated signals:

| Alert | Source | Severity | Trigger | Plan behavior |
| --- | --- | --- | --- | --- |
| `alert-sreinprod-demo-http5xx` | Bicep metric alert | Sev2 | `count(Http5xx) over PT5M >= 5`, evaluated every PT1M | Does not match the Sev3 plan. Humans see it in Azure Monitor. |
| `Failure Anomalies - appi-sreinprod-demo-<suffix>` | Application Insights smart detector | Sev3 | Statistical anomaly in failed-request rate | Matches `quickstart_response_plan`; read-only diagnosis runs and the incident becomes Acknowledged / Completed. |

The filter is a structural guardrail. Alert-catalog ownership therefore controls which incidents the agent handles. Changing the metric alert to Sev3, or broadening the response-plan filter to Sev2, expands the workflow's blast radius and should follow tool-list and remediation testing.

## Fault model

The sample app reads `INJECT_ERROR` and throws after the sixth button press in a cookie session:

```csharp
bool injectError = Environment.GetEnvironmentVariable("INJECT_ERROR") == "1";
// ...
if (injectError && !safeMode && buttonPressed && pressCount > 5)
    throw new Exception("Simulated error after 5 button clicks!");
```

The warmup script first restores production to `INJECT_ERROR=0`, produces baseline 200 responses, changes production to `INJECT_ERROR=1`, waits for the worker restart, and drives three cookie sessions. This creates an Http5xx burst, a recognizable exception, and recent `Microsoft.Web/sites/config/write` Activity Log operations under the operator's identity.

That combination lets an investigator correlate symptom, configuration state, source code, deployment timing, and actor. The generated evidence resembles a bad configuration deployment rather than a synthetic health-check failure.

## Interpreting the evidence chain

The interactive agent commonly fans out to these surfaces:

| Evidence | Typical tool or connector | Interpretation |
| --- | --- | --- |
| HTTP status and exceptions | Azure Monitor resource-log queries through `log-analytics-demo` and `app-insights-demo` | Establishes the spike, exception type, count, and time window. |
| Resource inventory | `RunAzCliReadCommands` with `az resource list` | Bounds the investigation to managed resources. |
| Configuration writes | Azure Monitor Activity Log | Identifies the `Microsoft.Web/sites/config/write` operations and initiating principal. |
| Current app settings | App Service configuration read | Confirms `INJECT_ERROR=1`; read the inline command because the capability card can still say **Setting resource configuration** and carry a Medium risk badge. |
| Source implementation | GitHub Code connector reading `Program.cs` | Links the environment variable to the exact throw site and exception text. |
| Workshop helper | GitHub Code connector reading the injection script | Reveals that the scenario is rehearsed; the script itself is not running in production. |
| Prior operational context | `SearchIncidentKnowledge` | Searches connected knowledge for related incidents even when the response-plan past-incident picker was empty. |

Risk badges classify capabilities, not necessarily individual command strings. A capability containing both `appsettings list` and `appsettings set` can show **Medium risk** even when the actual command is read-only. Operators must inspect the inline command before approving.

The final report should connect:

1. **Timeline:** the app-setting write and the first 500s.
2. **Root cause:** `INJECT_ERROR=1` set by the observed principal.
3. **Code evidence:** `Program.cs:11` reads the setting and the later branch throws.
4. **Exception evidence:** `System.Exception`, the `MoveNext` call site, and the message `Simulated error after 5 button clicks!`.
5. **Current state:** production is faulted; staging may also have `INJECT_ERROR=1`.
6. **Recommended mitigation:** remove or reset the production setting, but ask before writing.

The staging finding matters. Swapping production with an equally broken staging slot is not a rollback. A durable response plan should make slot-health verification an explicit precondition before proposing a swap.

## Read-only completion under Review

An Incident row can read `Acknowledged / Completed` while the plan remains in **Review** autonomy. Read-only investigation, synthesis, and acknowledgement can complete without approval. Review gates the proposed write, not evidence collection.

A Completed row therefore does not prove that no remediation occurred. Verify the plan's autonomy, tool list, and trace before interpreting it. If the plan were saved as Autonomous, it could reach the same Completed state after already reverting the setting.

## Trace model

The captured trace was rooted at `Agent meta_agent 112 sec` and used these span types:

| Span type | Meaning |
| --- | --- |
| **Model generation** | One model round-trip. Multiple spans show the gather-plan-gather loop. The captured build used `claude-opus-4-6`, but model IDs can change. |
| **Reasoning** | A planning step such as investigating errors or retrying a failed App Insights query. |
| **Agent response** | Text shown to the operator. |
| **Tool** | A tool invocation with its literal input, output, and duration. |

The representative chain was:

1. Model generation using `claude-opus-4-6`.
2. Reasoning: investigating HTTP 500 errors.
3. Agent response announcing parallel evidence collection.
4. `ManageTodoList` to track investigation work.
5. Another model generation.
6. `RunAzCliReadCommands` for resource inventory.
7. Two `monitor-client_monitor_resource_log_query` calls.
8. `SearchIncidentKnowledge`.
9. Another model generation.
10. Reasoning that corrected a missing subscription parameter and retried App Insights.
11. A narrative response and additional `ManageTodoList` progress.

Chat presents narration; trace presents the plan-and-tool loop. Tool-node input and output can reproduce failed KQL, Activity Log filters, or Azure CLI reads. Preserve the trace for diagnostic reproducibility, but also preserve the chat when approval identity matters.

## Approval and audit limits

The remediation prompt asks whether to remove `INJECT_ERROR` from production. The available choices demonstrate different behaviors:

| Reply | Result |
| --- | --- |
| `yes`, `approve`, or `go ahead` | The agent uses `UpdateAppSettings` or `RunAzCliWriteCommands`, sets `INJECT_ERROR=0`, waits for propagation, probes recovery, and reports completion. |
| `no, leave the broken state in place` | The agent records the decision and leaves both slots untouched. This is the workshop default when preserving the environment for another cohort. |
| `first, swap slots back` | The agent should reject or warn because staging is also configured with `INJECT_ERROR=1`, then propose fixing production directly. |

The approval message is stored in chat, but the next trace does not retroactively mark the previous proposal as approved. For a real incident review, retain both chat and trace. A browser print or screenshot can capture who approved when the platform does not provide a separate approval ledger.

## Operations Hub interpretation

After ingestion, **Daily Volume by Source** can show:

| Segment | Meaning |
| --- | --- |
| **Conversations** | Chat threads receiving at least one user message that day. |
| **Incidents** | Incidents handled by the agent through its incident platform and response plans. |
| **Scheduled Tasks** | Work started from **`Builder` → `Scheduled Tasks`**. |

The chart is useful for high-level reporting because it does not expose chat content or PII. Detailed drill-down still follows Azure RBAC. It is not the right place to confirm second-by-second recovery.

## Discussion prompts

- Who owns the severity catalog and approves moving an alert into an agent plan filter? Consider severity drift and asymmetric risks of over-action and under-action.
- At what incident volume does a two-minute agent investigation cost more than a human response, and how should the Module 5 cooldown handle alert storms and deduplication?
- What does `SearchIncidentKnowledge` search when no past incidents were selected, and how would curated incident files change retrieval quality and poisoning risk?
- How should the response plan encode the staging-health precondition so it survives regeneration?
- How would the timeline differ under **Autonomous (Default)**, where the mitigation prompt could be replaced by an immediate write?

## Full screenshot index

Captured against the live agent in June 2026. Files live under `images/wizard/` for facilitator reuse.

| # | Screen | File |
| --- | --- | --- |
| 56 | Chat home before incident | [56-agent-home-pre-incident.png](../images/wizard/56-agent-home-pre-incident.png) |
| 57 | Empty Incidents page | [57-incidents-page-empty.png](../images/wizard/57-incidents-page-empty.png) |
| 58 | Healthy Operations Hub baseline | [58-operations-hub-pre-incident.png](../images/wizard/58-operations-hub-pre-incident.png) |
| 59 | Blank new chat thread | [59-new-chat-blank.png](../images/wizard/59-new-chat-blank.png) |
| 60 | Investigation prompt entered | [60-investigation-prompt-typed.png](../images/wizard/60-investigation-prompt-typed.png) |
| 61 | Investigation started | [61-investigation-running.png](../images/wizard/61-investigation-running.png) |
| 62 | Initial parallel tool calls | [62-investigation-tools-running.png](../images/wizard/62-investigation-tools-running.png) |
| 63 | Activity Log, code, and configuration tools | [63-investigation-progress2.png](../images/wizard/63-investigation-progress2.png) |
| 64 | Final evidence report and mitigation prompt | [64-investigation-progress3.png](../images/wizard/64-investigation-progress3.png) |
| 65 | Sev3 incident Acknowledged and Completed | [65-incidents-with-alert.png](../images/wizard/65-incidents-with-alert.png) |
| 66 | Investigation summary at top of thread | [66-investigation-summary-top.png](../images/wizard/66-investigation-summary-top.png) |
| 67 | Expanded trace explorer | [67-trace-view.png](../images/wizard/67-trace-view.png) |
| 68 | Operations Hub after incident | [68-ops-hub-post-incident.png](../images/wizard/68-ops-hub-post-incident.png) |

## Further reading

- [Incident response plans in Azure SRE Agent](https://go.microsoft.com/fwlink/?linkid=2341945): response-plan concepts and incident platforms.
- [Smart detection in Application Insights](https://learn.microsoft.com/azure/azure-monitor/alerts/proactive-failure-diagnostics): source of the Sev3 Failure Anomalies alert.
- [Module 4 workshop](../Workshop/4-Connect-Observability.md): configures the telemetry connectors used by the evidence fan-out.
- [Module 5 workshop](../Workshop/5-Response-Plans-and-Guardrails.md): creates the `quickstart_response_plan` exercised here.

## Notes for repository owners

Re-capture screenshots `56` through `68` if Operations Hub changes, Incidents columns change, chat tool cards or risk badges change, the trace span taxonomy changes, the default model changes, the sample app moves the `INJECT_ERROR` logic or changes its exception, or `demo-warmup.ps1` changes fault mechanisms.

The most volatile captures are **64**, because model-generated report wording varies; **67**, because traces vary by plan and model; and **68**, because all same-day activity contributes to the chart.

[← Return to the Incident Drill workshop exercise](../Workshop/6-Incident-Drill.md) | [Learning home](./README.md)
