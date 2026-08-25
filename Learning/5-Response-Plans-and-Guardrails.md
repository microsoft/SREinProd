# Module 5 Learning - Response Plans and Guardrails

[← Back to the Response Plans and Guardrails workshop exercise](../Workshop/5-Response-Plans-and-Guardrails.md) | [Learning home](./README.md)

## Purpose

This companion provides the conceptual model, guardrail analysis, portal reference, discussion prompts, screenshot index, and repository maintenance notes for the executable [Response Plans and Guardrails workshop exercise](../Workshop/5-Response-Plans-and-Guardrails.md).

## What this module adds (and what it does not)

| Aspect | What it is | What it is not |
| --- | --- | --- |
| **Incident Platform** | A *one-per-agent* connection (`PagerDuty`, `ServiceNow`, or `Azure Monitor`) that lets the agent **subscribe to incidents**, not just answer chat queries. It is configured under **`Builder` → `Incident Platform`**. Azure Monitor requires no additional provisioning: the agent listens to notifications from resource groups it already manages. | A telemetry connector. Connectors answer "what is happening right now"; the Incident Platform announces that an alert fired. |
| **Incident Response Plan** | A per-severity or per-title policy that wraps each matching incident with a generated `EXECUTION_PLAN`, an allow-listed **Manage tools** set, an **Autonomy level**, and an **Alert reinvestigation cooldown**. Saved plans live under **`Builder` → `Incident Response Plans`**. | A chat prompt. Chat is opt-in per thread; a response plan starts when a matching incident arrives. |
| **Quickstart Response Plan** | A toggle on Incident Platform setup that creates `quickstart_response_plan` for Sev3 with status `On` when Azure Monitor connects. The portal warns: *"This will create an autonomous response plan that begins processing incidents immediately after the platform is connected."* | Safe by default in every editor state. The initial table row reads **Autonomy: Review**, but selecting *"I want a custom response plan"* resets the final wizard radio to **`Autonomous (Default)`**. Recheck it before every save. |
| **Manage tools** picker | The alphabetical catalog of tools available to the plan. Search matches both **Tool** and **Description**. Descriptions include policy such as `RunAzCliWriteCommands`: *"FORBIDDEN: 'delete', 'remove', 'aks command invoke'"*. | The only guardrail. Generated prose can say *"do not execute it"* while Suggested tools still includes a mutating tool. Removing dangerous tools is the structural control. |
| **Autonomy level** | A plan-level choice between **`Autonomous (Default)`**, which can analyze and remediate, and **`Review`**, which analyzes and waits for approval before modification. Different plans can use different postures. | A per-incident switch. A single plan cannot choose its autonomy each time it fires. |

For the broader catalog, including PagerDuty, ServiceNow, and programmatic plan creation, see [Incident response plans in Azure SRE Agent](https://go.microsoft.com/fwlink/?linkid=2341945).

## Incident platform and Quickstart behavior

Only one incident platform can be connected to an agent. Changing platforms requires deleting the current connection. The available platform choices captured for this workshop were:

| Option | Use |
| --- | --- |
| **PagerDuty** | Existing PagerDuty paging workflows; requires an integration key. |
| **ServiceNow** | ServiceNow ITSM routing; requires an instance URL and OAuth app. |
| **Azure Monitor** | Workshop choice; subscribes to notifications from resource groups the agent already manages. |

A response plan cannot be created before an incident platform is connected because it has no incident inbox. Disconnecting Azure Monitor is destructive: it also deletes all configured response plans. Treat the platform as a deployment decision rather than a routine operational toggle.

Quickstart uses Sev3, the Azure Monitor warning severity, so it does not automatically target Sev0 or Sev1 paging events. Its default filter can later be changed in the plan editor. The tension in the UI is deliberate to notice: Quickstart warns that it creates an autonomous plan, the initial row can display `Review`, and converting the plan to custom resets the final autonomy control to `Autonomous (Default)`.

## Generated plan versus tool permissions

The response-plan generator rewrites natural-language instructions into `### EXECUTION_PLAN ###`, usually with **Guidelines** and numbered **Investigation and Diagnosis Steps**. That generated block is editable and becomes the contract placed into agent context when the plan fires.

The generated plan and its tool list are independent surfaces. In the workshop example, both the input instructions and generated plan require approval before writes, yet Suggested tools can include `UpdateAppSettings`, whose description says it retries once without notifying the user if the first attempt fails. This is the contract gap the participant must identify.

The **Manage tools** catalog includes read and write capabilities. Early alphabetical examples include:

| Tool | Description excerpt |
| --- | --- |
| `AnalyzeDeploymentFailures` | Analyzes Azure deployment failures and returns troubleshooting detail. |
| `CancelScheduledTask` | Cancels or deletes a scheduled task by ID. |
| `CheckIfResourceExists` | Checks whether an Azure resource exists. |
| `CheckTcpConnectivity` | Checks connectivity from a resource to a target host. |
| `CompareRuns` | Compares pipeline runs for task, branch, and commit differences. |

Searching for `update` matches names and descriptions. In the captured environment it returned `RunAzCliWriteCommands`, whose full policy described Azure write operations; required user approval; required a valid `--subscription`; allowed `create`, `update`, `set`, `scale`, `start`, `stop`, `restart`, and `add`; and forbade `delete`, `remove`, and `aks command invoke`. It also directed diagnostic and telemetry work to read-oriented tools, required a read before a write, required an explanation of the change, recommended rollback commands, and required concise pre-execution notification.

Those prose constraints matter, but the stronger controls are structural:

1. The plan can call only tools selected in **Manage tools**.
2. **Review** autonomy blocks mutation until a human approves.
3. The plan filter limits which alerts can invoke the workflow.
4. The cooldown limits repeated investigations during an alert storm.

For a diagnose-and-propose plan, exclude mutating tools rather than depending on their descriptions or the generated plan to keep them idle.

## Save-step controls

| Control | Captured default | Meaning |
| --- | --- | --- |
| **Autonomous (Default)** | Selected after converting Quickstart to custom | With suitable permissions, the agent analyzes and independently modifies resources. |
| **Review** | Not selected | The agent diagnoses, then waits for review and approval before modifying resources. |
| **Run deep investigation autonomously** | Off | Adds a longer root-cause sweep and higher token cost. |
| **Alert reinvestigation cooldown** | Enabled, `3 hours` | Skips reinvestigation when the same alert refires within the cooldown. |

The response plan's autonomy is bound to the plan, not to a specific incident. Review is the workshop posture because the plan is designed to diagnose, propose the least disruptive action, and wait.

The **Test the response plan** tab is a dry-run surface for processing a synthetic Sev3 incident and reviewing tool calls. It remains empty until a test is triggered. The workshop skips it because Module 6 supplies a real Http5xx burst.

After saving, reopening the plan keeps **`I want a custom response plan.`** selected. Clearing that checkbox does not delete the existing `EXECUTION_PLAN`; it collapses the editor to the three-step filter flow. Select it again to return to Review and Save.

## Discussion prompts

- Quickstart warns that an autonomous response plan begins processing immediately. What should a production golden image use: Quickstart off, Quickstart with Review, or Quickstart with Autonomous? Consider blast radius, onboarding friction, change control, and Reader-only identities.
- Tool descriptions encode policies such as required approval and forbidden verbs. Should teams trust those descriptions or maintain explicit allow-lists per plan? Consider tool versioning, ownership, and audit history.
- Instructions and `EXECUTION_PLAN` can require approval while Suggested tools still includes `UpdateAppSettings`. Who owns reconciliation and regression testing: the platform team, the service team, or both?
- A plan binds severity to autonomy. What policy should Sev0 through Sev4 use when diagnosis, messaging, failover, and capacity remediation have different risks?
- Module 4 supplies **View trace** for chat and Module 5 supplies **Test the response plan** for incidents. What else is needed for reproducible review? Consider trace export, plan diffs, plan versioning, and approval identity.

## Full screenshot index

Captured against the live portal in June 2026. Files live under `images/wizard/` for facilitator reuse.

| # | Screen | File |
| --- | --- | --- |
| 37 | Incident Response Plans empty state; New disabled | [37-response-plans-page.png](../images/wizard/37-response-plans-page.png) |
| 38 | Incident Management Step 1; empty platform dropdown | [38-incident-platform-catalog.png](../images/wizard/38-incident-platform-catalog.png) |
| 39 | Platform options: PagerDuty, ServiceNow, Azure Monitor | [39-platform-dropdown.png](../images/wizard/39-platform-dropdown.png) |
| 40 | Azure Monitor selected | [40-azure-monitor-selected.png](../images/wizard/40-azure-monitor-selected.png) |
| 41 | Quickstart enabled and warning shown | [41-quickstart-toggle-on.png](../images/wizard/41-quickstart-toggle-on.png) |
| 42 | Connecting state | [42-platform-connected.png](../images/wizard/42-platform-connected.png) |
| 43 | Azure Monitor connected; Edit and Disconnect | [43-azure-monitor-connected.png](../images/wizard/43-azure-monitor-connected.png) |
| 44 | Quickstart plan row | [44-response-plans-with-default.png](../images/wizard/44-response-plans-with-default.png) |
| 45 | Three-step editor; custom unchecked | [45-quickstart-plan-detail.png](../images/wizard/45-quickstart-plan-detail.png) |
| 46 | Four-step editor; custom checked | [46-custom-plan-fields.png](../images/wizard/46-custom-plan-fields.png) |
| 47 | Define agent learning | [47-define-agent-learning.png](../images/wizard/47-define-agent-learning.png) |
| 48 | Workshop instructions entered | [48-instructions-typed.png](../images/wizard/48-instructions-typed.png) |
| 49 | Generated plan and Suggested tools | [49-review-custom-plan.png](../images/wizard/49-review-custom-plan.png) |
| 50 | Full Manage tools catalog | [50-manage-tools.png](../images/wizard/50-manage-tools.png) |
| 51 | Catalog filtered by `update` | [51-manage-tools-update-filter.png](../images/wizard/51-manage-tools-update-filter.png) |
| 52 | Test response plan tab | [52-test-tab.png](../images/wizard/52-test-tab.png) |
| 53 | Save step with Autonomous selected | [53-save-step.png](../images/wizard/53-save-step.png) |
| 54 | Save step with Review selected | [54-review-mode-selected.png](../images/wizard/54-review-mode-selected.png) |
| 55 | Saved plan: Created, On, Review | [55-saved-plan-list.png](../images/wizard/55-saved-plan-list.png) |

## Further reading

- [Incident response plans in Azure SRE Agent](https://go.microsoft.com/fwlink/?linkid=2341945): plan structure, supported severities, and platform connectors.
- [Module 4 workshop](../Workshop/4-Connect-Observability.md): creates `log-analytics-demo` and `app-insights-demo`.
- [Module 6 workshop](../Workshop/6-Incident-Drill.md): injects an Http5xx burst and exercises the Sev3 plan.

## Notes for repository owners

Re-capture screenshots `37` through `55` if the platform catalog changes, the Quickstart severity or warning changes, the plan wizard steps change, Manage tools is reorganized, the `RunAzCliWriteCommands` forbidden list changes, an autonomy option is added, or the cooldown default changes.

The most volatile captures are **49**, because generated plans are model-dependent; **50/51**, because the tool catalog evolves; and **53**, because autonomy and cooldown defaults can change independently of workshop content.

[← Return to the Response Plans and Guardrails workshop exercise](../Workshop/5-Response-Plans-and-Guardrails.md) | [Learning home](./README.md)
