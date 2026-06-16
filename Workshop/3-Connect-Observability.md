# Module 3 - Connect Observability

[← Module 2: Deploy the Agent](./2-Deploy-Agent.md) | [Workshop home](./ReadMe.md) | [Next: Module 4 →](./4-Response-Plans-and-Guardrails.md)

## Objective
Connect the agent to the signal sources it needs to investigate incidents on the demo workload.

## What is already wired by `infra/main.bicep`
- **Application Insights** (`APP_INSIGHTS_NAME` in `scripts/env.conf`) - workspace-based, ingesting request, exception, and dependency traces from both slots of the demo app.
- **Log Analytics workspace** (`LOG_ANALYTICS_WORKSPACE`) - receiving `AppServiceHTTPLogs`, `AppServiceConsoleLogs`, `AppServiceAppLogs`, platform logs, and metrics.
- **Http5xx metric alert** - fires when the production slot emits >=5 HTTP 5xx responses in 5 minutes.

The SRE Agent only needs to be pointed at these resources.

## Lab steps
1. In the SRE Agent portal, open the agent created in Module 2.
2. Verify Application Insights is connected - look for `appi-sreinprod-demo-*` under the agent's data sources.
3. Verify Azure Monitor / alert rules are discoverable - look for `alert-sreinprod-demo-http5xx`.
4. (Optional) Connect a GitHub or Azure DevOps repository so the agent can correlate the error spike with recent commits.
5. (Optional) Connect an incident system (ServiceNow, PagerDuty, etc.) so the agent can hand off summaries.
6. Validate the connection - ask the agent a question that requires the telemetry it just got:
   - "How many requests has `app-sreinprod-demo-*` served in the last hour?"
   - "Are there any exceptions in `app-sreinprod-demo-*` in the last 24 hours?"

## Example participant prompts
- What changed recently in this application?
- Are there exceptions correlated with failed requests on the production slot?
- Which app settings differ between the production slot and the staging slot?

