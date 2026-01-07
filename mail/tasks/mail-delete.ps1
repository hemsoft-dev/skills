<#
.SYNOPSIS
    Delete emails by ID or delete today's emails.
.DESCRIPTION
    Parent orchestrator - calls child scripts for each account.
    ALWAYS shows what will be deleted and requires confirmation.
.PARAMETER MessageIds
    Array of message IDs to delete (format: "id:account" or just "id" with -Account).
.PARAMETER Account
    Specific account when using simple IDs.
.PARAMETER Today
    Delete all of today's emails across configured accounts.
.PARAMETER Force
    Skip confirmation prompt (USE WITH CAUTION).
#>
$InformationPreference = 'Continue'

param(
    [string[]]$MessageIds,
    [ValidateSet("outlook", "gmail", "work", "hemmer.us")]
    [string]$Account,
    [switch]$Today,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

if (-not $MessageIds -and -not $Today) {
    Write-Error "Specify -MessageIds or -Today"
    exit 1
}

# If -Today, gather all today's message IDs first
if ($Today) {
    $AllAccounts = @('outlook', 'gmail', 'hemmer.us')  # Only accounts with delete support
    $Accounts = if ($Account) { @($Account) } else { $AllAccounts }
    
    $gathered = [System.Collections.ArrayList]::new()
    $preview = [System.Collections.ArrayList]::new()
    
    foreach ($acct in $Accounts) {
        $todayScript = Join-Path $PSScriptRoot "$acct\mail-today.ps1"
        if (Test-Path $todayScript) {
            $result = & $todayScript -List -Count 50
            if ($result.configured -and $result.messages) {
                foreach ($m in $result.messages) {
                    [void]$gathered.Add("$($m.id):$acct")
                    [void]$preview.Add(@{
                        account = $acct
                        subject = $m.subject
                        from = $m.from
                        date = $m.date
                    })
                }
            }
        }
    }
    $MessageIds = $gathered.ToArray()
    
    if ($MessageIds.Count -eq 0) {
        Write-Output "No emails found for today."
        exit 0
    }
    
    # Always show what will be deleted
    Write-Information "`n========== EMAILS TO BE DELETED ==========" -ForegroundColor Red
    Write-Information "Count: $($preview.Count) email(s)`n" -ForegroundColor Yellow
    
    $grouped = $preview | Group-Object -Property account
    foreach ($group in $grouped) {
        Write-Information "[$($group.Name)] - $($group.Count) email(s):" -ForegroundColor Cyan
        foreach ($email in $group.Group) {
            $subjectDisplay = if ($email.subject.Length -gt 50) { $email.subject.Substring(0, 47) + "..." } else { $email.subject }
            $fromDisplay = if ($email.from.Length -gt 30) { $email.from.Substring(0, 27) + "..." } else { $email.from }
            Write-Information "  • $subjectDisplay" -ForegroundColor White
            Write-Information "    From: $fromDisplay | Date: $($email.date)" -ForegroundColor DarkGray
        }
        Write-Information ""
    }
    Write-Information "==========================================`n" -ForegroundColor Red
    
    if (-not $Force) {
        Write-Information "Are you sure you want to DELETE these $($preview.Count) email(s)? " -NoNewline -ForegroundColor Yellow
        Write-Information "[y/N] " -NoNewline -ForegroundColor Green
        $confirm = Read-Host
        if ($confirm -ne 'y' -and $confirm -ne 'Y') {
            Write-Output "Cancelled. No emails were deleted."
            exit 0
        }
    }
}

# Group messages by account
$ByAccount = @{}
foreach ($mid in $MessageIds) {
    # Match account suffix (outlook, gmail, work, hemmer.us)
    if ($mid -match '^(.+):(outlook|gmail|work|hemmer\.us)$') {
        $id = $Matches[1]
        $acct = $Matches[2]
    }
    elseif ($Account) {
        $id = $mid
        $acct = $Account
    }
    else {
        Write-Warning "Skipping '$mid' - no account specified"
        continue
    }
    
    if (-not $ByAccount.ContainsKey($acct)) { $ByAccount[$acct] = [System.Collections.ArrayList]::new() }
    [void]$ByAccount[$acct].Add($id)
}

$TotalDeleted = 0
$TotalFailed = 0

foreach ($acct in $ByAccount.Keys) {
    $ids = @($ByAccount[$acct])  # Convert to array
    $childScript = Join-Path $PSScriptRoot "$acct\mail-delete.ps1"
    
    if (-not (Test-Path $childScript)) {
        Write-Warning "Delete not supported for $acct"
        $TotalFailed += $ids.Count
        continue
    }
    
    try {
        $result = & $childScript -MessageIds $ids
        $TotalDeleted += $result.deleted
        $TotalFailed += $result.failed
    }
    catch {
        Write-Warning "$acct delete failed: $_"
        $TotalFailed += $ids.Count
    }
}

Write-Output "deleted: $TotalDeleted"
Write-Output "failed: $TotalFailed"
