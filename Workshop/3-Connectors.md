# Module 3 - Connectors

[← Module 2: Deploy the Agent](./2-Deploy-Agent.md) | [Workshop home](./ReadMe.md) | [Next: Module 4 →](./4-Connect-Observability.md)

## Objective

Extend the agent's tool surface beyond what Module 2 wired up by adding a **connector**. Connectors are the agent's pluggable integrations: telemetry stores it can query (Log Analytics, Application Insights, Datadog, Splunk, etc.) and code repositories it can read (you already added one in Module 2: `app-service-dotnet-agent-tutorial`).

In this module the participants:

1. Open the **Connectors** page on the agent.
2. Walk the catalog and pick a tile they recognise.
3. Add a **Log Analytics Workspace** connector pointing at the workshop's workspace `log-sreinprod-demo-<suffix>`.
4. Validate from chat that the agent can now see tables and rows in that workspace.
5. Discuss when to add, scope, or remove a connector.

> Time: ~25 min (5 min framing, 15 min hands-on, 5 min discussion).
> Prereq: a working agent from Module 2 (`sreagent-sreinprod`), and the `log-sreinprod-demo-<suffix>` workspace from Module 1 (visible in `scripts/env.conf`).

## What a connector is (and is not)

| Aspect | What it is | What it is not |
| --- | --- | --- |
| **Connectors** | Optional, discrete tool integrations the agent can call to read or write external systems while reasoning about an incident. Telemetry connectors give the agent KQL access to specific workspaces and code connectors give it indexed source. | A replacement for the Azure RBAC the agent already has on the resources you attached in Module 2 |
| **Examples in the catalog** | **Telemetry**: Azure Data Explorer, Log Analytics Workspace, Application Insights, Datadog, Elasticsearch, Dynatrace, New Relic, Splunk, Hawkeye. **Code Repository**: GitHub, Azure DevOps. | Anything reachable purely through Azure RBAC (the agent already has that path from Module 2) |
| **Why use one** | The agent can take a closed-loop action: query a specific workspace by name, file a ticket, post to chat, etc. The connector becomes a named tool the agent picks when reasoning. | A connector does not bypass the agent's response plan or its RBAC. You still control approvals and the connector's identity is the agent's managed identity. |

For the catalog and configuration reference, see [Connectors in Azure SRE Agent](https://go.microsoft.com/fwlink/?linkid=2341945) on Microsoft Learn.

## Lab steps

> The portal at `https://sre.azure.com` exposes a **3-step Add connector wizard** (`Choose a connector`, `Set up connector`, `Review + add`). The wizard is the same shape no matter which tile you pick. We will walk it for **Log Analytics Workspace** because the workshop's workspace already exists from Module 1 and pointing the agent at it is a measurable end-to-end success.

### At a glance

The lab is 7 steps. Each step below adds the context and the *why*.

1. **Step 1:** In the agent, **`Builder`** -> **`Connectors`** opens the page.
2. **Step 2:** Toolbar **`+ Add connector`** opens the 3-step wizard.
3. **Step 3:** On the **Telemetry** tab, tick **`Log Analytics Workspace`**, click **`Next`**.
4. **Step 4:** Fill **Name** = `log-analytics-demo`, pick the workshop workspace, leave **Managed identity** = `System assigned`, click **`Next`**. (If needed, grant **Log Analytics Reader** to the agent's MI first.)
5. **Step 5:** On **Review + add**, click **`Add connector`**.
6. **Step 6:** Open a **`+ New Chat Thread`** and paste the validation prompt. Confirm tables + KQL rows return.
7. **Step 7:** Decide whether to keep or delete the connector via the row's **`...`** kebab menu.

### Step 1: Open the Connectors page

> **Action:**
>
> 1. Open the agent at `https://sre.azure.com/agents/subscriptions/<subId>/resourceGroups/rg-sreinprod-agent/providers/Microsoft.App/agents/sreagent-sreinprod`.
> 2. In the left navigation, expand **`Builder`** and click **`Connectors`**.

You should see the page header **"Connectors"** with the introductory copy:

> *Add a connector to give the agent additional tools for automating incident handling.* [Learn more about connectors](https://go.microsoft.com/fwlink/?linkid=2341945)

The toolbar exposes **`+ Add connector`**, **`↻ Refresh`**, **`🗑 Remove`** (disabled until rows are selected), and a **`Category : All`** filter dropdown.

> ℹ️ At this point the page already shows one connector group, **`Code Repository (1)`**, listing the `app-service-dotnet-agent-tutorial` row you wired up in Module 2. That row is itself a connector. Adding **Log Analytics Workspace** in this module will cause a second group, **`Telemetry (1)`**, to appear above it.

### Step 2: Open the **Add connector** wizard

> **Action:** Click **`+ Add connector`** on the toolbar.

A side dialog titled **"Connectors"** opens with a 3-step header:

| # | Step name |
| --- | --- |
| 1 | Choose a connector |
| 2 | Set up connector |
| 3 | Review + add |

Footer buttons: **`Back`**, **`Next`** (disabled until each step is valid), **`Cancel`**.

### Step 3: **Choose a connector** - pick **Log Analytics Workspace**

![Add connector dialog, Telemetry tab with 9 tiles](../images/wizard/18-add-connector-dialog.png)

The first step shows a category tab strip. The **`Telemetry`** tab is selected by default and lists nine tiles:

| Tile | What it integrates |
| --- | --- |
| **Azure Data Explorer** | Kusto cluster databases |
| **Log Analytics Workspace** ⭐ this lab | A specific Log Analytics workspace |
| **Application Insights** | A specific Application Insights resource |
| **Datadog** | Datadog metrics and logs |
| **Elasticsearch** | Elastic stack |
| **Dynatrace** | Dynatrace tenant |
| **New Relic** | New Relic account |
| **Splunk** | Splunk index |
| **Hawkeye** | Hawkeye observability platform |

Tick the checkbox on the **`Log Analytics Workspace`** tile. The tile's checkbox toggles to checked and the **`Next`** button activates.

> 🐞 **Known gotcha:** clicking the body of a tile sometimes only highlights it without toggling its checkbox. If **`Next`** stays disabled, click the small checkbox at the top-left corner of the tile directly.

> **Action:** Tick the checkbox on the **`Log Analytics Workspace`** tile, then click **`Next`**.

### Step 4: **Set up connector** - configure the workspace

The dialog header changes to **"Set up Log Analytics connector"**. Three required fields:

![Set up Log Analytics connector, workspace dropdown open](../images/wizard/21-workspace-dropdown.png)

| Field | Workshop value | Notes |
| --- | --- | --- |
| **Name\*** | `log-analytics-demo` | This is how the agent will refer to the connector in chat. Lowercase, hyphenated. |
| **Log Analytics workspace\*** | `log-sreinprod-demo-<suffix>` (make sure you select the RG created with the workshop) | Combobox listing every workspace the *agent's identity* can already see. Pick the one Module 1 created. |
| **Managed identity\*** | **`System assigned`** *(default)* | The connector authenticates to Log Analytics as the agent itself. Leave the default. The **`Add identity`** link is for advanced setups where you want a user-assigned identity instead. |

> ℹ️ As soon as you pick the workspace, an info banner appears below it: *"Log Analytics Reader role needed on: <rg-name>"*. The wizard cannot **grant** that role for you (unlike Module 2's *Azure resources* card, which did role assignments inline); it is informational only. If the agent's managed identity does not already have **Log Analytics Reader** on the RG holding the workspace, the connector will land in **`Status: Failed`** instead of **`Connected`**. For the workshop, the agent's RBAC on `rg-sreinprod-app` from Module 2 does **not** automatically extend to `rg-sreinprod-demo`. If the workspace lives in a different RG than the one you attached in Module 2, grant the role explicitly:
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
>   --role "Log Analytics Reader" `
>   --scope "/subscriptions/<subId>/resourceGroups/rg-sreinprod-demo"
> ```
>
> Alternatively, point the connector at the workspace under `rg-sreinprod-app` (the one created by `azd up` for the demo web app), since the agent already holds `Log Analytics Reader` there from Module 2's Privileged-mode role assignment.

> **Action:** Fill the three fields above, then click **`Next`**.

### Step 5: **Review + add** - commit the connector

The dialog header changes to **"Review + add"** and echoes back the four values you set:

![Review + add pane showing connector summary](../images/wizard/22-review-add.png)

| Section | Value |
| --- | --- |
| **Connector** | Log Analytics Workspace (subtitle: Log Analytics) |
| **Name** | `log-analytics-demo` |
| **Log Analytics workspace** | `log-sreinprod-demo-<suffix>` |
| **Managed identity** | `System assigned` |

> **Action:** Click **`Add connector`**.

The dialog closes and you land back on the **Connectors** page. The toolbar now also shows **`Search`**, **`Expand all`**, and **`Collapse all`**, and the page lists two collapsible groups:

![Connectors page after Log Analytics added, two groups](../images/wizard/23-connectors-after-log-analytics.png)

| Group | Row | Service | Status | Source |
| --- | --- | --- | --- | --- |
| **Telemetry (1)** | `log-analytics-demo` | Log Analytics | ✅ Connected | Agent |
| **Code Repository (1)** | `app-service-dotnet-agent-tutorial` | GitHub | ✅ Connected | Agent |

> ⚠️ If the Telemetry row reads anything other than **Connected**, hover the status to read the inline error. The two most common failures are:
>
> - **Permission error**: the agent's managed identity is missing **Log Analytics Reader** on the workspace's RG. Grant it as shown in Step 4 and click the toolbar **`↻ Refresh`**.
> - **Workspace deleted / moved**: the connector keeps the workspace's resource ID. If Module 1's RG was torn down and recreated, edit the connector (kebab menu) to repoint it.

### Step 6: Validate from chat

> **Action:** Open a **`+ New Chat Thread`** in the agent's left rail (the icon at the very top, above **Search Threads**) and ask:

```text
List the table names available in the log-analytics-demo connector and show the 3 most recent AppServiceHTTPLogs entries from the last hour. If AppServiceHTTPLogs has no rows, list whatever tables you do see and show 3 rows from each.
```

A correct answer:

![Agent answer enumerating tables and showing AppServiceHTTPLogs rows](../images/wizard/25-chat-validate-connector.png)

- enumerates standard App Service tables (`AppServiceHTTPLogs`, `AppServiceAppLogs`, `AppServiceConsoleLogs`, `AppServiceAuditLogs`, etc.),
- runs a KQL query against the workspace, and
- returns 3 rows whose `Host` column matches `app-sreinprod-demo-<suffix>.azurewebsites.net` (production) and `app-sreinprod-demo-<suffix>-staging.azurewebsites.net` (staging slot).

**Why this prompt:** the model has to (a) call out to the new connector by name, (b) issue a `getschema` to enumerate tables, then (c) run a parameterised KQL query. If any of those three steps fails the answer will either be empty, hallucinate table names that are not in the workspace, or return host names that do not match your `azd env get-values`.

> 💡 **Cross-check with Module 2.** The `Host` values in the answer should match the `WEBAPP_NAME` in `scripts/env.conf` and the **`AlwaysOn`** pings hitting both slots prove that Module 1's deployment is healthy. If the rows reference a different web app, the connector is pointed at the wrong workspace.

### Step 7: Manage and clean up

> **Action:** On the SRE Agent portal, return to the Connectors page. Hover the `log-analytics-demo` row and click the **`...`** kebab button.

Two actions are exposed:

| Action | When to use it |
| --- | --- |
| **Edit connector** | Repoint the connector at a different workspace, or rename it. The Set up connector form opens with the existing values. |
| **Delete connector** | Remove the connector entirely. The agent's managed identity keeps any RBAC roles you granted on the workspace; clean those up separately if you no longer need them. |

For the workshop you can **leave the connector in place**. Module 4 will use it in chat (the agent picks `log-analytics-demo` over the implicit RBAC path because the connector is named) and Module 6 relies on the agent's ability to read App Service logs.

If your tenant security policy forbids leaving a Log Analytics connector wired to a learning environment, **Delete** the connector at the end of Module 3 and re-add it at the start of Module 4.

## Discussion prompts

- The agent already had RBAC on `rg-sreinprod-app` from Module 2. **What did adding the Log Analytics Workspace connector buy you that the implicit RBAC path didn't?** *(Hint: a named tool, predictable target workspace, less ambiguity in chat prompts, easier to revoke.)*
- The wizard surfaced the **`Log Analytics Reader role needed`** banner but did not assign the role itself. **Should it?** *(Module 2's Azure resources card does grant roles inline; the Connectors flow does not. Discuss the trade-off: explicit security review vs. one-click setup.)*
- Walk through the other Telemetry tiles (Datadog, Splunk, etc.). **For each one your team actually runs, what is the minimum scope a connector should have?**
- The kebab menu only exposes **Edit** and **Delete**. There is no **Disable** toggle. **How would you take a connector offline temporarily without losing its configuration?** *(Options: rotate the managed identity's RBAC, scope the connector to an empty workspace, delete and re-add from a saved template in your IaC repo.)*

## Validation checklist

- [ ] The **Connectors** page shows the **Telemetry (1)** group with `log-analytics-demo` / Log Analytics / Connected / Agent.
- [ ] The agent's managed identity holds **Log Analytics Reader** on the RG holding the workspace.
- [ ] In chat, the agent can list tables in the workspace and run KQL against `AppServiceHTTPLogs`.
- [ ] The host names returned by KQL match the `WEBAPP_NAME` recorded in `scripts/env.conf`.
- [ ] The kebab (`...`) menu on the row exposes **Edit connector** and **Delete connector**, and you know which one your security policy will require at the end of the workshop.

## Reference: full screenshot index

The screenshots embedded above capture the moments where the wizard transitions or where validation evidence is highest-value. The full set (captured against the live portal in June 2026) lives under `images/wizard/` for facilitators who want to build a slide deck:

| # | Screen | File |
| --- | --- | --- |
| 17 | Connectors page (initial: Code Repository only) | [17-connectors-page.png](../images/wizard/17-connectors-page.png) |
| 18 | Add connector, Choose a connector (Telemetry tab, 9 tiles) ⭐ embedded | [18-add-connector-dialog.png](../images/wizard/18-add-connector-dialog.png) |
| 19 | Add connector, Log Analytics Workspace selected | [19-log-analytics-selected.png](../images/wizard/19-log-analytics-selected.png) |
| 20 | Set up Log Analytics connector (empty form) | [20-set-up-connector.png](../images/wizard/20-set-up-connector.png) |
| 21 | Set up connector, workspace dropdown open ⭐ embedded | [21-workspace-dropdown.png](../images/wizard/21-workspace-dropdown.png) |
| 22 | Review + add ⭐ embedded | [22-review-add.png](../images/wizard/22-review-add.png) |
| 23 | Connectors page after Log Analytics added (2 groups) ⭐ embedded | [23-connectors-after-log-analytics.png](../images/wizard/23-connectors-after-log-analytics.png) |
| 24 | Connector row context menu (Edit / Delete) | [24-connector-row-menu.png](../images/wizard/24-connector-row-menu.png) |
| 25 | Chat validation: tables and AppServiceHTTPLogs rows ⭐ embedded | [25-chat-validate-connector.png](../images/wizard/25-chat-validate-connector.png) |

## Further reading

- [Connectors in Azure SRE Agent](https://go.microsoft.com/fwlink/?linkid=2341945): the official catalog and configuration reference.
- [Module 2: Deploy the Agent](./2-Deploy-Agent.md) wired up the GitHub **Code Repository** connector that already shows up on the Connectors page.
- [Module 4: Connect Observability](./4-Connect-Observability.md) takes the Log Analytics connector you just added and shows how to drive it from chat at incident time.
- [Module 5: Response Plans and Guardrails](./5-Response-Plans-and-Guardrails.md) governs *when* the agent is allowed to invoke any connector tool.

## Notes for repo owners

Re-capture screenshots `17` to `25` if the portal redesigns the **Connectors** page or the **Add connector** wizard. The most volatile elements are the tile catalog (new providers ship regularly) and the kebab menu actions (a `Disable` toggle has been requested and may land before this doc is updated).
