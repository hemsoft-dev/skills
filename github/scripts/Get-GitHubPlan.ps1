<#
.SYNOPSIS
    Get GitHub account plan/subscription type.

.DESCRIPTION
    Shows the current GitHub subscription plan (Free, Pro, Pro+, Team, Enterprise)
    along with account limits and usage statistics.

.PARAMETER Username
    GitHub username. Defaults to authenticated user.

.EXAMPLE
    .\Get-GitHubPlan.ps1
    # Show plan info for authenticated user
#>

$InformationPreference = 'Continue'

[CmdletBinding()]
param(
    [string]$Username
)

Write-Information "Fetching GitHub account info..." -ForegroundColor Cyan

# Get authenticated user data (includes plan info)
$response = gh api /user 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to fetch user data: $response"
    exit 1
}

$user = $response | ConvertFrom-Json

Write-Information "`n┌─────────────────────────────────────────┐" -ForegroundColor DarkGray
Write-Information "│  GitHub Account: @$($user.login)" -ForegroundColor White
Write-Information "└─────────────────────────────────────────┘" -ForegroundColor DarkGray

# Plan info
$planName = $user.plan.name
$planDisplay = switch ($planName) {
    "free" { "Free" }
    "pro" { "Pro" }
    "pro+" { "Pro+" }
    default { $planName }
}

$planColor = switch ($planName) {
    "free" { "White" }
    "pro" { "Green" }
    "pro+" { "Cyan" }
    default { "Yellow" }
}

Write-Information "`nSubscription:" -ForegroundColor Cyan
Write-Information "  Plan:              " -NoNewline
Write-Information $planDisplay -ForegroundColor $planColor

Write-Information "  Space:             $("{0:N0} MB" -f ($user.plan.space / 1024 / 1024))"
Write-Information "  Private Repos:     $($user.plan.private_repos)"
Write-Information "  Collaborators:     $(if ($user.plan.collaborators -eq 0) { 'Unlimited' } else { $user.plan.collaborators })"

Write-Information "`nAccount Stats:" -ForegroundColor Cyan
Write-Information "  Public Repos:      $($user.public_repos)"
Write-Information "  Private Repos:     $($user.owned_private_repos)"
Write-Information "  Total Repos:       $($user.total_private_repos + $user.public_repos)"
Write-Information "  Disk Usage:        $("{0:N2} MB" -f ($user.disk_usage / 1024))"
Write-Information "  Followers:         $($user.followers)"
Write-Information "  Following:         $($user.following)"

Write-Information "`nSecurity:" -ForegroundColor Cyan
Write-Information "  2FA Enabled:       $(if ($user.two_factor_authentication) { '✓ Yes' } else { '✗ No' })"

Write-Information "`nAccount Created:     $($user.created_at)" -ForegroundColor DarkGray
Write-Information "Last Updated:        $($user.updated_at)" -ForegroundColor DarkGray

# Pro+ specific info
if ($planName -eq "pro" -or $planName -eq "pro+") {
    Write-Information "`n┌─────────────────────────────────────────┐" -ForegroundColor Cyan
    Write-Information "│  Pro+ Benefits                          │" -ForegroundColor Cyan
    Write-Information "└─────────────────────────────────────────┘" -ForegroundColor Cyan
    Write-Information "  • 1,500 premium Copilot requests/month"
    Write-Information "  • Access to Claude, GPT-4o, o1 models"
    Write-Information "  • Copilot Agent mode"
    Write-Information "  • 3,000 Actions minutes/month"
    Write-Information "  • 2 GB Packages storage"
    Write-Information ""
    Write-Information "  Run Get-CopilotUsage.ps1 for usage details" -ForegroundColor DarkGray
}
