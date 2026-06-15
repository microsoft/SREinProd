# Module 2 - Deploy the Agent

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
2. **Verify your role**. You need `Owner` *or* `User Access Administrator` on the subscription. The wizard creates a system-assigned managed identity for the agent and then assigns RBAC roles on the monitored resource groups on your behalf — only those two roles can grant role assignments.
3. **Allow outbound traffic to `*.azuresre.ai`**. The agent's hosted runtime calls back to that endpoint. If you're behind a corporate firewall, get it allow-listed before you continue, otherwise the chat UI will load but the agent will fail to respond.

## Lab steps

### Step 1 — Create the agent resource group
**What:** create an empty resource group that will hold *only* the agent and its automatically-provisioned dependencies (Application Insights, Log Analytics, Managed Identity).

**Why:** keeping the agent in its own RG (`rg-sreinprod-agent`) separates the *observer* from the *observed* (`rg-sreinprod-app`). It means you can delete or redeploy the demo workload without disturbing the agent, and the agent's own telemetry never gets mixed up with the workload's telemetry.

```powershell
az group create --name rg-sreinprod-agent --location eastus2
```

> The agent is only available in **Sweden Central**, **East US 2**, and **Australia East**. We use `eastus2` for the workshop. Pick the same region you used for `rg-sreinprod-app` to keep latency and data-residency simple.

### Step 2 — Open the SRE Agent portal and start the wizard
1. Browse to <https://aka.ms/sreagent> (it redirects to `https://sre.azure.com`).
2. Sign in with the same identity that owns the demo subscription.
3. On the agent list page, select **+ Create agent** in the top toolbar.

**What:** this launches a tree-pane wizard (**Basics → Review → Deploy**) that ultimately deploys an `Microsoft.App/SREAgents` resource plus its supporting Application Insights, Log Analytics workspace, and managed identity into the resource group you pick.

**Why:** doing this in the portal (instead of `az` or Bicep) is intentional for the workshop — the wizard is the easiest way to see exactly which roles and dependencies the agent needs, and it leaves a clean Activity Log entry attendees can inspect afterwards.

### Step 3 — Fill in the **Basics** pane
Use these exact values so later modules' screenshots and scripts line up:

| Field | Value | Why this value |
|---|---|---|
| **Subscription** | Same subscription where you deployed Module 1 | The agent must live in the same tenant as the resources it monitors. |
| **Resource group** | `rg-sreinprod-agent` | The empty RG you created in Step 1 — isolates the agent from the workload. |
| **Agent name** | `sreagent-sreinprod` | Lowercase, hyphenated; must be unique within the RG. Used later in URLs and CLI commands. |
| **Region** | `East US 2` | One of the three supported regions; matches the workload region. |
| **Application Insights** | **Create new** (accept the default name) | The agent uses its *own* App Insights for self-telemetry — this is **not** the App Insights that monitors your web app. Creating a fresh one keeps the two telemetry streams isolated. |

Click **Next: Managed resources**.

### Step 4 — Attach the workload on the **Managed resources** pane
1. Click **+ Add managed resources**.
2. In the picker, filter to the demo subscription and tick the box next to **`rg-sreinprod-app`**.
3. Confirm the selection — only one RG should be listed.
4. Click **Next: Permissions**.

**What:** "managed resources" tells the agent which slice of Azure it is allowed to look at. We attach the application RG (created by `infra/main.bicep`), which contains:
- the App Service plan,
- the web app + the `staging` slot,
- the Log Analytics workspace + Application Insights instance that receive the app's telemetry,
- the `Http5xx` metric alert that fires the incident in Module 5.

**Why one RG (not the whole subscription):** the agent should only see resources relevant to this workload. This is a least-privilege boundary — if a teammate later spins up unrelated resources in another RG, the agent won't touch them. You can always widen the scope from **Settings → Managed resources** afterwards.

### Step 5 — Choose the **Permissions** level
Select **Reader (recommended)**. The wizard shows the exact RBAC roles it is about to assign to the agent's managed identity on `rg-sreinprod-app`:
- **Reader** — see resources and configuration
- **Log Analytics Reader** — query the workspace
- **Monitoring Reader** — read metrics and alerts
- (plus service-specific reader roles like *AKS Cluster User* for any services it detects)

Click **Next: Review + create**.

**What:** this is the *blast radius* control. `Reader` mode means the agent can investigate, summarise, and propose fixes, but **every write action requires your approval in chat** — perfect for Modules 3–5 where we want to *see* the agent reason about the failure before anything changes.

**Why not Privileged:** `Privileged` lets the agent execute approved runbooks automatically without an approval prompt. We deliberately keep that off for the workshop so attendees can watch the human-in-the-loop flow. You'll see in Module 4 how to selectively grant write permission for a single remediation (e.g. flipping `INJECT_ERROR` back to `0`) instead of escalating the whole agent.

### Step 6 — Review and deploy
1. Confirm the summary matches the table in Step 3 and that `rg-sreinprod-app` appears under monitored resources.
2. Click **Create**.
3. Deployment usually takes 2–4 minutes. The portal will show progress as it provisions:
   - the SRE Agent resource,
   - a managed identity,
   - an Application Insights instance + Log Analytics workspace (for agent self-telemetry),
   - the role assignments on `rg-sreinprod-app`.
4. When the banner reads **Deployment succeeded**, click **Chat with agent**.

**What / why:** the wizard is doing the same thing you would otherwise do with `az role assignment create` three times — it just batches everything into a single ARM deployment so you can see it succeed (or fail) atomically. If you ever need to reproduce this with IaC, inspect the deployment in `rg-sreinprod-agent → Deployments` to grab the generated template.

### Step 7 — (Optional, for Module 5) Grant write access for the remediation step
By default the agent is read-only. If you want it to actually flip `INJECT_ERROR` back to `0` during the Module 5 incident drill (instead of just *telling* you to do it), add one extra role assignment **scoped to the web app only**, not the whole RG:

```powershell
# Replace <suffix> and <subId> with your values from scripts/env.conf and `az account show`
$webAppId = az webapp show `
  --resource-group rg-sreinprod-app `
  --name app-sreinprod-demo-<suffix> `
  --query id -o tsv

$agentMiId = az resource show `
  --resource-group rg-sreinprod-agent `
  --name sreagent-sreinprod `
  --resource-type "Microsoft.App/SREAgents" `
  --query "identity.principalId" -o tsv

az role assignment create `
  --assignee-object-id $agentMiId `
  --assignee-principal-type ServicePrincipal `
  --role "Website Contributor" `
  --scope $webAppId
```

**What:** grants the agent's managed identity `Website Contributor` on **just the web app** (not the App Service plan, not the slot, not Application Insights).

**Why narrow scope:** `Website Contributor` at RG scope would let the agent recreate or delete *any* site in the RG. Scoping to a single web app limits the agent's reach to settings, slots, and restarts on that one resource — which is exactly what Module 5 needs and nothing more.

### Step 8 — Smoke-test the connection
In the agent chat pane, ask:

```
What App Services do you see in rg-sreinprod-app, and which alert rules are configured on them?
```

You should get back:
- the demo web app (`app-sreinprod-demo-<suffix>`) and its `staging` slot,
- the `Http5xx` metric alert defined in `infra/main.bicep`.

**Why this prompt:** it exercises three of the agent's read paths in one shot — ARM resource enumeration, App Service slot awareness, and Azure Monitor alert rules. If any of them comes back empty, the agent doesn't have the role you think it does and you need to recheck Step 5 before continuing to Module 3.

## Validation checklist
- [ ] `Microsoft.App` provider is `Registered` on the subscription.
- [ ] Agent resource (`sreagent-sreinprod`) exists in `rg-sreinprod-agent`.
- [ ] `rg-sreinprod-app` shows up under the agent's **Managed resources**.
- [ ] The agent has a system-assigned managed identity (visible under **Settings → Basics**).
- [ ] `Reader`, `Log Analytics Reader`, and `Monitoring Reader` role assignments exist on `rg-sreinprod-app` for that managed identity.
- [ ] (Optional) `Website Contributor` is assigned **on the web app resource only** if you plan to demo automated remediation in Module 5.
- [ ] The agent's smoke-test reply names the demo web app, its `staging` slot, and the `Http5xx` alert.

## Notes for repo owners
Add screenshots and tenant-specific instructions here if you want a polished event-ready guide.

