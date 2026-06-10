param(
    [string]$AppName = "<APP_NAME>",
    [string]$ResourceGroup = "<APP_RESOURCE_GROUP>",
    [string]$AppUrl = "<APP_URL>"
)

Write-Host "Restoring baseline configuration..." -ForegroundColor Cyan
az webapp config appsettings set --name $AppName --resource-group $ResourceGroup --settings INJECT_ERROR=0 | Out-Null
Start-Sleep -Seconds 5

Write-Host "Running smoke test..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri "https://$AppUrl" -UseBasicParsing | Out-Null
    Write-Host "Application responded successfully." -ForegroundColor Green
}
catch {
    Write-Host "Smoke test failed. Review the app before the next demo." -ForegroundColor Red
}
