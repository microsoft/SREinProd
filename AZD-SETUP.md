# AZD Setup (proposed)

This file is a starter for an Azure Developer CLI-based deployment path.

## Goals
- provision a demo application environment
- enable observability
- prepare a target workload for Azure SRE Agent

## Suggested flow
1. Log in to Azure.
2. Create an azd environment.
3. Provision infrastructure.
4. Deploy the demo app.
5. Validate telemetry before the workshop.

## Placeholder commands
```bash
azd auth login
azd init
azd env new sreinprod
azd provision
azd deploy
```

## Add later
- supported regions
- quota requirements
- expected deployment time
- post-provision validation steps
