# Infrastructure

Use this folder if you decide to include a deployable sample app environment.

## Suggested contents
- `main.bicep` for the demo application and observability resources
- parameter files for region / naming / SKU choices
- optional alert rule definitions

## Goal
Create a workload that is realistic enough to demonstrate:
- normal traffic
- telemetry collection
- a safe fault injection path
- fast rollback
