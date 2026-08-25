# Module 6 - Incident Drill

[← Module 5: Response Plans and Guardrails](./5-Response-Plans-and-Guardrails.md) | [Workshop home](./ReadMe.md)

[Learning companion: alert paths, evidence interpretation, discussion, and reference](../Learning/6-Incident-Drill.md)

## Objective

Inject a production-slot configuration fault, observe the Sev2 and Sev3 alert paths, investigate through chat and trace, and keep remediation behind explicit human approval.

> Time: ~45 min. Prerequisites: Modules 3 to 5 are complete; `quickstart_response_plan` is `Created / On / Review` with a `Sev3` filter; the demo app is healthy; and `scripts/env.conf` is populated.

## Scenario

The drill sets `INJECT_ERROR=1` on the production slot and drives failing cookie sessions. The sample app then throws `Simulated error after 5 button clicks!`, producing an Http5xx spike, App Insights exceptions, and `Microsoft.Web/sites/config/write` Activity Log entries.

## Lab steps

> All lab steps assume the agent at `https://sre.azure.com/agents/subscriptions/<subId>/resourceGroups/rg-sreinprod-agent/providers/Microsoft.App/agents/sreagent-sreinprod` and the demo app under `rg-sreinprod-demo`. **Always confirm `scripts/env.conf` is populated before running any of the helper scripts** (otherwise they error out with *"APP_NAME is required"*).

### At a glance

1. Baseline **Operations Hub**, **Incidents**, and chat.
2. Run `demo-warmup.ps1` and confirm `Http5xx` in Azure Monitor.
3. Wait 5 minutes for ingestion and alert evaluation.
4. Confirm the Sev3 incident is `Acknowledged / Completed` with `quickstart_response_plan`.
5. Submit the exact investigation prompt in a new chat thread.
6. Observe evidence collection and inspect inline commands.
7. Verify the final findings and mitigation question.
8. Open the trace and inspect one tool input and output.
9. Choose one remediation reply.
10. If remediated, run the smoke test.
11. Confirm **Conversations** and **Incidents** in Operations Hub.
12. If needed, reset for the next run.

### Step 1: Baseline the operator surfaces

> **Action:** Open each surface and record the healthy state:

- **Operations Hub:** `Agent Process = Healthy`, `Connectors Overview = 4 Healthy`, and today's **Daily Volume by Source** is flat or understood.
- **Incidents:** `New = 0`, `Acknowledged = 0`, all agent-status counters are `0`, and the table says `No incidents found`.
- **New Chat Thread:** the `All sources configured` banner shows `Code`, `Logs`, `Incidents`, `Azure resources`, and `Knowledge files`.

![Operations Hub before the incident, all green, flat volume](../images/wizard/58-operations-hub-pre-incident.png)

![Incidents page empty, all counters at 0](../images/wizard/57-incidents-page-empty.png)

![Agent chat home, sources configured pill, empty thread](../images/wizard/56-agent-home-pre-incident.png)

### Step 2: Inject the fault

> **Action:** From the workshop root, run:
>
> ```powershell
> pwsh ./scripts/demo-warmup.ps1
> ```

The script resets production, generates baseline 200 responses, sets `INJECT_ERROR=1`, and drives three failing sessions; its configuration writes are attributed to the operator running it.

Expected console output:

```text
Step 1/4: Resetting production slot to baseline (INJECT_ERROR=0)...
Step 2/4: Generating 25 baseline requests against https://app-sreinprod-demo-<suffix>.azurewebsites.net ...
Step 3/4: Injecting fault (INJECT_ERROR=1)...
Step 4/4: Driving 30 failing requests across 3 sessions ...
  session 1 complete
  session 2 complete
  session 3 complete

Warmup complete. Give Application Insights and the Http5xx metric alert about 3-5 minutes to surface telemetry, then ask the SRE Agent to investigate.
```

> **Action:** Confirm 5xx are actually flowing on the production slot by asking Azure Monitor directly:
>
> ```powershell
> az monitor metrics list `
>   --resource (az webapp show -g $env:APP_RESOURCE_GROUP -n $env:APP_NAME --query id -o tsv) `
>   --metric Http5xx --aggregation Total --interval PT1M --output table
> ```

**Pass:** one burst-minute row has `Total` between **40** and **60**, and at minimum `Total >= 5`.

**Fail:** every row for the last 10 minutes has `Total = 0`. The worker restart can outlast the script's 10-second wait, causing requests to reach the old process. Wait one minute and re-drive three sessions of 30 `?crash=1` requests. As a manual fallback, browse to `https://<APP_URL>`, click **Increment** at least 6 times to produce a 500, and repeat in multiple sessions until `Total >= 5`.

### Step 3: Wait for ingestion and let the alerts fire

> **Action:** Set a 5-minute timer. App Insights exceptions typically ingest in **2-5 minutes**; the metric alert evaluates every **PT1M** against a **PT5M** rolling window.

Two alerts will fire from the same burst:

| Alert | Source | Severity | Fires when | Module 5 plan reaction |
| --- | --- | --- | --- | --- |
| **`alert-sreinprod-demo-http5xx`** | Bicep metric alert from `infra/main.bicep` | **Sev2** | `count(Http5xx) over PT5M >= 5`, evaluated PT1M | **No autonomous reaction.** The plan filter is `Severity = Sev3`. The alert raises and is visible in `Azure Monitor`, but the response plan does not pick it up. |
| **`Failure Anomalies - appi-sreinprod-demo-<suffix>`** | App Insights smart detector (auto-enabled per App Insights resource) | **Sev3** | Statistical anomaly in failed-request rate | **Plan fires.** Matches `Severity = Sev3`. The agent runs the `EXECUTION_PLAN` end-to-end, posts the result, marks the incident `Acknowledged / Completed`. |

If the metric exists but the Sev3 incident has not appeared after 5 minutes, wait another 5 minutes and refresh **Incidents**. If neither alert appears, repeat Step 2 and verify the metric before continuing.

### Step 4: Confirm the autonomous path - the Incidents inbox

> **Action:** Open **Incidents** in the agent's left rail.

![Incidents page now shows a Sev3 row, Acknowledged + Completed, with quickstart_response_plan attached](../images/wizard/65-incidents-with-alert.png)

Expected row:

- Alert title: `failure anomalies - appi-sreinprod-demo-<suffix>`
- Severity: `Sev3`
- Alert status: `Acknowledged`
- Agent status: `Completed`
- Response plan: `quickstart_response_plan`

`Completed` under **Review** does not by itself prove that no write occurred. Confirm the plan autonomy and later verify that no write tool ran before approval.

> **Action:** Click the alert title to open the agent's response-plan summary in chat.

Briefly review the response-plan summary, then return to a new chat thread.

### Step 5: Open chat and submit the investigation prompt

> **Action:** In the left rail click **`+ New Chat Thread`**.

> **Action:** Paste the workshop prompt verbatim into the input. Use this exact wording so participant traces match the screenshots:

```text
We are seeing a spike of HTTP 500 errors on our production application.
Users started reporting issues in the last few minutes.
Can you investigate the cause of these 500 errors and identify the
likely root cause?
```

![Prompt typed into the chat input, Send button active](../images/wizard/60-investigation-prompt-typed.png)

> **Action:** Press **`Ctrl+Enter`** (or click the round blue Send button).

**Pass:** the thread is titled `Production HTTP 500 Error Spike Investigation`, the first response appears within a few seconds, and investigation cards begin to render.

![Investigation kicks off, reasoning chip rendered, first reply visible](../images/wizard/61-investigation-running.png)

### Step 6: Watch the agent gather evidence in parallel

> **Action:** Watch for evidence from Azure Monitor logs, resource inventory, Activity Log, current App Service settings, and `Program.cs` through the Code connector.

![Multiple tool cards: 2x Monitor Resource Log Query Completed, Executing resource list (Safe), Retrying App Insights queries](../images/wizard/62-investigation-tools-running.png)

![Three Monitor Resource Log Query rows, Activitylog list completed, Reading Program.cs and demo-inject-errors.ps1, Setting resource configuration medium-risk badge](../images/wizard/63-investigation-progress2.png)

Check that:

- Read/query cards finish as `Completed`; a retry is acceptable if the later query succeeds.
- Evidence includes the 500 spike, `Microsoft.Web/sites/config/write`, `INJECT_ERROR=1`, and the matching source-code throw.
- Tool names may include `RunAzCliReadCommands`, `monitor-client_monitor_resource_log_query`, `SearchIncidentKnowledge`, and `ManageTodoList`.
- A configuration capability may show **Medium risk** even for a read. Inspect the inline command every time. Do not approve unless the command is the intended operation against the intended production resource.

If a query remains failed, verify the Module 4 connectors are healthy and the agent identity can read `rg-sreinprod-demo`, then retry the prompt.

### Step 7: Read the final report

> **Action:** After ~90-120s of tool work the agent assembles a final report under the chat title **`Production HTTP 500 Error Spike Investigation`**. Scroll to the bottom of the thread.

![Final report: Timeline with operator UPN, Root Cause with INJECT_ERROR=1, code quote at Program.cs:11, exception name and call site, Recommended Mitigation prompt](../images/wizard/64-investigation-progress3.png)

Expected findings:

- **Timeline:** the app-setting write precedes the first 500s and identifies the initiating principal.
- **Root Cause:** production has `INJECT_ERROR=1`.
- **Code evidence:** `Program.cs:11` reads `INJECT_ERROR`, and the later branch throws `Simulated error after 5 button clicks!`.
- **Exception evidence:** `System.Exception` and recent occurrences are reported.
- **Current State:** production remains faulted; staging may also have `INJECT_ERROR=1`.
- **Recommended Mitigation:** the agent asks whether to remove or reset `INJECT_ERROR` on production instead of writing immediately.

If the report lacks Activity Log, configuration, or code evidence, do not approve remediation. Resolve the failed connector or tool card and rerun the investigation.

### Step 8: Inspect the trace

> **Action:** Click **`View trace`** at the top right of the chat.

![Expanded trace tree showing claude-opus-4-6 model generations, Reasoning spans, Tool calls including ManageTodoList, RunAzCliReadCommands, monitor-client_monitor_resource_log_query x2, SearchIncidentKnowledge](../images/wizard/67-trace-view.png)

> **Action:** Expand the root **`meta_agent`** span, then select at least one tool node and inspect its literal input and output.

Expected tool names include `ManageTodoList`, `RunAzCliReadCommands`, `monitor-client_monitor_resource_log_query`, and `SearchIncidentKnowledge`. Confirm the input targets the expected subscription/resource and the output supports the final report.

### Step 9: Decide on remediation

Back in the chat thread, the agent's last message is the question:

> *"Would you like me to remove the `INJECT_ERROR` setting from the production app?"*

> **Action:** Reply with one choice:

| Reply | Operational consequence |
| --- | --- |
| **`yes`** (or `approve`, `go ahead`) | The agent sets production `INJECT_ERROR=0`, waits for propagation, probes recovery, and reports completion. Continue to Step 10. |
| **`no, leave the broken state in place`** | No slot changes. The incident remains `Acknowledged / Completed`; the environment stays faulted for another cohort. This is the workshop default. |
| **`first, swap slots back`** | The agent should refuse or warn because staging may also be faulted, then propose fixing production directly. |

> **Critical:** Approval authorizes a production write. Recheck the inline command, target app, slot, setting, and value before approving. Approval text is retained in chat, but the trace does not retroactively annotate the earlier proposal with approver identity and time. Preserve both chat and trace for an incident audit.

### Step 10 *(optional)*: Validate recovery

Only run this step if you replied **`yes`** in Step 9.

> **Action:** From the workshop root, run:
>
> ```powershell
> pwsh ./scripts/smoke-test.ps1
> ```

The script issues `Invoke-WebRequest` against both `https://<APP_URL>` and `https://<STAGING_URL>` and asserts `200`. Expected output:

```text
Probing production: https://app-sreinprod-demo-<suffix>.azurewebsites.net ... 200
Probing staging:    https://app-sreinprod-demo-<suffix>-staging.azurewebsites.net ... 200
✅ Smoke test passed.
```

If production returns `200` and the agent's **Incidents** row has *not* moved off `Acknowledged / Completed`, that is correct: the row reflects the **alert** state, not the **resource health** state. Azure Monitor will resolve the metric alert on its own once the rolling 5-minute window clears.

### Step 11 *(optional)*: Look at the Operations Hub volume chart

> **Action:** Re-open **Operations Hub** in the left rail.

The **`Daily Volume by Source`** chart should have a fresh bar on today's date:

![Operations Hub after the incident, Daily Volume bar with Conversations purple and Incidents orange on today](../images/wizard/68-ops-hub-post-incident.png)

**Pass:** the bar has non-zero **Conversations** and **Incidents** segments. Allow several minutes and refresh if it has not updated.

### Step 12 *(optional)*: Reset for the next run

If you replied **`no`** in Step 9, the environment is already in the right shape for the next workshop cohort - **stop here**.

If you replied **`yes`** and want to put the broken state back for someone else:

> **Action:** Run:
>
> ```powershell
> pwsh ./scripts/demo-rollback.ps1
> ```

The script re-asserts `INJECT_ERROR=0` on production (idempotent), `INJECT_ERROR=1` on staging (matching the post-deploy baseline), and runs a single smoke test. **It does not delete the chat thread or the Incidents row** - those are useful as historical context for the next cohort. Delete them by hand if you want the agent to look "fresh".

## Validation checklist

- [ ] **Pre-burst baseline** captured: `Operations Hub` shows `Agent Process: Healthy`, `Connectors Overview: 4 Healthy`, **flat** `Daily Volume by Source` for today; `Incidents` page reads `0 / 0` across all counters.
- [ ] **Fault confirmed in metrics** with `az monitor metrics list ... Http5xx ... Total >= 5` on the production slot for at least one PT1M bucket inside the burst window.
- [ ] **Both alerts fired**: `alert-sreinprod-demo-http5xx` (Sev2, visible in Azure Monitor → Alerts) and `Failure Anomalies - appi-sreinprod-demo-<suffix>` (Sev3, visible in the agent's `Incidents` page).
- [ ] **Sev3 row** in the agent's Incidents page reads `Acknowledged / Completed` with `Response plan = quickstart_response_plan` (proves Module 5 wired correctly and `Review` autonomy did not block read-only diagnosis).
- [ ] **Sev2 row** is **absent** from the agent's Incidents page (proves the response plan filter is structural, per Module 5).
- [ ] **Chat investigation** thread exists with title **`Production HTTP 500 Error Spike Investigation`** and a final report containing **Timeline**, **Root Cause**, a **fenced code quote** of `Program.cs:11`, the verbatim exception **`Simulated error after 5 button clicks!`**, and a **Recommended Mitigation** ending in *"Would you like me to ...?"*.
- [ ] **Trace** includes `monitor-client_monitor_resource_log_query`, `RunAzCliReadCommands`, and `ManageTodoList`; at least one tool input/output was inspected.
- [ ] **Approval gate held**: no `UpdateAppSettings` / `RunAzCliWriteCommands` span fired before the operator typed an approval. (Verify by Ctrl+F in the trace JSON if needed.)
- [ ] **Operations Hub** `Daily Volume by Source` shows a non-zero bar for today with **Conversations** + **Incidents** segments.

## What you learned

One injected configuration fault can produce multiple alerts with different severities and routing behavior. The response-plan filter controls which alert the agent handles, read-only investigation can complete under **Review**, and remediation remains a human decision. Evidence must connect telemetry, Activity Log, current configuration, and source code before recovery; trace and chat together provide the fuller audit record.

[Explore the concepts and reference material](../Learning/6-Incident-Drill.md) | [Workshop home](./ReadMe.md)
<!-- End of Module 6 workshop exercise. -->
