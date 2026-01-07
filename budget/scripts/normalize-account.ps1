$InformationPreference = 'Continue'

# normalize-account.ps1
# Normalizes all CSVs for an account with ONE batched AI call
# Usage: .\normalize-account.ps1 -AccountName "Account Name"
param(
    [Parameter(Mandatory=$true)]
    [string]$AccountName
)

$StatementsRoot = "F:\OneDrive\Documents\Budget\Statements"
$AccountRoot = "$StatementsRoot\$AccountName"
$YearFolder = "$AccountRoot\2025"
$Categories = Get-Content "$StatementsRoot\category-choices.txt" -Raw

if (-not (Test-Path $YearFolder)) {
    Write-Information "ERROR: Folder not found: $YearFolder" -ForegroundColor Red
    exit 1
}

# Get source CSVs (exclude already-normalized YYYY-MM.csv files)
$Files = Get-ChildItem "$YearFolder\*.csv" | Where-Object { $_.Name -notmatch '^\d{4}-\d{2}\.csv$' } | Sort-Object Name
if ($Files.Count -eq 0) {
    Write-Information "No source CSV files found in $YearFolder" -ForegroundColor Yellow
    exit 0
}

# Collect ALL transactions from all files
Write-Information "[$AccountName] Loading $($Files.Count) source files..." -ForegroundColor Cyan
$AllLines = @()
foreach ($File in $Files) {
    $Lines = Get-Content $File.FullName | Select-Object -Skip 1  # Skip header
    $AllLines += $Lines
    Write-Information "  $($File.Name): $($Lines.Count) lines"
}

$TotalInput = $AllLines.Count
Write-Information "[$AccountName] $TotalInput total transactions to categorize" -ForegroundColor Cyan

if ($TotalInput -eq 0) {
    Write-Information "No transactions found."
    exit 0
}

# Build combined CSV
$CombinedCsv = "Date,Description,Amount`n" + ($AllLines -join "`n")

# Build prompt
$Prompt = @"
Convert to normalized CSV. Output ONLY CSV data lines, no headers, no markdown, no explanations.

Format per line: Date,Account,Category,Description,Amount
- Date: YYYY-MM-DD
- Account: $AccountName  
- Category: from list below
- Description: clean merchant name
- Amount: negative=expense, POSITIVE for payments/credits

Categories:
$Categories

CSV data:
$CombinedCsv
"@

# Write prompt to temp file (avoids escaping issues)
$TempFile = [System.IO.Path]::GetTempFileName()
$Prompt | Out-File -FilePath $TempFile -Encoding utf8

Write-Information "[$AccountName] Calling AI (1 request for $TotalInput transactions)..." -ForegroundColor Yellow

# Call copilot with piped input
$Result = Get-Content $TempFile -Raw | copilot --model claude-sonnet-4

Remove-Item $TempFile -Force

# Parse output - only lines starting with YYYY-MM-DD,
$NormalizedLines = $Result -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d{4}-\d{2}-\d{2},' }

Write-Information "[$AccountName] Got $($NormalizedLines.Count) normalized transactions" -ForegroundColor Cyan

if ($NormalizedLines.Count -eq 0) {
    Write-Information "ERROR: No transactions parsed from AI output" -ForegroundColor Red
    Write-Information "Raw output (first 500 chars):"
    Write-Information ($Result.Substring(0, [Math]::Min(500, $Result.Length)))
    exit 1
}

# Group by year-month
$AllData = @{}
foreach ($Line in $NormalizedLines) {
    if ($Line -match "^(\d{4}-\d{2})") {
        $Month = $Matches[1]
        if (-not $AllData[$Month]) { $AllData[$Month] = @() }
        $AllData[$Month] += $Line
    }
}

# Write output files
$Header = "Date,Account,Category,Description,Amount"
foreach ($Month in $AllData.Keys | Sort-Object) {
    $OutFile = "$AccountRoot\$Month.csv"
    (@($Header) + $AllData[$Month]) -join "`n" | Out-File $OutFile -Encoding UTF8
    Write-Information "  Created: $Month.csv ($($AllData[$Month].Count) transactions)" -ForegroundColor Green
}

Write-Information "`n[$AccountName] Done! $($NormalizedLines.Count) transactions normalized in 1 AI call." -ForegroundColor Cyan
