#requires -Version 5.1
<#
.SYNOPSIS
  Fetch SonarCloud (SonarQube Cloud) issues for a pull request or branch.

.DESCRIPTION
  Uses the machine environment variable SONAR_TOKEN for HTTP Basic auth.
  Defaults to the Relias configurator project.

.EXAMPLE
  pwsh -File Get-SonarIssues.ps1 -PullRequest 49

.EXAMPLE
  pwsh -File Get-SonarIssues.ps1 -Branch main -ProjectKey relias-engineering_configurator
#>
[CmdletBinding(DefaultParameterSetName = 'PR')]
param(
    [Parameter(ParameterSetName = 'PR', Mandatory = $true)]
    [int]$PullRequest,

    [Parameter(ParameterSetName = 'Branch')]
    [string]$Branch,

    [string]$ProjectKey = 'relias-engineering_configurator',
    [string]$SonarHost = 'https://sonarcloud.io',
    [switch]$IncludeResolved
)

$ErrorActionPreference = 'Stop'

$tok = [Environment]::GetEnvironmentVariable('SONAR_TOKEN', 'Machine')
if (-not $tok) { $tok = $env:SONAR_TOKEN }
if (-not $tok) {
    Write-Error "SONAR_TOKEN not found. Set it as a machine env var or process env var. Generate one at $SonarHost/account/security"
    return
}

$b64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($tok):"))
$headers = @{ Authorization = "Basic $b64" }

$resolved = if ($IncludeResolved) { '' } else { '&resolved=false' }
$scope = if ($PSCmdlet.ParameterSetName -eq 'PR') { "pullRequest=$PullRequest" }
         elseif ($Branch) { "branch=$Branch" } else { '' }

$url = "$SonarHost/api/issues/search?componentKeys=$ProjectKey&$scope$resolved&ps=100"

try {
    $r = Invoke-RestMethod -Uri $url -Headers $headers -ErrorAction Stop
}
catch {
    Write-Error "SonarCloud API error: $($_.Exception.Message)"
    if ($_.ErrorDetails) { Write-Host $_.ErrorDetails.Message }
    return
}

Write-Host "TOTAL ISSUES: $($r.total)" -ForegroundColor Cyan
$r.issues |
    Select-Object severity, type, rule,
        @{n = 'file'; e = { $_.component -replace '.*:', '' } },
        line, message |
    Format-Table -AutoSize -Wrap

# Return raw objects too for further processing
$r.issues
