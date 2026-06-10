# PowerShell Setup (proposed)

Use this path if you want presenters or lab runners to understand the environment build in smaller steps.

## Suggested sequence
1. Create resource group
2. Deploy demo app resources
3. Enable Application Insights / Log Analytics
4. Configure alert rules
5. Validate the app before adding SRE Agent

## Recommended script split
- `deploy-demo-env.ps1` – create environment
- `smoke-test.ps1` – verify baseline health
- `demo-warmup.ps1` – generate baseline traffic and inject fault
- `demo-rollback.ps1` – restore environment after the run
