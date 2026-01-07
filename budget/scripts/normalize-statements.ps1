# normalize-statements.ps1
# Normalizes CSV statement files using Copilot CLI

$StatementsRoot = "F:\OneDrive\Documents\Budget\Statements"
$Year = "2025"
$TemplateFile = Join-Path $StatementsRoot "template.csv"
$CategoryFile = Join-Path $StatementsRoot "category-choices.txt"

# Verify required files exist
if (-not (Test-Path $CategoryFile)) {
    Write-Host "ERROR: category-choices.txt not found. Run generate-categories.ps1 first." -ForegroundColor Red
    exit 1
}

$TemplateContent = Get-Content $TemplateFile -Raw
$Categories = Get-Content $CategoryFile -Raw

# Process each account
Get-ChildItem -Path $StatementsRoot -Directory | Where-Object {
    Test-Path (Join-Path $_.FullName $Year)
} | ForEach-Object {
    $AccountName = $_.Name
    $AccountRoot = $_.FullName
    $YearFolder = Join-Path $AccountRoot $Year
    
    Write-Host "`n=== Processing: $AccountName ===" -ForegroundColor Cyan
    
    # Process each CSV in the year folder
    Get-ChildItem -Path $YearFolder -Filter "*.csv" -File | ForEach-Object {
        $SourceFile = $_.FullName
        $SourceName = $_.BaseName
        
        Write-Host "  Normalizing: $($_.Name)" -ForegroundColor Yellow
        
        $CsvContent = Get-Content $SourceFile -Raw
        
        $Prompt = @"
Convert this bank statement CSV into the normalized format.

TEMPLATE FORMAT (follow exactly):
$TemplateContent

ACCOUNT NAME (use this for the Account column):
$AccountName

CATEGORY OPTIONS (pick the best match for each transaction):
$Categories

SOURCE CSV CONTENT:
$CsvContent

RULES:
1. Output ONLY valid CSV data, no explanations
2. First line must be: Date,Account,Category,Description,Amount
3. Date format: YYYY-MM-DD
4. Amount: negative for expenses/purchases, positive for credits/payments received
5. For credit card accounts: payments TO the card (e.g., "Payment Thank You") are POSITIVE (category: Credit Card Payment)
6. If transactions span multiple months, output ALL transactions (they will be split later)
7. Skip non-transaction rows (headers, summaries, totals, fees tables)
8. Use the Account name provided above for every row
9. Pick the most appropriate category from the list
10. Derive the date from the original filename if it contains month info: $SourceName
"@

        $NormalizedContent = & copilot --model claude-haiku-4.5 -p $Prompt
        
        # Parse the normalized content to split by month
        # Filter to only lines that look like CSV data (start with a date or the header)
        $Lines = $NormalizedContent -split "`n" | Where-Object { 
            $_.Trim() -match "^Date,|^\d{4}-\d{2}-\d{2}," 
        }
        
        if ($Lines.Count -eq 0) {
            Write-Host "    WARNING: No valid CSV data found in output" -ForegroundColor Red
            continue
        }
        
        $Header = "Date,Account,Category,Description,Amount"
        $DataLines = $Lines | Where-Object { $_ -match "^\d{4}-\d{2}-\d{2}," }
        
        # Group by month
        $MonthGroups = @{}
        foreach ($Line in $DataLines) {
            if ($Line -match "^(\d{4}-\d{2})") {
                $YearMonth = $Matches[1]
                if (-not $MonthGroups.ContainsKey($YearMonth)) {
                    $MonthGroups[$YearMonth] = @()
                }
                $MonthGroups[$YearMonth] += $Line
            }
        }
        
        # Write output file(s)
        foreach ($YearMonth in $MonthGroups.Keys) {
            $OutputFile = Join-Path $AccountRoot "$YearMonth.csv"
            $OutputContent = @($Header) + $MonthGroups[$YearMonth]
            
            # Append if file exists, otherwise create
            if (Test-Path $OutputFile) {
                # Append without header
                $MonthGroups[$YearMonth] | Add-Content -Path $OutputFile -Encoding UTF8
            } else {
                $OutputContent -join "`n" | Out-File -FilePath $OutputFile -Encoding UTF8
            }
            
            Write-Host "    -> $YearMonth.csv ($($MonthGroups[$YearMonth].Count) transactions)" -ForegroundColor Green
        }
    }
}

Write-Host "`nNormalization complete." -ForegroundColor Cyan
