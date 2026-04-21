<#
.SYNOPSIS
    Get Copilot premium request usage for Franz's GitHub accounts.

.DESCRIPTION
    Fetches and displays Copilot Pro+/Business usage for:
    - HemSoft (Personal #1) - Pro+ personal + fhemmer org Business
    - fhemmerrelias (Work #1) - Pro+ via Relias

.PARAMETER Account
    Which account(s) to query: 'personal1', 'work', or 'all' (default)

.PARAMETER Year
    Year to query (default: current year)

.PARAMETER Month
    Month to query (default: current month)

.PARAMETER Login
    Force re-authentication for the specified account(s)

.EXAMPLE
    .\Get-MyCopilotUsage.ps1
    # Get usage for all accounts

.EXAMPLE
    .\Get-MyCopilotUsage.ps1 -Account personal1
    # Get HemSoft account only
#>


[CmdletBinding()]
param(
    [ValidateSet('personal1', 'work', 'all')]
    [string]$Account = 'all',
    [int]$Year = (Get-Date).Year,
    [int]$Month = (Get-Date).Month,
    [switch]$Login
)

$InformationPreference = 'Continue'

# Account configuration
$accounts = @{
    personal1 = @{
        Username = 'HemSoft'
        Email    = 'franz_hemmer@hotmail.com'
        Label    = 'Personal #1 (HemSoft)'
        Plan     = 'Pro+'
        Quota    = 1500
        OrgAccess = 'fhemmer'
    }
    work = @{
        Username = 'fhemmerrelias'
        Email    = 'fhemmer@relias.com'
        Label    = 'Work #1 (fhemmerrelias)'
        Plan     = 'Pro+'
        Quota    = 1500
        OrgAccess = $null
    }
}

$organizations = @{
    fhemmer = @{
        Name       = 'HemSoft Developments'
        PlanType   = 'Business'
        Seats      = 1
        Members    = @('HemSoft')
        Enterprise = 'hemsoft-corp'
        # Business plan includes 300 premium requests per user per month
        PremiumAllowancePerSeat = 300  # requests
    }
}

$enterprises = @{
    'hemsoft-corp' = @{
        Name     = 'HemSoft Corp'
        Licenses = 50
        Admins   = @('HemSoft')
        Orgs     = @('fhemmer')
        Url      = 'https://github.com/enterprises/hemsoft-corp'
    }
}

function Get-CurrentGhUser {
    $user = gh api /user --jq '.login' 2>$null
    if ($LASTEXITCODE -eq 0) { return $user }
    return $null
}

function Switch-GhAccount {
    param([string]$Username)
    $currentUser = Get-CurrentGhUser
    if ($currentUser -eq $Username) { return $true }
    gh auth switch -u $Username 2>&1 | Out-Null
    return ($LASTEXITCODE -eq 0)
}

function Invoke-GhLogin {
    param([string]$Username)
    Write-Information "[36m  Authenticating as $Username...`e[0m"
    gh auth login -h github.com -s user -w
    return ($LASTEXITCODE -eq 0)
}

function Get-UserUsage {
    param([string]$Username, [int]$Year, [int]$Month)
    $response = gh api "/users/$Username/settings/billing/premium_request/usage?year=$Year&month=$Month" 2>&1
    if ($LASTEXITCODE -ne 0) { return $null }
    return $response | ConvertFrom-Json
}

function Get-OrgUsage {
    param([string]$Org, [int]$Year, [int]$Month)
    $response = gh api "/orgs/$Org/settings/billing/premium_request/usage?year=$Year&month=$Month" 2>&1
    if ($LASTEXITCODE -ne 0) { return $null }
    return $response | ConvertFrom-Json
}

function Get-OrgCopilotInfo {
    param([string]$Org)
    $response = gh api "/orgs/$Org/copilot/billing" 2>&1
    if ($LASTEXITCODE -ne 0) { return $null }
    return $response | ConvertFrom-Json
}

function Get-EnterpriseInfo {
    param([string]$Slug)
    $query = 'query($slug: String!) { enterprise(slug: $slug) { name billingInfo { totalLicenses totalAvailableLicenses } ownerInfo { admins(first: 10) { nodes { login } } } organizations(first: 20) { nodes { login } } } }'
    $response = gh api graphql -f query="$query" -f slug="$Slug" 2>&1
    if ($LASTEXITCODE -ne 0) { return $null }
    return ($response | ConvertFrom-Json).data.enterprise
}

function Get-EnterpriseUsage {
    param([string]$Slug, [int]$Year, [int]$Month)
    $response = gh api "/enterprises/$Slug/settings/billing/premium_request/usage?year=$Year&month=$Month" 2>&1
    if ($LASTEXITCODE -ne 0) { return $null }
    return $response | ConvertFrom-Json
}

function Show-UsageBar {
    param([double]$Used, [double]$Quota, [int]$BarLength = 30)
    if ($Quota -eq 0) { return @{ Bar = ''; Percent = 0; Color = 'DarkGray' } }
    $percentUsed = ($Used / $Quota) * 100
    $displayPercent = [Math]::Min(100, $percentUsed)  # Cap bar at 100%
    $filledLength = [Math]::Floor($BarLength * $displayPercent / 100)
    $bar = ([char]0x2588).ToString() * $filledLength + ([char]0x2591).ToString() * ($BarLength - $filledLength)
    $color = if ($percentUsed -ge 100) { 'Red' } elseif ($percentUsed -ge 80) { 'Yellow' } else { 'Green' }
    return @{ Bar = $bar; Percent = $percentUsed; Color = $color }
}

function Format-Currency { param([double]$Amount) return '$' + '{0:N2}' -f $Amount }
function Format-Number { param([double]$Number) return '{0:N2}' -f $Number }

function Show-ModelBreakdown {
    param($UsageItems)
    if (-not $UsageItems -or $UsageItems.Count -eq 0) {
        Write-Information "[90m    (no usage this period)`e[0m"
        return
    }
    foreach ($item in $UsageItems) {
        $model = $item.model
        $qty = Format-Number $item.grossQuantity
        $amt = Format-Currency $item.grossAmount
        $discount = Format-Currency $item.discountAmount
        $net = Format-Currency $item.netAmount
        Write-Information "[97m    $model`e[0m"
        Write-Information "[90m      Requests: $qty | Gross: $amt | Discount: $discount | Net: $net`e[0m"
    }
}

function Show-AccountUsage {
    param([hashtable]$Acct, [int]$Year, [int]$Month, [switch]$ForceLogin)

    Write-Information ""
    Write-Information "[33m  $($Acct.Label)`e[0m"
    Write-Information "[90m  Email: $($Acct.Email) | Plan: $($Acct.Plan)`e[0m"
    Write-Information "  " + ("-" * 50)

    # Switch to account
    if (-not (Switch-GhAccount -Username $Acct.Username)) {
        if ($ForceLogin) { Invoke-GhLogin -Username $Acct.Username | Out-Null }
        else {
            Write-Information "[31m    Unable to switch to $($Acct.Username)`e[0m"
            return $null
        }
    }

    # Get personal usage
    $data = Get-UserUsage -Username $Acct.Username -Year $Year -Month $Month
    $totalRequests = 0
    $totalGross = 0
    $totalDiscount = 0
    $totalNet = 0

    if ($data -and $data.usageItems) {
        $totalRequests = ($data.usageItems | Measure-Object -Property grossQuantity -Sum).Sum
        $totalGross = ($data.usageItems | Measure-Object -Property grossAmount -Sum).Sum
        $totalDiscount = ($data.usageItems | Measure-Object -Property discountAmount -Sum).Sum
        $totalNet = ($data.usageItems | Measure-Object -Property netAmount -Sum).Sum
    }

    if ($Acct.Quota -gt 0) {
        $bar = Show-UsageBar -Used $totalRequests -Quota $Acct.Quota

        Write-Information "    Personal Quota: " -NoNewline
        Write-Information "[97m$(Format-Number $totalRequests)`e[0m"
        Write-Information " / $($Acct.Quota) requests (" -NoNewline
        Write-Information "$("{0:N1}%" -f $bar.Percent)" -ForegroundColor $bar.Color -NoNewline
        Write-Information ")"

        Write-Information "    [$($bar.Bar)]" -ForegroundColor $bar.Color

        if ($totalNet -gt 0) {
            Write-Information "    Overage Cost: " -NoNewline
            Write-Information "[31m$(Format-Currency $totalNet)`e[0m"
        }
    } else {
        Write-Information "[90m    Personal Quota: N/A (org license only)`e[0m"
    }

    Write-Information ""
    Write-Information "[36m    Model Breakdown:`e[0m"
    Show-ModelBreakdown -UsageItems $data.usageItems

    return [PSCustomObject]@{
        Account      = $Acct.Label
        Username     = $Acct.Username
        Used         = $totalRequests
        Quota        = $Acct.Quota
        Remaining    = if ($Acct.Quota -gt 0) { [Math]::Max(0, $Acct.Quota - $totalRequests) } else { 0 }
        Percent      = if ($Acct.Quota -gt 0) { ($totalRequests / $Acct.Quota) * 100 } else { 0 }
        GrossAmount  = $totalGross
        DiscountAmount = $totalDiscount
        NetCost      = $totalNet
    }
}

function Show-OrgUsage {
    param([string]$OrgKey, [hashtable]$Org, [int]$Year, [int]$Month)

    Write-Information ""
    Write-Information "[35m  Organization: $OrgKey ($($Org.Name))`e[0m"
    Write-Information "[90m  Plan: $($Org.PlanType) | Seats: $($Org.Seats) | Members: $($Org.Members -join ', ')`e[0m"
    Write-Information "  " + ("-" * 50)

    $data = Get-OrgUsage -Org $OrgKey -Year $Year -Month $Month
    $info = Get-OrgCopilotInfo -Org $OrgKey

    $activeSeats = $Org.Seats
    if ($info) {
        $seats = $info.seat_breakdown
        $activeSeats = $seats.active_this_cycle
        Write-Information "[90m    Seat Status: $($seats.total) total, $activeSeats active, $($seats.inactive_this_cycle) inactive`e[0m"
    }

    $totalRequests = 0
    $totalGross = 0
    $totalNet = 0

    if ($data -and $data.usageItems) {
        $totalRequests = ($data.usageItems | Measure-Object -Property grossQuantity -Sum).Sum
        $totalGross = ($data.usageItems | Measure-Object -Property grossAmount -Sum).Sum
        $totalNet = ($data.usageItems | Measure-Object -Property netAmount -Sum).Sum
    }

    # Calculate org premium request quota (allowance per seat × active seats)
    $orgQuota = 0
    if ($Org.PremiumAllowancePerSeat) {
        $orgQuota = $Org.PremiumAllowancePerSeat * $activeSeats
    }

    # Show org quota usage with progress bar (like GitHub UI)
    if ($orgQuota -gt 0) {
        $bar = Show-UsageBar -Used $totalRequests -Quota $orgQuota
        Write-Information "    Premium Quota: " -NoNewline
        Write-Information "[97m$(Format-Number $totalRequests)`e[0m"
        Write-Information " / $orgQuota requests (" -NoNewline
        Write-Information "$("{0:N1}%" -f $bar.Percent)" -ForegroundColor $bar.Color -NoNewline
        Write-Information ")"
        Write-Information "    [$($bar.Bar)]" -ForegroundColor $bar.Color

        if ($bar.Percent -gt 100) {
            $overageReqs = $totalRequests - $orgQuota
            Write-Information "[31m    ⚠️  Over quota by $(Format-Number $overageReqs) requests`e[0m"
        }
    }

    Write-Information "    Total Usage: $(Format-Number $totalRequests) requests | Gross: $(Format-Currency $totalGross) | Net: $(Format-Currency $totalNet)"
    
    if ($totalNet -gt 0) {
        Write-Information "    💰 Overage Cost: " -NoNewline
        Write-Information "[31m$(Format-Currency $totalNet)`e[0m"
    }

    Write-Information ""
    Write-Information "[36m    Model Breakdown:`e[0m"
    Show-ModelBreakdown -UsageItems $data.usageItems

    return [PSCustomObject]@{
        Org          = $OrgKey
        Name         = $Org.Name
        Used         = $totalRequests
        Quota        = $orgQuota
        GrossAmount  = $totalGross
        NetCost      = $totalNet
        Enterprise   = $Org.Enterprise
    }
}

function Show-EnterpriseInfo {
    param([string]$Slug, [hashtable]$Ent)

    Write-Information ""
    Write-Information "[94m  Enterprise: $($Ent.Name)`e[0m"
    Write-Information "[90m  URL: $($Ent.Url)`e[0m"
    Write-Information "  " + ("-" * 50)

    $info = Get-EnterpriseInfo -Slug $Slug
    if ($info) {
        $licenses = $info.billingInfo.totalLicenses
        $available = $info.billingInfo.totalAvailableLicenses
        $used = $licenses - $available
        $admins = ($info.ownerInfo.admins.nodes | ForEach-Object { $_.login }) -join ', '
        $orgs = ($info.organizations.nodes | ForEach-Object { $_.login }) -join ', '

        Write-Information "[90m    Licenses: $used / $licenses used ($available available)`e[0m"
        Write-Information "[90m    Admins: $admins`e[0m"
        Write-Information "[90m    Organizations: $orgs`e[0m"
    } else {
        Write-Information "[90m    Licenses: $($Ent.Licenses) | Admins: $($Ent.Admins -join ', ')`e[0m"
        Write-Information "[90m    Organizations: $($Ent.Orgs -join ', ')`e[0m"
    }

    return [PSCustomObject]@{
        Slug     = $Slug
        Name     = $Ent.Name
        Licenses = $Ent.Licenses
    }
}

# ============================================================
# MAIN
# ============================================================

$startTime = Get-Date
$originalUser = Get-CurrentGhUser

Write-Information ""
Write-Information "[36m  ================================================================`e[0m"
Write-Information "[36m    GitHub Copilot Usage Report`e[0m"
Write-Information "[36m    Period: $Month/$Year`e[0m"
Write-Information "[36m    Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`e[0m"
Write-Information "[36m  ================================================================`e[0m"

# Determine which accounts to query
$targetAccounts = switch ($Account) {
    'all'       { @('personal1', 'work') }
    'personal'  { @('personal1') }  # Backwards compat
    default     { @($Account) }
}

$results = @()
$orgResults = @()
$enterpriseResults = @()
$orgsQueried = @()
$enterprisesQueried = @()

# Query each account
foreach ($acctKey in $targetAccounts) {
    $acct = $accounts[$acctKey]
    $result = Show-AccountUsage -Acct $acct -Year $Year -Month $Month -ForceLogin:$Login
    if ($result) { $results += $result }

    # Query org if applicable and not already queried
    if ($acct.OrgAccess -and $acct.OrgAccess -notin $orgsQueried) {
        $org = $organizations[$acct.OrgAccess]
        if ($org) {
            $orgResult = Show-OrgUsage -OrgKey $acct.OrgAccess -Org $org -Year $Year -Month $Month
            if ($orgResult) { 
                $orgResults += $orgResult 
                
                # Query enterprise if org belongs to one
                if ($org.Enterprise -and $org.Enterprise -notin $enterprisesQueried) {
                    $ent = $enterprises[$org.Enterprise]
                    if ($ent) {
                        $entResult = Show-EnterpriseInfo -Slug $org.Enterprise -Ent $ent
                        if ($entResult) { $enterpriseResults += $entResult }
                        $enterprisesQueried += $org.Enterprise
                    }
                }
            }
            $orgsQueried += $acct.OrgAccess
        }
    }
}

# Restore original auth
if ($originalUser) {
    Switch-GhAccount -Username $originalUser | Out-Null
}

# Summary
Write-Information ""
Write-Information "[36m  ================================================================`e[0m"
Write-Information "[36m    SUMMARY`e[0m"
Write-Information "[36m  ================================================================`e[0m"

$totalUsed = ($results | Measure-Object -Property Used -Sum).Sum
$totalQuota = ($results | Where-Object { $_.Quota -gt 0 } | Measure-Object -Property Quota -Sum).Sum
$totalRemaining = ($results | Where-Object { $_.Quota -gt 0 } | Measure-Object -Property Remaining -Sum).Sum
$totalGross = ($results | Measure-Object -Property GrossAmount -Sum).Sum
$totalDiscount = ($results | Measure-Object -Property DiscountAmount -Sum).Sum
$totalNet = ($results | Measure-Object -Property NetCost -Sum).Sum

$orgUsed = ($orgResults | Measure-Object -Property Used -Sum).Sum
$orgGross = ($orgResults | Measure-Object -Property GrossAmount -Sum).Sum
$orgNet = ($orgResults | Measure-Object -Property NetCost -Sum).Sum

Write-Information ""
Write-Information "[33m  Personal Accounts:`e[0m"
Write-Information "    Total Requests:  $(Format-Number $totalUsed) / $totalQuota (personal quota)"
Write-Information "    Remaining Quota: $(Format-Number $totalRemaining) requests"
Write-Information "    Gross Value:     $(Format-Currency $totalGross)"
Write-Information "    Discount:        $(Format-Currency $totalDiscount)"
Write-Information "    Net Cost:        $(Format-Currency $totalNet)"

if ($orgResults.Count -gt 0) {
    Write-Information ""
    Write-Information "[35m  Organizations:`e[0m"
    $orgQuota = ($orgResults | Measure-Object -Property Quota -Sum).Sum
    Write-Information "    Total Requests:  $(Format-Number $orgUsed) / $orgQuota (premium quota)"
    Write-Information "    Gross Value:     $(Format-Currency $orgGross)"
    Write-Information "    Net Cost:        $(Format-Currency $orgNet)"
}

Write-Information ""
Write-Information "[36m  Combined Total:`e[0m"
Write-Information "    All Requests:    $(Format-Number ($totalUsed + $orgUsed))"
Write-Information "    All Gross Value: $(Format-Currency ($totalGross + $orgGross))"
Write-Information "    All Net Cost:    $(Format-Currency ($totalNet + $orgNet))"

$elapsed = (Get-Date) - $startTime
Write-Information ""
Write-Information "[90m$("  Completed in $("{0:N1}" -f $elapsed.TotalSeconds)s")`e[0m"
Write-Information ""
