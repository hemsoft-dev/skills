<#
.SYNOPSIS
    Search emails across accounts by keyword.
.DESCRIPTION
    Parent orchestrator - calls child scripts for each account.
    Searches subject and body content for matching messages.
    Output is in TOON format for token efficiency.
.PARAMETER Query
    Search keyword or phrase (required).
.PARAMETER Account
    Specific account to query. If omitted, queries ALL configured accounts.
.PARAMETER Count
    Maximum messages per account (default: 10, max: 50).
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$Query,
    
    [ValidateSet("outlook", "gmail", "work", "hemmer.us")]
    [string]$Account,
    
    [int]$Count = 10
)

$ErrorActionPreference = 'Stop'
$Count = [Math]::Clamp($Count, 1, 50)

# Active accounts (work is blocked awaiting org admin consent)
$AllAccounts = @('outlook', 'gmail', 'hemmer.us')
$Accounts = if ($Account) { @($Account) } else { $AllAccounts }

$Results = @()
$AllMessages = @()

foreach ($acct in $Accounts) {
    $childScript = Join-Path $PSScriptRoot "$acct\mail-search.ps1"
    
    if (-not (Test-Path $childScript)) {
        $Results += @{ account = $acct; configured = $false; count = 0 }
        continue
    }
    
    try {
        $result = & $childScript -Query $Query -Count $Count
        
        if ($result.configured -eq $false) {
            $Results += @{ account = $acct; configured = $false; count = 0 }
            continue
        }
        
        $Results += @{
            account    = $acct
            configured = $true
            count      = $result.count
        }
        
        if ($result.messages) {
            foreach ($m in $result.messages) {
                $m.account = $acct
                $AllMessages += $m
            }
        }
    }
    catch {
        $Results += @{
            account    = $acct
            configured = $true
            count      = 0
            error      = $_.Exception.Message
        }
    }
}

# Output in TOON format
$configuredResults = @($Results | Where-Object { $_.configured })

Write-Output "search_query: $Query"
Write-Output ""
Write-Output "summary[$($configuredResults.Count)]{account,matches}:"
foreach ($r in $configuredResults) {
    Write-Output "  $($r.account),$($r.count)"
}

$totalMatches = ($configuredResults | Measure-Object -Property count -Sum).Sum
Write-Output ""
Write-Output "total_matches: $totalMatches"

if ($AllMessages.Count -gt 0) {
    Write-Output ""
    Write-Output "emails[$($AllMessages.Count)]{status,date,from,subject,id,account}:"
    foreach ($m in $AllMessages) {
        $from = ($m.from -replace ',', ';' -replace '"', '') -replace '^(.{40}).*', '$1...'
        $subject = ($m.subject -replace ',', ';') -replace '^(.{50}).*', '$1...'
        $dateShort = if ($m.date -match '(\d+/\d+/\d+)\s+(\d+:\d+)') { "$($Matches[1]) $($Matches[2])" } else { $m.date }
        Write-Output "  $($m.status)`t$dateShort`t$from`t$subject`t$($m.id)`t$($m.account)"
    }
}

$unconfigured = @($Results | Where-Object { -not $_.configured })
if ($unconfigured.Count -gt 0) {
    Write-Output ""
    Write-Output "unconfigured: $(($unconfigured.account) -join ',')"
}
