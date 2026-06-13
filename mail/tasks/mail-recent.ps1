<#
.SYNOPSIS
    List recent emails across accounts (regardless of read status).
.DESCRIPTION
    Parent orchestrator - calls child scripts for each account.
    Output is in TOON format for token efficiency.
.PARAMETER Account
    Specific account to query. If omitted, queries ALL configured accounts.
.PARAMETER Count
    Number of messages per account (default: 10, max: 50).
.PARAMETER Days
    Filter to emails from N days ago (0=today, 1=yesterday, etc.). If omitted, no date filter.
#>
param(
    [ValidateSet("outlook", "gmail", "work", "hemmer.us")]
    [string]$Account,
    [int]$Count = 10,
    [int]$Days = -1
)

$ErrorActionPreference = 'Stop'
$Count = [Math]::Clamp($Count, 1, 50)

# Active accounts (work is blocked awaiting org admin consent)
$AllAccounts = @('outlook', 'gmail', 'hemmer.us')
$Accounts = if ($Account) { @($Account) } else { $AllAccounts }

$Results = @()
$AllMessages = @()

foreach ($acct in $Accounts) {
    $childScript = Join-Path $PSScriptRoot "$acct\mail-recent.ps1"
    
    if (-not (Test-Path $childScript)) {
        $Results += @{ account = $acct; configured = $false; count = 0 }
        continue
    }
    
    try {
        $result = if ($Days -ge 0) { & $childScript -Count $Count -Days $Days } else { & $childScript -Count $Count }
        
        if ($result.configured -eq $false) {
            $Results += @{ account = $acct; configured = $false; count = 0 }
            continue
        }
        
        $Results += @{
            account    = $acct
            configured = $true
            count      = $result.count
            total      = $result.total
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

Write-Output "summary[$($configuredResults.Count)]{account,returned,total}:"
foreach ($r in $configuredResults) {
    Write-Output "  $($r.account),$($r.count),$($r.total)"
}

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
