# Module 2 Learning - Deploy the Agent

[← Back to the Deploy the Agent workshop exercise](../Workshop/2-Deploy-Agent.md) | [Learning home](./README.md)

## Purpose

This companion provides the conceptual background, read-only roadmap, facilitator reference, and repository maintenance notes for the executable [Deploy the Agent workshop exercise](../Workshop/2-Deploy-Agent.md).

## Deployment mental model

The portal at `https://sre.azure.com` presents two flows back-to-back:

1. A **3-pane Create-agent wizard** (`Basics`, `Review`, `Deploy`) provisions the agent resource itself.
2. A **Set up your agent page** opens immediately after deployment with four data-source cards (`Code`, `Logs`, `Azure resources`, `Incidents`). Each card opens its own mini-wizard.

Creating the agent also provisions its identity and self-observability dependencies. Connecting Azure resources is a separate operation because it defines what the agent can see and what it can change through Azure RBAC. Connecting code adds repository context for root-cause analysis but does not expand the agent's Azure permissions.

## Read-only roadmap

> **This section is a preview, not the lab.** Use it to understand the flow, then return to the [workshop exercise](../Workshop/2-Deploy-Agent.md) and execute the detailed steps. Every action here appears there with its task-critical context and validation.

The full lab is 9 steps:

1. **Step 1:** Run `az group create --name rg-sreinprod-agent --location eastus2`.
2. **Step 2:** Open <https://aka.ms/sreagent>, sign in, click **`Create agent`**.
3. **Step 3:** Fill the **Basics** pane with the workshop values, click **`Next`**.
4. **Step 4:** Verify the **Review** pane, click **`Create`**.
5. **Step 5:** Wait ~2-4 min for deployment, click **`Set up your agent`**.
6. **Step 6:** Inspect the four data-source cards (no action; orientation only).
7. **Step 7:** On the **Azure resources** card, click **`Add resources`** -> **Choose resource groups** -> tick `rg-sreinprod-app` -> **Privileged** -> **`Add resource group`**.
8. **Step 8:** On the **Code** card, click **`Connect repositories`** -> **GitHub** -> **Your account** -> add the `app-service-dotnet-agent-tutorial` URL -> **`Save`**.
9. **Step 9:** Click **`Done and go to agent`**, then run the two smoke-test prompts in chat.

## Why the agent uses a separate resource group

The workshop creates an empty resource group that holds *only* the agent and its automatically provisioned dependencies: Managed Identity, Application Insights, Log Analytics workspace, and the `Microsoft.App/SREAgents` resource itself.

Keeping the agent in its own resource group (`rg-sreinprod-agent`) separates the *observer* from the *observed* (`rg-sreinprod-app`). You can delete or redeploy the demo workload without disturbing the agent, and the agent's own telemetry never gets mixed with the workload's telemetry.

The agent is available only in **Sweden Central**, **East US 2**, and **Australia East**. The workshop uses `eastus2`. Pick a location close to the workshop resource group (`rg-sreinprod-app` by default) to keep latency and data residency simple.

## Why the workshop uses the portal

The wizard is the easiest way to see exactly which roles and dependencies the agent needs. It also leaves a clean ARM deployment under `rg-sreinprod-agent`, **Deployments**, which can be inspected later when reproducing the setup with infrastructure as code.

The wizard creates a system-assigned managed identity for the agent and assigns RBAC roles on monitored resource groups on your behalf. The creator therefore needs `Owner` or `User Access Administrator` on the subscription. The `Microsoft.App` provider must also be registered because SRE Agent runs on the Azure Container Apps control plane.

## Provisioned resources

A normal deployment reports seven successful operations in this order:

| # | Resource | Type | What it is |
| --- | --- | --- | --- |
| 1 | `rg-sreinprod-agent-roleAssignments-…` | Nested deployment | Grants the agent's own managed identity the roles it needs on its sibling resources. |
| 2 | `sreagent-sreinprod-<suffix>` | **Managed Identity** | User-assigned identity that the agent runs as. |
| 3 | `workspace<suffix>` | **Log Analytics Workspace** | Stores the agent's *own* operational logs. |
| 4 | `sreagent-sreinprod-<suffix>-app-insights` | **Application Insights** | Captures the agent's *own* traces/metrics. |
| 5 | `sreagent-sreinprod` | **Azure SRE Agent** (`Microsoft.App/SREAgents`) | The agent resource itself. |
| 6 | `UserRoleAssignment-…` | Nested deployment | Grants **you** (the creator) administrative access on the new agent so you can chat with it. |
| 7 | *"Warming up your agent"* | **Agent Site** | Spins up the hosted chat backend at `*.azuresre.ai`. |

The agent's Application Insights and Log Analytics resources monitor the agent itself. They are distinct from the Application Insights instance and workspace that monitor the demo application.

## Permission model

The setup flow offers two permission levels on the selected workload resource group:

| Permission level | Roles assigned on `rg-sreinprod-app` | Use it when… |
| --- | --- | --- |
| **Reader** *(default)* | `Reader`, `Monitoring Reader`, `Log Analytics Reader` (3 roles) | You want the agent to *propose* every action and have a human approve in chat. Safest. |
| **Privileged** | All Reader roles, plus `Log Analytics Contributor`, `Application Insights Component Contributor`, `Website Contributor`, `Web Plan Contributor` (7 roles) | You want the agent to execute approved remediations end-to-end. Required for Module 6's *"flip `INJECT_ERROR` back to 0"* drill. |

`Website Contributor` and `Web Plan Contributor` let the agent change app settings, swap slots, and restart the app. The workshop grants these roles at the single workload resource-group scope, so the agent cannot touch `rg-sreinprod-agent` or unrelated resource groups.

The portal's Privileged mode is resource-group scoped and atomic. It has no per-resource scope control. A stricter production design can select Reader and manually assign a narrower role with `az role assignment create --scope <webAppId>`.

## Data-source choices

The **Set up your agent** page presents four cards:

| Card | Purpose in this workshop |
| --- | --- |
| **Code** *(Recommended, "Best with Logs")* | Maps exception stack traces to source. Used by the *"why is this app throwing 500s?"* path in Module 6. |
| **Logs** *(Recommended, "Best with code")* | Connects external log providers such as Datadog or Grafana. Azure telemetry is already available through the resource RBAC path, so the workshop skips this card. |
| **Azure resources** | Attaches `rg-sreinprod-app` and assigns the selected RBAC roles. Required for the workshop. |
| **Incidents** | Connects ServiceNow, PagerDuty, or Azure Monitor Alerts as incident sources. Module 5 covers alerts. |

The workshop connects **Azure resources** and **Code**. The Azure resources connection is the authorization path; the code connection is additional investigation context.

## Model-provider consideration

The workshop uses **Anthropic (3x) Preferred**, the wizard default, because Microsoft tunes it for SRE workflows. `(3x)` and `(1x)` are billing-rate multipliers: Anthropic costs 3x per token compared with Azure OpenAI.

**Anthropic processes data in the United States and is excluded from the European Union Data Boundary (EUDB).** A tenant that requires EUDB should select **Azure OpenAI (1x)** instead.

## Full screenshot index

The screenshots embedded in the workshop capture the moments where the UI diverges most from older docs. The full set of wizard screens was captured against the live portal in June 2026 and lives under `images/wizard/` for facilitators building a slide deck:

| # | Screen | File |
| --- | --- | --- |
| 1 | Agent list (empty state) | [01-after-signin.png](../images/wizard/01-after-signin.png) |
| 2 | Create wizard, Basics (blank) | [02-wizard-pane-1.png](../images/wizard/02-wizard-pane-1.png) |
| 3 | Create wizard, Basics (filled, Model provider visible) - embedded | [03-basics-filled.png](../images/wizard/03-basics-filled.png) |
| 4 | Create wizard, Review | [04-review-pane.png](../images/wizard/04-review-pane.png) |
| 5 | Create wizard, Deploy in progress | [05-deploy-pane.png](../images/wizard/05-deploy-pane.png) |
| 6 | Create wizard, Deploy succeeded | [06-deploy-complete.png](../images/wizard/06-deploy-complete.png) |
| 7 | Set up your agent (initial state) | [07-setup-your-agent.png](../images/wizard/07-setup-your-agent.png) |
| 8 | Add Azure resources, choose type | [08-add-resources.png](../images/wizard/08-add-resources.png) |
| 9 | Add resource groups, picker | [09-choose-subscriptions.png](../images/wizard/09-choose-subscriptions.png) |
| 10 | View agent permissions, Reader (3 roles) | [10-view-agent-permissions.png](../images/wizard/10-view-agent-permissions.png) |
| 10b | View agent permissions, Privileged (7 roles) - embedded | [10b-permissions-privileged.png](../images/wizard/10b-permissions-privileged.png) |
| 11 | Set up your agent, Azure resources connected - embedded | [11-after-azure-resources-added.png](../images/wizard/11-after-azure-resources-added.png) |
| 12 | Add repositories, Choose a platform | [12-connect-repositories.png](../images/wizard/12-connect-repositories.png) |
| 13 | Add repositories, Authenticate | [13-github-authenticate.png](../images/wizard/13-github-authenticate.png) |
| 14 | Add repositories, Authenticate (PAT validated) | [14-add-repositories.png](../images/wizard/14-add-repositories.png) |
| 15 | Add repositories, URL grid | [15-add-repositories-picker.png](../images/wizard/15-add-repositories-picker.png) |
| 16 | Set up your agent, Code + Azure resources connected | [16-after-code-added.png](../images/wizard/16-after-code-added.png) |

## Notes for repository owners

Re-capture the wizard screens if the portal changes meaningfully; the agent wizard has been iterating quickly. Add tenant-specific instructions here when preparing a polished event-ready guide.

[← Return to the Deploy the Agent workshop exercise](../Workshop/2-Deploy-Agent.md) | [Learning home](./README.md)
