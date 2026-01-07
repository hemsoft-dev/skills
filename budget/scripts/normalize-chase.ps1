$InformationPreference = 'Continue'

# normalize-chase.ps1
# Normalizes all Chase Credit Card CSVs using Copilot CLI

$StatementsRoot = "F:\OneDrive\Documents\Budget\Statements"
$AccountName = "Chase Credit Card"
$Categories = Get-Content "$StatementsRoot\category-choices.txt" -Raw
$Files = Get-ChildItem "$StatementsRoot\$AccountName\2025\*.csv" | Sort-Object Name
$AllData = @{}
$Total = 0

Write-Information "Processing $($Files.Count) files (est. ~12 minutes)..."

for ($i = 0; $i -lt $Files.Count; $i++) {
    $File = $Files[$i]
    Write-Information "[$($i + 1)/$($Files.Count)] $($File.Name)" -NoNewline
    $Csv = Get-Content $File.FullName -Raw
    $Prompt = "Convert CSV to: Date,Account,Category,Description,Amount. YYYY-MM-DD. Negative=expense. Payments POSITIVE as 'Credit Card Payment'. Account: $AccountName. Categories: $Categories`n$Csv"
    $Result = $Prompt | copilot --model claude-haiku-4.5
    $Lines = $Result -split "`n" | Where-Object { $_ -match "^\d{4}-\d{2}-\d{2}," }
    $Total += $Lines.Count
    foreach ($Line in $Lines) {
        if ($Line -match "^(\d{4}-\d{2})") {
            $Month = $Matches[1]
            if (-not $AllData[$Month]) { $AllData[$Month] = @() }
            $AllData[$Month] += $Line
        }
    }
    Write-Information " -> $($Lines.Count) txns (total: $Total)"
}

# Write output
$Header = "Date,Account,Category,Description,Amount"
foreach ($Month in $AllData.Keys | Sort-Object) {
    $OutFile = "$StatementsRoot\$AccountName\$Month.csv"
    (@($Header) + $AllData[$Month]) -join "`n" | Out-File $OutFile -Encoding UTF8
    Write-Information "Created: $Month.csv ($($AllData[$Month].Count) transactions)"
}
Write-Information "`nDone! $Total total transactions."
