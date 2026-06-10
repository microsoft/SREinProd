param(
    [string]$AppName = "<APP_NAME>",
    [string]$ResourceGroup = "<APP_RESOURCE_GROUP>",
    [string]$AppUrl = "<APP_URL>"
)

Write-Host "Resetting app to baseline..." -ForegroundColor Cyan
az webapp config appsettings set --name $AppName --resource-group $ResourceGroup --settings INJECT_ERROR=0 | Out-Null

Write-Host "Generating baseline traffic..." -ForegroundColor Cyan
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
1..20 | ForEach-Object {
    try { Invoke-WebRequest -Uri "https://$AppUrl" -UseBasicParsing -WebSession $session | Out-Null } catch {}
    Start-Sleep -Milliseconds 300
}

Write-Host "Injecting fault..." -ForegroundColor Yellow
az webapp config appsettings set --name $AppName --resource-group $ResourceGroup --settings INJECT_ERROR=1 | Out-Null
Start-Sleep -Seconds 10

Write-Host "Generating failing traffic..." -ForegroundColor Yellow
1..25 | ForEach-Object {
    try { Invoke-WebRequest -Uri "https://$AppUrl/?crash=1" -UseBasicParsing -WebSession $session | Out-Null } catch {}
    Start-Sleep -Milliseconds 250
}

Write-Host "Warmup complete. Give telemetry a moment to arrive before starting the investigation." -ForegroundColor Green
