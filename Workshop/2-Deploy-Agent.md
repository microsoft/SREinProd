# Module 2 - Deploy the Agent

[← Module 1: Foundation](./1-Foundation.md) | [Workshop home](./ReadMe.md) | [Next: Module 3 →](./3-Connectors.md)

[Learning companion: deployment concepts, roadmap, and reference](../Learning/2-Deploy-Agent.md)

## Objective

Deploy a working Azure SRE Agent and attach it to the workshop demo workload.

## Prerequisites

The workshop environment must already be deployed (`scripts/deploy-demo-env.ps1` or `azd up`). After that, `scripts/env.conf` should contain:

```text
APP_RESOURCE_GROUP=rg-sreinprod-app
AGENT_RESOURCE_GROUP=rg-sreinprod-agent
APP_NAME=app-sreinprod-demo-<suffix>
APP_INSIGHTS_NAME=appi-sreinprod-demo-<suffix>
LOG_ANALYTICS_WORKSPACE=log-sreinprod-demo-<suffix>
```

## Before you start the wizard

Confirm three platform-level prerequisites. If any of these are missing the **Create** button in the portal will be disabled or the deployment will fail with `DeploymentNotFound`.

1. **Register the `Microsoft.App` resource provider** on the subscription that will host the agent. SRE Agent runs on the Azure Container Apps control plane, so the provider must be registered before the wizard can deploy backing resources.

    ```powershell
    az provider register --namespace "Microsoft.App"
    az provider show --namespace "Microsoft.App" --query "registrationState" -o tsv
    ```

    Wait until the state reads `Registered`.

2. **Verify your role**. You need `Owner` *or* `User Access Administrator` on the subscription. The wizard creates a system-assigned managed identity for the agent and then assigns RBAC roles on the monitored resource groups on your behalf. Only those two roles can grant role assignments.

3. **Allow outbound traffic to `*.azuresre.ai`**. The agent's hosted runtime calls back to that endpoint. If you're behind a corporate firewall, get it allow-listed before you continue, otherwise the chat UI will load but the agent will fail to respond.

## Lab steps

Complete the steps in order. The workshop creates the agent, connects **Azure resources** and **Code**, and skips **Logs** and **Incidents**.

### Step 1: Create the agent resource group

> **Action:** Run:
>
> ```powershell
> az group create --name rg-sreinprod-agent --location eastus2
> ```

> The agent is available only in **Sweden Central**, **East US 2**, and **Australia East**. This workshop uses `eastus2`.

### Step 2: Open the SRE Agent portal and start the wizard

> **Action:**
>
> 1. Browse to <https://aka.ms/sreagent> (redirects to `https://sre.azure.com`).
> 2. Sign in with the identity that owns the demo subscription.
> 3. On the **Agents** list page, click **`Create agent`** (the empty-state primary button, or **`+ Create agent`** on the top toolbar).

This opens a 3-step dialog titled **Create agent** with header tabs **`1 Basics`**, **`2 Review`**, **`3 Deploy`**.

### Step 3: Fill in the **Basics** pane

Use these exact values so later modules and scripts line up.

![Basics pane with Model provider radio group visible](../images/wizard/03-basics-filled.png)

| Field | Value |
| --- | --- |
| **Subscription** | Same subscription where you deployed Module 1 |
| **Resource group** | Select **Select an existing resource group**, then choose `rg-sreinprod-agent` |
| **Agent name** *(required)* | `sreagent-sreinprod` |
| **Region** *(required)* | `East US 2` |
| **Model provider** *(required)* | **Anthropic (3x) Preferred** *(default)* |
| **Application Insights** | **Create new** *(default; this is separate from the demo app's Application Insights)* |

> ⚠️ **EUDB requirement:** Anthropic processes data in the United States and is excluded from the European Union Data Boundary (EUDB). If the workshop tenant requires EUDB, select **Azure OpenAI (1x)** instead.

> ⚠️ **Model provider didn't appear at first.** The radio group only renders once a subscription is selected. If you don't see it, finish picking the Subscription and it will materialise.

> **Action:** Click **`Next`**.

### Step 4: Confirm the **Review** pane

The Review pane echoes back **only four fields**: Agent name, Region, Subscription, Resource group.

> 🔍 **Important:** the Review pane does **not** show your Model provider or Application Insights choice. If you're unsure, click **Back** and double-check the Basics pane *before* clicking Create. Those values cannot be changed after deployment.

> **Action:** Click **`Create`**.

### Step 5: Watch the **Deploy** pane

Deployment typically takes 2 to 4 minutes. Wait while the **Resource operations** list streams progress; Close and Cancel remain disabled during deployment. Continue only when the banner reads **"Deployment succeeded"** and the **`Set up your agent`** button is enabled.

> **Action:** Click **`Set up your agent`**.

### Step 6: Connect the workshop data sources

You're now on the agent's overview page (URL: `https://sre.azure.com/agents/subscriptions/<subId>/resourceGroups/rg-sreinprod-agent/providers/Microsoft.App/agents/sreagent-sreinprod`).

![Set up your agent page with four data-source cards](../images/wizard/11-after-azure-resources-added.png)

Connect **Azure resources** in Step 7 and **Code** in Step 8. Skip the **Logs** and **Incidents** cards for this workshop.

### Step 7: Connect **Azure resources** (required)

> **Action:** On the **Azure resources** card, click **`Add resources`**. The **Add Azure resources** dialog opens with its own two-step header (`1 Choose subscriptions`, `2 Choose resource type`).

**Sub-step 7a, Choose resource type.** Select **`Choose resource groups`** (least-privilege; the alternative `Choose subscriptions` would give the agent visibility into *every* RG in the sub).

> **Action:** Click **`Next`**.

**Sub-step 7b, Select resource groups.** The dialog header changes to **`Add resource groups`** with steps `1 Select resource groups`, `2 View agent permissions`.

> ℹ️ The dialog shows a banner: *"Only resources where you have the Owner or User Access Administrator role are listed. These roles are required to grant the agent access."* If the RG you created when you started this workshop isn't visible, the missing permission is *yours*, not the agent's.

> **Action:**
>
> 1. Narrow the **Subscription** filter to the one that holds the workshop RG.
> 2. Tick the box next to the workshop RG (use the search box if needed).
> 3. Confirm the counter reads **`1 selected`**, then click **`Next`**.

**Sub-step 7c, View agent permissions.** Select the Privileged permission for the agent. The role list on the page changes based on your choice:

![Permission level: Privileged shows all seven roles the agent receives](../images/wizard/10b-permissions-privileged.png)

| Permission level | Roles assigned on `rg-sreinprod-app` |
| --- | --- |
| **Reader** *(default)* | `Reader`, `Monitoring Reader`, `Log Analytics Reader` (3 roles) |
| **Privileged** *(required for this workshop)* | `Reader`, `Monitoring Reader`, `Log Analytics Reader`, `Log Analytics Contributor`, `Application Insights Component Contributor`, `Website Contributor`, `Web Plan Contributor` (7 roles) |

> ⚠️ **Scope:** Privileged grants remediation access at the single resource-group scope and is required for Module 6. In production, select **Reader** and, if needed, assign a narrower role manually with `az role assignment create --scope <webAppId>`.

The page shows the role table with status chips (**Already granted (0)** / **Needs assignment (7)**) and a confirmation strip: *"Required permissions will be granted automatically when you add resources."*

> **Action:** Click **`Add resource group`** to commit.

Back on the *Set up your agent* page the **Azure resources** card now reads **"1 resource group added"** with `Add more` and `Show details` actions.

### Step 8: Connect **Code** (recommended)

> **Action:** On the **Code** card, click **`Connect repositories`**. The **Add repositories** dialog has three steps: `1 Choose a platform`, `2 Authenticate`, `3 Add repositories`.

**Sub-step 8a, Choose a platform.**

| Field | Value |
| --- | --- |
| **Platform** | **GitHub** (alternative: **Azure DevOps**) |
| **GitHub host\*** | `github.com` (use `<tenant>.ghe.com` for GitHub Enterprise Cloud; GitHub Enterprise *Server* is not supported) |

> **Action:** Click **`Next`**.

**Sub-step 8b, Authenticate.** Use **Your account** (OAuth) for the workshop. If OAuth is blocked, use a fine-grained **PAT** with read-only contents access to the repository. **Bring your own GitHub App** is the production option for team-owned access.

> **Action:** Click **`Sign in to GitHub`** and complete the OAuth grant **in the same browser window**. When the panel updates to show **Connected as `<your-handle>`** ✅, click **`Next`**.

> 🐞 **Known gotcha: "Invalid state / OAuth state rejected".** If the GitHub redirect comes back to a different browser session than the one that started it, you'll see `{"error":"Invalid state","message":"OAuth state rejected."}`. Cause: the OAuth popup opened (or was completed) in a *different* browser or profile than the SRE Agent tab, so the anti-CSRF state cookie can't be matched. Fix: cancel the dialog, click **`Connect repositories`** again, and ensure the GitHub sign-in completes **in the same browser session**. If it still fails (corporate browser policies, third-party-cookie blockers, etc.), switch to **PAT** on the same Authenticate step. It bypasses the OAuth handshake entirely.

**Sub-step 8c, Add repositories.** This is **not a list picker**; it's a manual URL grid. Fill out the first row to add our sample repo:

| Column | Value for this workshop |
| --- | --- |
| **Repository URL\*** | `https://github.com/Azure-Samples/app-service-dotnet-agent-tutorial` |
| **Display name\*** | `app-service-dotnet-agent-tutorial` |
| **Description** | `Sample .NET app` |

> Add another row for your IaC repo (e.g. your forked `SREinProd` repo) if you want the agent to also understand `infra/main.bicep`. Not required for Module 2.

> **Action:** Click **`Save`**.

The **Code** card now reads **"1 repository"** ✅.

### Step 9: Smoke-test the agent

> **Action:** Click **`Done and go to agent`** in the *Set up your agent* page footer (or use the breadcrumb to open the agent's chat view). In the chat pane, ask:

```text
What App Services do you see in <your workshop RG>, and which alert rules are configured on them?
```

You should get back:

- the demo web app (`app-sreinprod-demo-<suffix>`),
- the `Http5xx` metric alert defined in `infra/main.bicep`.

If either result is missing, RBAC may not have propagated; recheck Step 7c before continuing to Module 4.

Then optionally ask:

```text
What does the Program.cs in app-service-dotnet-agent-tutorial do?
```

A correct answer (mentions the controllers, the `INJECT_ERROR` feature flag, etc.) confirms the GitHub indexing from Step 8 is live.

## Validation checklist

- [ ] `Microsoft.App` provider is `Registered` on the subscription.
- [ ] Agent resource (`sreagent-sreinprod`) exists in `rg-sreinprod-agent`, along with a sibling managed identity, Log Analytics workspace, and Application Insights instance.
- [ ] You can open the agent at `https://sre.azure.com`.
- [ ] On the *Set up your agent* page the **Azure resources** card reads **"1 resource group added"** (= `rg-sreinprod-app`).
- [ ] The agent's managed identity holds the **7 Privileged-mode roles** on `rg-sreinprod-app` (`Reader`, `Monitoring Reader`, `Log Analytics Reader`, `Log Analytics Contributor`, `Application Insights Component Contributor`, `Website Contributor`, `Web Plan Contributor`). Verify with:

    ```powershell
    $miId = az resource show `
      --resource-group rg-sreinprod-agent `
      --name sreagent-sreinprod `
      --resource-type "Microsoft.App/SREAgents" `
      --query "identity.principalId" -o tsv
    az role assignment list `
      --assignee $miId `
      --resource-group rg-sreinprod-app `
      --query "[].roleDefinitionName" -o tsv
    ```

- [ ] The **Code** card reads **"1 repository"** (= your fork of `app-service-dotnet-agent-tutorial`).
- [ ] The agent's smoke-test reply names the demo web app, its `staging` slot, and the `Http5xx` alert.
- [ ] (Optional) The agent can also summarise `Program.cs` from the indexed repo.

[Read the deployment concepts, roadmap, and full screenshot reference →](../Learning/2-Deploy-Agent.md)

[← Module 1: Foundation](./1-Foundation.md) | [Workshop home](./ReadMe.md) | [Next: Module 3 →](./3-Connectors.md)
