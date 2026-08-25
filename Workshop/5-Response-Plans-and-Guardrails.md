# Module 5 - Response Plans and Guardrails

[← Module 4: Connect Observability](./4-Connect-Observability.md) | [Workshop home](./ReadMe.md) | [Next: Module 6 →](./6-Incident-Drill.md)

[Learning companion: response-plan concepts, discussion, and reference](../Learning/5-Response-Plans-and-Guardrails.md)

## Objective

Connect Azure Monitor as the incident inbox, customize the Quickstart Sev3 response plan, restrict its tools, and save it with **Review** autonomy so diagnosis can run but resource changes require human approval.

> Time: ~30 minutes.
> Prerequisite: Module 4 is complete. `log-analytics-demo` and `app-insights-demo` both show **Connected**, and the agent identity has at least **Reader** on `rg-sreinprod-demo`.

## Safety contract

This workshop plan must **diagnose and propose**, not mutate resources. Keep these controls aligned:

- The generated `EXECUTION_PLAN` must require approval before writes.
- Do not add mutating tools in **Manage tools**. A tool description is guidance; excluding the tool is the stronger guardrail.
- Save the plan with **`Review`**, not **`Autonomous (Default)`**.
- Leave deep investigation off and the reinvestigation cooldown enabled at `3 hours`.

> ⚠️ Selecting **`I want a custom response plan.`** resets the final autonomy radio to **`Autonomous (Default)`**, even when the Quickstart row previously showed `Review`. Re-select **Review** before saving.

## At a glance

1. Open **`Builder` → `Incident Response Plans`** and connect an incident platform.
2. Select **Azure Monitor**, enable **Create a default response plan**, and save.
3. Open `quickstart_response_plan` and enable the custom-plan flow.
4. Paste the workshop instructions and generate the structured plan.
5. Review `EXECUTION_PLAN` and Suggested tools.
6. Inspect **Manage tools** and exclude mutating tools.
7. Check the test surface, then save with **Review** and a `3 hours` cooldown.

## Step 1: Connect the incident platform

> **Action:** In the agent's left rail, open **`Builder` → `Incident Response Plans`**.

The first-run page shows **`+ New incident response plan`** disabled because no incident inbox is connected.

![Incident Response Plans empty state](../images/wizard/37-response-plans-page.png)

> **Action:** Click **`Connect an incident platform`**.

On **Incident Management**, open the required **`Incident Platform *`** dropdown.

![Incident platform selector](../images/wizard/38-incident-platform-catalog.png)

> **Action:** Select **`Azure Monitor`**.

Azure Monitor is the workshop choice because it listens to notifications from resource groups the agent already manages without additional provisioning.

![Azure Monitor selected](../images/wizard/40-azure-monitor-selected.png)

> **Action:** In **`2 Quickstart Response Plan`**, switch **`Create a default response plan`** to **ON**.

The portal warns:

> *"This will create an autonomous response plan that begins processing incidents immediately after the platform is connected."*

![Quickstart enabled with warning](../images/wizard/41-quickstart-toggle-on.png)

> **Action:** Click **`Save`**.

Wait a few seconds while the page reads **`Connecting...`**. Continue only when the card reads **`Azure Monitor is connected`** and shows **`Edit`** and **`Disconnect`**.

![Azure Monitor connected](../images/wizard/43-azure-monitor-connected.png)

> ⚠️ **Disconnect is destructive.** Disconnecting the incident platform also deletes its response plans.

## Step 2: Confirm the Quickstart plan

> **Action:** Return to **`Incident Response Plans`**.

Confirm the table contains:

| Column | Expected value |
| --- | --- |
| **Incident response plan** | `quickstart_response_plan` |
| **Severity** | `Sev3` |
| **Custom response plan** | `Set up` |
| **Status** | `On` |
| **Autonomy level** | `Review` |

![Quickstart response plan row](../images/wizard/44-response-plans-with-default.png)

Quickstart targets Sev3. Keep that filter for this workshop; Module 6 uses a Sev3 Failure Anomalies alert to exercise it.

## Step 3: Enable the custom plan

> **Action:** Click **`quickstart_response_plan`**.

On **Set up incident filters**, keep these values:

| Field | Value |
| --- | --- |
| **Incident response plan name** | `quickstart_response_plan` |
| **Severity** | `Sev3` |
| **Title contains** | empty |
| **Title does not contain** | empty |

![Quickstart plan editor](../images/wizard/45-quickstart-plan-detail.png)

> **Action:** Select **`I want a custom response plan.`** The wizard expands from three to four steps. Click **`Next`**.

![Custom plan enabled](../images/wizard/46-custom-plan-fields.png)

## Step 4: Generate the plan

On **Define agent learning**, a fresh demo subscription usually has no matching past incidents. Leave **Choose past incidents** empty.

![Define agent learning](../images/wizard/47-define-agent-learning.png)

> **Action:** Paste this text verbatim into **`Enter instructions`**:

```text
When an Http5xx alert fires for app-sreinprod-demo:
1. Pull the last 30 minutes of AppServiceHTTPLogs from the
   log-analytics-demo connector and identify the top failing routes by
   status code.
2. Cross-check exceptions and dependency failures from the
   app-insights-demo connector for the same window. Note any matching
   operation_Id values.
3. List the 3 most recent deployments to both production and staging
   slots.
4. Propose the least disruptive remediation first (slot swap back, app
   setting revert, scale out). Do not execute it.
5. Post a stakeholder-ready summary including: incident ID, suspected
   cause, evidence (with KQL snippets), proposed action, and rollback
   plan.
6. Wait for human approval before any write action. If approval is not
   received within 30 minutes, escalate to the on-call rotation.
```

![Workshop instructions entered](../images/wizard/48-instructions-typed.png)

> **Action:** When **`Generate + review`** becomes active, click it. Generation can take several seconds.

## Step 5: Review the generated contract

On **Review custom incident response plan**, inspect the editable `### EXECUTION_PLAN ###`.

![Generated execution plan and Suggested tools](../images/wizard/49-review-custom-plan.png)

Confirm its opening guidance preserves these requirements:

```text
### EXECUTION_PLAN ###

**Guidelines:**
- This is an HTTP 5xx alert investigation for app-sreinprod-demo
- Perform diagnostics and analysis WITHOUT executing any mitigation actions
- Gather evidence and propose remediation options to stakeholders
- Require explicit human approval before any write operations
- Escalate if approval not received within 30 minutes
```

Then inspect **Suggested tools**. Exact rows can vary by portal version, but read-oriented tools can include `QueryAppInsightsByAppId`, `QueryLogAnalyticsByWorkspaceId`, `GetArmResourceAsJson`, and `GetAppSetting`.

> ⚠️ If **`UpdateAppSettings`** appears, the generated prose did not enforce the tool boundary. Its description says a failed first attempt can be retried once without notifying the user. Remove or exclude mutating tools rather than relying on the prose alone.

## Step 6: Enforce the tool boundary

> **Action:** Click **`+ Manage tools`**, then search for **`update`**.

![Manage tools filtered by update](../images/wizard/51-manage-tools-update-filter.png)

Read the `RunAzCliWriteCommands` description. It requires approval and a valid `--subscription`, allows write verbs such as `create`, `update`, `set`, and `scale`, and forbids `delete`, `remove`, and `aks command invoke`.

> **Decision:** Do **not** add `RunAzCliWriteCommands`, `UpdateAppSettings`, or any other mutating tool. Close the dialog with **`Cancel`**.

> 🔒 The structural controls are the available tool set and the plan's autonomy. The tool descriptions and `EXECUTION_PLAN` are important instructions, but they are not substitutes for excluding write capabilities.

## Step 7: Check the test surface

> **Action:** Open the **`Test the response plan`** tab.

![Test response plan tab](../images/wizard/52-test-tab.png)

This surface can run the plan against a synthetic Sev3 incident. Do not trigger it in this workshop; Module 6 generates a real Http5xx burst.

> **Action:** Return to **`Review custom incident response plan`** and click **`Next`**.

## Step 8: Save with Review autonomy

On **Save response plan**, set exactly:

| Control | Workshop value |
| --- | --- |
| **Choose agent autonomy level** | **`Review`** |
| **Run deep investigation autonomously** | unchecked |
| **Alert reinvestigation cooldown** | enabled |
| **Cooldown time** | `3 hours` |

![Save response plan controls](../images/wizard/53-save-step.png)

> **Action:** Select **`Review`**, verify the other values, and click **`Save`**.

![Saved response plan](../images/wizard/55-saved-plan-list.png)

The final row must read **`Created / On / Review`**. If it reads `Autonomous`, reopen the plan and correct the final radio before continuing.

## Troubleshooting

- **New response plan is disabled:** connect the Incident Platform first.
- **Azure Monitor remains Connecting:** refresh after a few seconds and verify the agent can read its managed resource groups.
- **Generate + review is disabled:** enter instructions in the textarea.
- **Suggested tools contains a write tool:** use **Manage tools** to exclude it; do not assume approval prose makes it harmless.
- **Saved row reads Autonomous:** reopen the custom plan, advance to **Save response plan**, select **Review**, and save again.
- **Custom-plan editor returns to three steps:** reselect **`I want a custom response plan.`** Existing generated content is retained.

## Validation checklist

- [ ] Incident Platform reads **`Azure Monitor is connected`**.
- [ ] `quickstart_response_plan` has **Severity = Sev3**, **Custom response plan = Created**, **Status = On**, and **Autonomy level = Review**.
- [ ] Reopening the plan shows the four-step custom flow.
- [ ] `EXECUTION_PLAN` requires read-only diagnosis and explicit approval before writes.
- [ ] No mutating tool was added for this workshop plan.
- [ ] **Run deep investigation autonomously** is off.
- [ ] Reinvestigation cooldown is enabled at `3 hours`.
- [ ] The agent identity still has at least **Reader** on `rg-sreinprod-demo`.

## What you learned

An incident platform supplies the event, the plan filter chooses which events run, the tool allow-list constrains capabilities, and **Review** autonomy holds resource changes for a human. Module 6 now tests that contract against a real Sev3 incident.

[Explore the concepts and reference material](../Learning/5-Response-Plans-and-Guardrails.md) | [Continue to Module 6 →](./6-Incident-Drill.md)
