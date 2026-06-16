# Module 4 - Response Plans and Guardrails

[← Module 3: Connect Observability](./3-Connect-Observability.md) | [Workshop home](./ReadMe.md) | [Next: Module 5 →](./5-Incident-Drill.md)

## Objective
Define how the agent should respond when it encounters a real issue.

## Suggested lab steps
1. Create a new response plan.
2. Start in review mode.
3. Add explicit instructions for investigation order.
4. Add explicit limits on what the agent may change.
5. Add approval expectations and escalation rules.

## Example response plan starter
```text
If HTTP 500 errors increase significantly:
1. Inspect recent deployments and configuration changes.
2. Check dependency health and exceptions.
3. Propose the least disruptive remediation first.
4. Do not make production changes without approval.
5. Include a timeline and stakeholder-ready summary.
```
