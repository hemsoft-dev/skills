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

$InformationPreference = 'Continue'

Write-Information "[36mFetching GitHub account info...`e[0m"

# Get authenticated user data (includes plan info)
$response = gh api /user 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to fetch user data: $response"
    exit 1
}

$user = $response | ConvertFrom-Json

Write-Information "[90m`n┌─────────────────────────────────────────┐`e[0m"
Write-Information "[97m│  GitHub Account: @$($user.login)`e[0m"
Write-Information "[90m└─────────────────────────────────────────┘`e[0m"

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

Write-Information "[36m`nSubscription:`e[0m"
Write-Information "  Plan:              " -NoNewline
Write-Information $planDisplay -ForegroundColor $planColor

Write-Information "  Space:             $("{0:N0} MB" -f ($user.plan.space / 1024 / 1024))"
Write-Information "  Private Repos:     $($user.plan.private_repos)"
Write-Information "  Collaborators:     $(if ($user.plan.collaborators -eq 0) { 'Unlimited' } else { $user.plan.collaborators })"

Write-Information "[36m`nAccount Stats:`e[0m"
Write-Information "  Public Repos:      $($user.public_repos)"
Write-Information "  Private Repos:     $($user.owned_private_repos)"
Write-Information "  Total Repos:       $($user.total_private_repos + $user.public_repos)"
Write-Information "  Disk Usage:        $("{0:N2} MB" -f ($user.disk_usage / 1024))"
Write-Information "  Followers:         $($user.followers)"
Write-Information "  Following:         $($user.following)"

Write-Information "[36m`nSecurity:`e[0m"
Write-Information "  2FA Enabled:       $(if ($user.two_factor_authentication) { '✓ Yes' } else { '✗ No' })"

Write-Information "[90m`nAccount Created:     $($user.created_at)`e[0m"
Write-Information "[90mLast Updated:        $($user.updated_at)`e[0m"

# Pro+ specific info
if ($planName -eq "pro" -or $planName -eq "pro+") {
    Write-Information "[36m`n┌─────────────────────────────────────────┐`e[0m"
    Write-Information "[36m│  Pro+ Benefits                          │`e[0m"
    Write-Information "[36m└─────────────────────────────────────────┘`e[0m"
    Write-Information "  • 1,500 premium Copilot requests/month"
    Write-Information "  • Access to Claude, GPT-4o, o1 models"
    Write-Information "  • Copilot Agent mode"
    Write-Information "  • 3,000 Actions minutes/month"
    Write-Information "  • 2 GB Packages storage"
    Write-Information ""
    Write-Information "[90m  Run Get-CopilotUsage.ps1 for usage details`e[0m"
}
