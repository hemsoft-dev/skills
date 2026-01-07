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

[CmdletBinding()]
param(
    [string]$Username
)

Write-Host "Fetching GitHub account info..." -ForegroundColor Cyan

# Get authenticated user data (includes plan info)
$response = gh api /user 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to fetch user data: $response"
    exit 1
}

$user = $response | ConvertFrom-Json

Write-Host "`n┌─────────────────────────────────────────┐" -ForegroundColor DarkGray
Write-Host "│  GitHub Account: @$($user.login)" -ForegroundColor White
Write-Host "└─────────────────────────────────────────┘" -ForegroundColor DarkGray

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

Write-Host "`nSubscription:" -ForegroundColor Cyan
Write-Host "  Plan:              " -NoNewline
Write-Host $planDisplay -ForegroundColor $planColor

Write-Host "  Space:             $("{0:N0} MB" -f ($user.plan.space / 1024 / 1024))"
Write-Host "  Private Repos:     $($user.plan.private_repos)"
Write-Host "  Collaborators:     $(if ($user.plan.collaborators -eq 0) { 'Unlimited' } else { $user.plan.collaborators })"

Write-Host "`nAccount Stats:" -ForegroundColor Cyan
Write-Host "  Public Repos:      $($user.public_repos)"
Write-Host "  Private Repos:     $($user.owned_private_repos)"
Write-Host "  Total Repos:       $($user.total_private_repos + $user.public_repos)"
Write-Host "  Disk Usage:        $("{0:N2} MB" -f ($user.disk_usage / 1024))"
Write-Host "  Followers:         $($user.followers)"
Write-Host "  Following:         $($user.following)"

Write-Host "`nSecurity:" -ForegroundColor Cyan
Write-Host "  2FA Enabled:       $(if ($user.two_factor_authentication) { '✓ Yes' } else { '✗ No' })"

Write-Host "`nAccount Created:     $($user.created_at)" -ForegroundColor DarkGray
Write-Host "Last Updated:        $($user.updated_at)" -ForegroundColor DarkGray

# Pro+ specific info
if ($planName -eq "pro" -or $planName -eq "pro+") {
    Write-Host "`n┌─────────────────────────────────────────┐" -ForegroundColor Cyan
    Write-Host "│  Pro+ Benefits                          │" -ForegroundColor Cyan
    Write-Host "└─────────────────────────────────────────┘" -ForegroundColor Cyan
    Write-Host "  • 1,500 premium Copilot requests/month"
    Write-Host "  • Access to Claude, GPT-4o, o1 models"
    Write-Host "  • Copilot Agent mode"
    Write-Host "  • 3,000 Actions minutes/month"
    Write-Host "  • 2 GB Packages storage"
    Write-Host ""
    Write-Host "  Run Get-CopilotUsage.ps1 for usage details" -ForegroundColor DarkGray
}
