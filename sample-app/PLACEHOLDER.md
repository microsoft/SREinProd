# sample-app/ (placeholder)

The contents of this folder are **cloned on demand** by
[`scripts/clone-sample-app.ps1`](../scripts/clone-sample-app.ps1) from
[`Azure-Samples/app-service-dotnet-agent-tutorial`](https://github.com/Azure-Samples/app-service-dotnet-agent-tutorial).

That repository is licensed MIT by Microsoft `Azure-Samples` and is not
vendored here. The clone happens automatically as part of:

- `pwsh ./scripts/deploy-demo-env.ps1`
- `azd up` (via the `preprovision` hook in [`azure.yaml`](../azure.yaml))

If you want to pre-populate the folder yourself:

```powershell
pwsh ./scripts/clone-sample-app.ps1
```

After cloning, this directory will contain the .NET 9 `SreAgentMemoryDemo`
project (`Program.cs`, `SreAgentMemoryDemo.csproj`, etc.). Those files are
gitignored on purpose so the workshop always exercises the latest upstream
code; only this `PLACEHOLDER.md` is checked in.
