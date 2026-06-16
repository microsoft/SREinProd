# Module 5 - Incident Drill

[← Module 4: Response Plans and Guardrails](./4-Response-Plans-and-Guardrails.md) | [Workshop home](./ReadMe.md) | [Next: Module 6 →](./6-Production-Rollout.md)

## Objective
Run a realistic incident on the demo workload and let the agent investigate and propose remediation.

## Scenario
The sample app ([`Azure-Samples/app-service-dotnet-agent-tutorial`](https://github.com/Azure-Samples/app-service-dotnet-agent-tutorial)) throws an HTTP 500 after 5 `?crash=1` requests in a single session whenever `INJECT_ERROR=1`. The drill flips `INJECT_ERROR=1` on the **production slot** to simulate a bad config change reaching production.

## Lab steps
1. Generate baseline traffic and inject the fault:
   ```powershell
   pwsh ./scripts/demo-warmup.ps1
   ```
   The script resets `INJECT_ERROR=0`, sends ~25 baseline requests, flips `INJECT_ERROR=1`, then drives ~30 `?crash=1` requests across 3 sessions.
2. Wait 3-5 minutes for Application Insights ingestion and the Http5xx metric alert (`alert-sreinprod-demo-http5xx`) to fire.
3. Open the agent and run the investigation prompt:
   ```text
   We are seeing a spike of HTTP 500 errors on our production application.
   Users started reporting issues in the last few minutes.
   Can you investigate the cause of these 500 errors and identify the
   likely root cause?
   ```
4. Walk the participants through the evidence chain the agent presents:
   - Http5xx metric spike on the production slot
   - Exception trace in App Insights (`Simulated error after 5 button clicks!`)
   - Recent app-setting change: `INJECT_ERROR` 0 -> 1
5. Approve or discuss remediation (set `INJECT_ERROR=0` or swap the slots back).
6. Validate recovery: re-run `pwsh ./scripts/smoke-test.ps1` and confirm the production slot returns 200.
7. Capture the incident summary the agent produced.
8. Reset for the next run:
   ```powershell
   pwsh ./scripts/demo-rollback.ps1
   ```

## Success criteria
- Participants see the Http5xx spike and the exception trace appear in telemetry.
- The agent identifies the `INJECT_ERROR` change as the likely root cause.
- A safe remediation is proposed (and optionally executed under approval).
- The environment is restored after the exercise.

