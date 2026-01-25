#Requires -Version 7.0

<#
.SYNOPSIS
    Gets the count of repositories in a Bitbucket workspace.

.DESCRIPTION
    Retrieves the total count of repositories in the specified Bitbucket workspace
    using the Bitbucket REST API v2.0.

.PARAMETER Workspace
    The Bitbucket workspace name (e.g., "relias"). Defaults to "relias".

.PARAMETER Username
    Bitbucket username/email. If not provided, reads from BITBUCKET_USERNAME environment variable.

.PARAMETER ApiKey
    Bitbucket API key/app password. If not provided, reads from BITBUCKET_API_KEY environment variable.

.EXAMPLE
    Get-BitbucketRepoCount -Workspace relias

.EXAMPLE
    Get-BitbucketRepoCount -Workspace relias -Username fhemmer@relias.com -ApiKey "ATATT..."
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Workspace = "relias",

    [Parameter(Mandatory = $false)]
    [string]$Username,

    [Parameter(Mandatory = $false)]
    [string]$ApiKey
)

# Load credentials from environment if not provided
# Check Process scope first (current session), then User scope (persistent)
if (-not $Username) {
    $Username = [System.Environment]::GetEnvironmentVariable('BITBUCKET_USERNAME', 'Process')
    if (-not $Username) {
        $Username = [System.Environment]::GetEnvironmentVariable('BITBUCKET_USERNAME', 'User')
    }
}

if (-not $ApiKey) {
    $ApiKey = [System.Environment]::GetEnvironmentVariable('BITBUCKET_API_KEY', 'Process')
    if (-not $ApiKey) {
        $ApiKey = [System.Environment]::GetEnvironmentVariable('BITBUCKET_API_KEY', 'User')
    }
}

# Validate credentials
if (-not $Username -or -not $ApiKey) {
    Write-Error "Bitbucket credentials not found. Please set BITBUCKET_USERNAME and BITBUCKET_API_KEY environment variables or provide them as parameters."
    exit 1
}

# Create Basic Auth header
$credentials = "${Username}:${ApiKey}"
$base64 = [Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credentials))
$headers = @{
    Authorization = "Basic $base64"
}

# Bitbucket API v2.0 endpoint for repositories
$baseUrl = "https://api.bitbucket.org/2.0"
$url = "$baseUrl/repositories/$Workspace"

$repoCount = 0
$nextUrl = $url

try {
    # Paginate through all repositories
    while ($nextUrl) {
        $response = Invoke-RestMethod -Uri $nextUrl -Method Get -Headers $headers -ErrorAction Stop

        if ($response.values) {
            $repoCount += $response.values.Count
        }

        # Check for next page
        $nextUrl = $response.next
    }

    Write-Output $repoCount
}
catch {
    Write-Error "Failed to retrieve Bitbucket repositories: $_"
    exit 1
}
