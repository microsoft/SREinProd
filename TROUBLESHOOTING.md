# Troubleshooting

## Common issues

### Agent cannot see the workload
- Verify the monitored resource group is attached to the agent.
- Verify the agent identity has the required RBAC assignments.

### No telemetry appears during the workshop
- Confirm Application Insights / Log Analytics is enabled.
- Wait long enough for new requests and exceptions to appear.
- Confirm the sample app is writing telemetry.

### Fault injection does not trigger the expected incident
- Validate the app setting or slot swap completed successfully.
- Re-run the warmup / traffic generation script.
- Confirm alert thresholds match the expected request/error volume.

### Remediation suggestion is incomplete
- Check whether the agent has enough context (code repo, docs, runbooks, observability).
- Review whether the response plan includes safe remediation guidance.
