# FetchAllAccounts.ps1
# Fetches backup data for all tracked Egg Inc accounts and saves to JSON files

$accounts = @(
    @{ Name = "king-friday"; EID = "EI6335140328505344" }
    @{ Name = "king-saturday"; EID = "EI5435770400276480" }
    @{ Name = "king-sunday"; EID = "EI6306349753958400" }
    @{ Name = "king-monday"; EID = "EI6725967592947712" }
)

$dataDir = Join-Path $PSScriptRoot "data"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

foreach ($account in $accounts) {
    $url = "https://ei_worker.tylertms.workers.dev/backup?EID=$($account.EID)"
    $outputPath = Join-Path $dataDir "$($account.Name).json"
    
    try {
        Write-Host "Fetching $($account.Name)..." -NoNewline
        $response = Invoke-RestMethod -Uri $url -Method Get
        $response | ConvertTo-Json -Depth 100 | Set-Content -Path $outputPath -Encoding UTF8
        Write-Host " OK" -ForegroundColor Green
    }
    catch {
        Write-Host " FAILED: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`nData saved to: $dataDir"
