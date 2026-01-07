<#
.SYNOPSIS
    Monitor Copilot spending in real-time with alerts.

.DESCRIPTION
    Periodically checks Copilot premium request usage and displays
    current spend with optional threshold alerts.

.PARAMETER Username
    GitHub username. Defaults to authenticated user.

.PARAMETER AlertThreshold
    Dollar amount to trigger alert (default: 50)

.PARAMETER IntervalMinutes
    Check interval in minutes (default: 30)

.PARAMETER Once
    Run once and exit (no continuous monitoring)

.EXAMPLE
    .\Watch-CopilotSpend.ps1 -AlertThreshold 30
    # Alert when spend exceeds $30

.EXAMPLE
    .\Watch-CopilotSpend.ps1 -Once
    # Single check, no monitoring
#>

$InformationPreference = 'Continue'

[CmdletBinding()]
param(
    [string]$Username,
    [decimal]$AlertThreshold = 50,
    [int]$IntervalMinutes = 30,
    [switch]$Once
)

function Get-CurrentSpend {
    param([string]$User)
    
    $response = gh api "/users/$User/settings/billing/premium_request/usage" 2>&1
    if ($LASTEXITCODE -ne 0) { return $null }
    
    $data = $response | ConvertFrom-Json
    
    $totalRequests = ($data.usageItems | Measure-Object -Property grossQuantity -Sum).Sum
    $totalBilled = ($data.usageItems | Measure-Object -Property netAmount -Sum).Sum
    
    return @{
        Requests = $totalRequests
        Billed = $totalBilled
        Period = "$($data.timePeriod.month)/$($data.timePeriod.year)"
    }
}

# Get username
if (-not $Username) {
    $Username = gh api /user --jq '.login'
    if (-not $Username) {
        Write-Error "Could not determine username."
        exit 1
    }
}

$proQuota = 1500
$pricePerRequest = 0.04

Write-Information "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Information "║  Copilot Spend Monitor - @$Username" -ForegroundColor Cyan
Write-Information "║  Alert Threshold: `$$AlertThreshold" -ForegroundColor Cyan
Write-Information "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan

do {
    $timestamp = Get-Date -Format "HH:mm:ss"
    $spend = Get-CurrentSpend -User $Username
    
    if (-not $spend) {
        Write-Information "[$timestamp] Failed to fetch data" -ForegroundColor Red
    } else {
        $percentQuota = ($spend.Requests / $proQuota) * 100
        $overQuota = [Math]::Max(0, $spend.Requests - $proQuota)
        
        # Status bar
        $barLength = 20
        $filled = [Math]::Min($barLength, [Math]::Floor($barLength * $percentQuota / 100))
        $bar = ('█' * $filled) + ('░' * ($barLength - $filled))
        
        $statusColor = if ($spend.Billed -ge $AlertThreshold) { 'Red' } 
                       elseif ($spend.Billed -ge $AlertThreshold * 0.8) { 'Yellow' } 
                       else { 'Green' }
        
        Write-Information ""
        Write-Information "[$timestamp] Period: $($spend.Period)" -ForegroundColor DarkGray
        Write-Information "  Requests: $("{0:N0}" -f $spend.Requests) [$bar] $("{0:N0}%" -f $percentQuota)" -ForegroundColor White
        Write-Information "  Billed:   " -NoNewline
        Write-Information "$("{0:C2}" -f $spend.Billed)" -ForegroundColor $statusColor
        
        if ($overQuota -gt 0) {
            Write-Information "  Over Quota: $("{0:N0}" -f $overQuota) requests" -ForegroundColor Yellow
        }
        
        # Alert
        if ($spend.Billed -ge $AlertThreshold) {
            Write-Information ""
            Write-Information "  ⚠️  ALERT: Spend exceeds threshold of `$$AlertThreshold!" -ForegroundColor Red
            [Console]::Beep(800, 500)
        }
        
        # Projection
        $dayOfMonth = (Get-Date).Day
        $daysInMonth = [DateTime]::DaysInMonth((Get-Date).Year, (Get-Date).Month)
        $projectedRequests = ($spend.Requests / $dayOfMonth) * $daysInMonth
        $projectedBilled = [Math]::Max(0, ($projectedRequests - $proQuota)) * $pricePerRequest
        
        Write-Information ""
        Write-Information "  Projected EOM:" -ForegroundColor DarkGray
        Write-Information "    Requests: ~$("{0:N0}" -f $projectedRequests)" -ForegroundColor DarkGray
        Write-Information "    Billed:   ~$("{0:C2}" -f $projectedBilled)" -ForegroundColor DarkGray
    }
    
    if (-not $Once) {
        Write-Information ""
        Write-Information "  Next check in $IntervalMinutes minutes... (Ctrl+C to stop)" -ForegroundColor DarkGray
        Start-Sleep -Seconds ($IntervalMinutes * 60)
    }
    
} while (-not $Once)
