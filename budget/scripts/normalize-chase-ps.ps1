<#
.SYNOPSIS
    Normalizes Chase Credit Card CSVs using GitHub Copilot CLI
.DESCRIPTION
    Processes all CSV files in the 2025 folder and uses Copilot to categorize transactions
#>

$StatementsRoot = "F:\OneDrive\Documents\Budget\Statements"
$AccountName = "Chase Credit Card"
$AccountRoot = Join-Path $StatementsRoot $AccountName
$YearFolder = Join-Path $AccountRoot "2025"
$CategoryFile = Join-Path $StatementsRoot "category-choices.txt"

# Get categories
$Categories = Get-Content $CategoryFile -Raw

# Get all CSV files
$CsvFiles = Get-ChildItem -Path $YearFolder -Filter "*.csv" | Sort-Object Name
Write-Host "Processing $($CsvFiles.Count) files..."

$AllData = @{}
$Total = 0

foreach ($CsvFile in $CsvFiles) {
    $Index = [array]::IndexOf($CsvFiles, $CsvFile) + 1
    Write-Host "[$Index/$($CsvFiles.Count)] $($CsvFile.Name)"
    
    $CsvContent = Get-Content $CsvFile.FullName -Raw
    
    $Prompt = "Convert to normalized CSV. Only output CSV lines, no markdown fences. Header: Date,Account,Category,Description,Amount. YYYY-MM-DD dates. Negative=expense. Payments POSITIVE as Credit Card Payment. Account: $AccountName. Categories: $Categories. CSV: $CsvContent"
    
    # Call copilot directly
    $Output = $Prompt | copilot --model claude-haiku-4.5 2>$null
    
    # Parse output for valid CSV lines
    $Lines = @()
    foreach ($Line in ($Output -split "`n")) {
        $Line = $Line.Trim()
        if ($Line -match '^\d{4}-\d{2}-\d{2},') {
            $Lines += $Line
        }
    }
    
    $Total += $Lines.Count
    Write-Host "  $($Lines.Count) transactions (total: $Total)"
    
    # Group by year-month
    foreach ($Line in $Lines) {
        $YearMonth = $Line.Substring(0, 7)
        if (-not $AllData.ContainsKey($YearMonth)) {
            $AllData[$YearMonth] = @()
        }
        $AllData[$YearMonth] += $Line
    }
}

# Write output files
$Header = "Date,Account,Category,Description,Amount"
foreach ($YearMonth in ($AllData.Keys | Sort-Object)) {
    $OutFile = Join-Path $AccountRoot "$YearMonth.csv"
    $Header | Out-File -FilePath $OutFile -Encoding utf8
    $AllData[$YearMonth] | Out-File -FilePath $OutFile -Append -Encoding utf8
    Write-Host "Created: $YearMonth.csv ($($AllData[$YearMonth].Count) transactions)"
}

Write-Host "`nDone! $Total total transactions normalized."
