# Module 3 Learning - Connectors

[← Back to the Connectors workshop exercise](../Workshop/3-Connectors.md) | [Learning home](./README.md)

## Purpose

This companion provides the conceptual background, connector catalog reference, discussion prompts, screenshot index, and repository maintenance notes for the executable [Connectors workshop exercise](../Workshop/3-Connectors.md).

## What a connector is (and is not)

| Aspect | What it is | What it is not |
| --- | --- | --- |
| **Connectors** | Optional, discrete tool integrations the agent can call to read or write external systems while reasoning about an incident. Telemetry connectors give the agent KQL access to specific workspaces and code connectors give it indexed source. | A replacement for the Azure RBAC the agent already has on the resources attached in Module 2. |
| **Examples in the catalog** | **Telemetry**: Azure Data Explorer, Log Analytics Workspace, Application Insights, Datadog, Elasticsearch, Dynatrace, New Relic, Splunk, Hawkeye. **Code Repository**: GitHub, Azure DevOps. | Anything reachable purely through Azure RBAC; the agent already has that path from Module 2. |
| **Why use one** | The agent can take a closed-loop action: query a specific workspace by name, file a ticket, post to chat, or invoke another named integration while reasoning. | A connector does not bypass the agent's response plan or RBAC. You still control approvals, and the connector uses the agent's managed identity. |

A named connector provides a predictable target, makes the source explicit in chat, reduces ambiguity when several workspaces exist, and gives administrators a discrete integration to edit or remove. It does not grant access by itself: the identity still needs the required role at the target scope.

For the catalog and configuration reference, see [Connectors in Azure SRE Agent](https://go.microsoft.com/fwlink/?linkid=2341945) on Microsoft Learn.

## Wizard and catalog reference

The portal at `https://sre.azure.com` exposes a three-step **Add connector** wizard:

| # | Step name |
| --- | --- |
| 1 | Choose a connector |
| 2 | Set up connector |
| 3 | Review + add |

The footer contains **`Back`**, **`Next`** (disabled until the current step is valid), and **`Cancel`**. The wizard has the same overall shape for every connector tile.

The **Connectors** page initially exposes **`+ Add connector`**, **`↻ Refresh`**, **`Remove`** (disabled until rows are selected), and a **`Category : All`** filter. After connectors are added, it also exposes **`Search`**, **`Expand all`**, and **`Collapse all`**. The GitHub repository connected in Module 2 appears under **`Code Repository (1)`** as `app-service-dotnet-agent-tutorial`.

The **Telemetry** tab currently lists these tiles:

| Tile | What it integrates |
| --- | --- |
| **Azure Data Explorer** | Kusto cluster databases |
| **Log Analytics Workspace** | A specific Log Analytics workspace |
| **Application Insights** | A specific Application Insights resource |
| **Datadog** | Datadog metrics and logs |
| **Elasticsearch** | Elastic stack |
| **Dynatrace** | Dynatrace tenant |
| **New Relic** | New Relic account |
| **Splunk** | Splunk index |
| **Hawkeye** | Hawkeye observability platform |

The tile body may highlight without selecting the tile. If **`Next`** remains disabled, select the small checkbox at the tile's upper-left corner.

## Identity, scope, and lifecycle

The Log Analytics connector authenticates with the agent's system-assigned managed identity by default. Selecting a workspace displays a **Log Analytics Reader role needed** banner, but the connector wizard does not create that role assignment. This differs from Module 2's **Azure resources** flow, which can grant roles inline.

The connector stores the workspace resource ID. If the resource group is deleted and recreated, edit the connector to point at the new workspace. A connector row currently exposes only **Edit connector** and **Delete connector**; there is no **Disable** action. Deleting a connector does not remove RBAC assignments previously granted to its identity.

A temporary shutdown therefore requires a deliberate operational choice: remove or rotate RBAC, repoint the connector to an empty workspace, or delete it and retain its desired configuration in infrastructure as code for later recreation.

## Why the validation prompt is discriminating

The workshop prompt asks the agent to list tables and retrieve recent rows. That forces three observable behaviors:

1. Select the named `log-analytics-demo` connector.
2. Inspect the workspace schema rather than assume table names.
3. Run a parameterized KQL query and return actual records.

A fabricated table list, empty result without schema evidence, or host names that do not match `WEBAPP_NAME` indicates a connector, permission, or target-workspace problem. Matching `AlwaysOn` traffic from the production and staging hosts also confirms that the Module 1 deployment is generating telemetry.

## Discussion prompts

- The agent already had RBAC on `rg-sreinprod-app` from Module 2. **What did adding the Log Analytics Workspace connector provide that the implicit RBAC path did not?** Consider named tools, predictable targeting, prompt clarity, and revocation.
- The wizard reports the required role but does not assign it. **Should connector setup grant roles inline?** Compare explicit security review with one-click setup.
- For each telemetry provider your team operates, **what is the minimum scope its connector should receive?**
- With only **Edit** and **Delete** available, **how would you take a connector offline temporarily without losing its configuration?**

## Full screenshot index

The screenshots were captured against the live portal in June 2026 and live under `images/wizard/` for facilitators who want to build a slide deck.

| # | Screen | File |
| --- | --- | --- |
| 17 | Connectors page (initial: Code Repository only) | [17-connectors-page.png](../images/wizard/17-connectors-page.png) |
| 18 | Add connector, Choose a connector (Telemetry tab, 9 tiles) - embedded | [18-add-connector-dialog.png](../images/wizard/18-add-connector-dialog.png) |
| 19 | Add connector, Log Analytics Workspace selected | [19-log-analytics-selected.png](../images/wizard/19-log-analytics-selected.png) |
| 20 | Set up Log Analytics connector (empty form) | [20-set-up-connector.png](../images/wizard/20-set-up-connector.png) |
| 21 | Set up connector, workspace dropdown open - embedded | [21-workspace-dropdown.png](../images/wizard/21-workspace-dropdown.png) |
| 22 | Review + add - embedded | [22-review-add.png](../images/wizard/22-review-add.png) |
| 23 | Connectors page after Log Analytics added (2 groups) - embedded | [23-connectors-after-log-analytics.png](../images/wizard/23-connectors-after-log-analytics.png) |
| 24 | Connector row context menu (Edit / Delete) | [24-connector-row-menu.png](../images/wizard/24-connector-row-menu.png) |
| 25 | Chat validation: tables and AppServiceHTTPLogs rows - embedded | [25-chat-validate-connector.png](../images/wizard/25-chat-validate-connector.png) |

## Further reading

- [Connectors in Azure SRE Agent](https://go.microsoft.com/fwlink/?linkid=2341945): official catalog and configuration reference.
- [Module 2: Deploy the Agent](../Workshop/2-Deploy-Agent.md): connects the GitHub code repository that appears on the Connectors page.
- [Module 4: Connect Observability](../Workshop/4-Connect-Observability.md): uses the Log Analytics connector from chat during an investigation.
- [Module 5: Response Plans and Guardrails](../Workshop/5-Response-Plans-and-Guardrails.md): governs when the agent may invoke connector tools.

## Notes for repository owners

Re-capture screenshots `17` to `25` if the portal redesigns the **Connectors** page or **Add connector** wizard. The most volatile elements are the tile catalog, because new providers ship regularly, and the row actions, because a **Disable** toggle may be added.

[← Return to the Connectors workshop exercise](../Workshop/3-Connectors.md) | [Learning home](./README.md)
