param([string]$AppUrl = "<APP_URL>")

try {
    $response = Invoke-WebRequest -Uri "https://$AppUrl" -UseBasicParsing
    Write-Host "Status code: $($response.StatusCode)" -ForegroundColor Green
}
catch {
    Write-Host "Application did not respond successfully." -ForegroundColor Red
    throw
}
