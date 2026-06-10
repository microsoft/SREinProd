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

## Lab steps
1. Create the agent resource group (the workload already lives in its own RG):
   ```powershell
   az group create --name rg-sreinprod-agent --location eastus2
   ```
2. In the [Azure SRE Agent portal](https://aka.ms/sreagent), create a new agent in `rg-sreinprod-agent`.
3. **Attach** the application resource group (`rg-sreinprod-app`) as a monitored scope. This is the resource group created by `infra/main.bicep` and contains:
   - the App Service plan,
   - the web app + staging slot,
   - Log Analytics + Application Insights,
   - the Http5xx metric alert.
4. Confirm the agent's system-assigned managed identity exists.
5. Assign RBAC so the agent can read telemetry and (optionally) apply guarded remediations:
   - `Reader` on `rg-sreinprod-app` (minimum)
   - `Monitoring Reader` on the subscription or `rg-sreinprod-app`
   - `Website Contributor` on the web app **if** you want the agent to be able to flip `INJECT_ERROR` back to `0` during Module 5 with approval
6. Ask the agent a basic context question (e.g. "What App Services do you see in `rg-sreinprod-app`?") and confirm it returns the demo app.

## Validation checklist
- [ ] Agent resource exists in `rg-sreinprod-agent`.
- [ ] `rg-sreinprod-app` is attached to the agent.
- [ ] Required RBAC is assigned to the agent identity.
- [ ] The agent can name the demo web app and its slot.

## Notes for repo owners
Add screenshots and tenant-specific instructions here if you want a polished event-ready guide.

