<#
.SYNOPSIS
    Assign or remove Copilot licenses for users in an organization.

.DESCRIPTION
    Adds or removes users from an organization's GitHub Copilot subscription.

    - Assign: Purchases Copilot seats for the specified users.
    - Remove: Sets seats to "pending cancellation" — the license remains
      active until the end of the current billing cycle.

    Requires org owner or billing manager permissions.

.PARAMETER Org
    The GitHub organization name (case-insensitive).

.PARAMETER Action
    The action to perform: Assign or Remove.

.PARAMETER Users
    One or more GitHub usernames to assign or remove.

.PARAMETER Confirm
    Skip the confirmation prompt (use with caution).

.EXAMPLE
    .\Set-CopilotLicense.ps1 -Org fhemmer -Action Assign -Users "newuser1","newuser2"

.EXAMPLE
    .\Set-CopilotLicense.ps1 -Org fhemmer -Action Remove -Users "inactiveuser"

.EXAMPLE
    .\Set-CopilotLicense.ps1 -Org relias-engineering -Action Remove -Users "user1" -Confirm
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Org,

    [Parameter(Mandatory)]
    [ValidateSet('Assign', 'Remove')]
    [string]$Action,

    [Parameter(Mandatory)]
    [string[]]$Users,

    [Alias('Force')]
    [switch]$Confirm
)

$InformationPreference = 'Continue'

# Display intent
$actionVerb = if ($Action -eq 'Assign') { 'ASSIGN licenses to' } else { 'REMOVE licenses from' }
$actionColor = if ($Action -eq 'Assign') { '32' } else { '33' }

Write-Information ""
Write-Information "`e[${actionColor}m╔═══════════════════════════════════════════════════════╗`e[0m"
Write-Information "`e[${actionColor}m║  Copilot License — $Action`e[0m"
Write-Information "`e[${actionColor}m║  Org: $Org`e[0m"
Write-Information "`e[${actionColor}m║  Users: $($Users.Count)`e[0m"
Write-Information "`e[${actionColor}m╚═══════════════════════════════════════════════════════╝`e[0m"
Write-Information ""

Write-Information "Will $actionVerb the following users:"
foreach ($user in $Users) {
    Write-Information "  - $user"
}
Write-Information ""

# Confirmation
if (-not $Confirm) {
    $response = Read-Host "Proceed? (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Information "`e[33mAborted.`e[0m"
        exit 0
    }
}

# Build the request body
$body = @{ selected_usernames = $Users } | ConvertTo-Json -Compress

# Execute the API call
$endpoint = "/orgs/$Org/copilot/billing/selected_users"

if ($Action -eq 'Assign') {
    $apiResponse = $body | gh api $endpoint --method POST --input - 2>&1
} else {
    $apiResponse = $body | gh api $endpoint --method DELETE --input - 2>&1
}

if ($LASTEXITCODE -ne 0) {
    Write-Error "API call failed: $apiResponse"
    exit 1
}

$result = $apiResponse | ConvertFrom-Json

if ($Action -eq 'Assign') {
    $count = $result.seats_created
    Write-Information "`e[32m✓ Successfully assigned $count Copilot seat(s).`e[0m"
} else {
    $count = $result.seats_cancelled
    Write-Information "`e[33m✓ $count seat(s) set to pending cancellation.`e[0m"
    Write-Information "`e[90m  Licenses remain active until the end of the current billing cycle.`e[0m"
}

Write-Information ""
