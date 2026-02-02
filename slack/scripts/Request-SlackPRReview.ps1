<#
.SYNOPSIS
    Posts a PR review request to a Slack channel with proper formatting.

.DESCRIPTION
    Creates a beautifully formatted Block Kit message requesting PR reviews.
    Handles PowerShell escape sequences properly (backticks in repo names).

.PARAMETER Channel
    The Slack channel ID or name to post to.

.PARAMETER RepoName
    The repository name (will be formatted as bold, NOT backticks to avoid `r escape issue).

.PARAMETER PRs
    Array of hashtables with 'Number', 'Title', and 'Url' keys.

.PARAMETER Message
    Optional custom message. Defaults to "PRs ready for review".

.EXAMPLE
    $prs = @(
        @{ Number = 18; Title = "Part 1 - Low complexity"; Url = "https://github.com/org/repo/pull/18" }
        @{ Number = 20; Title = "Part 2 - Medium complexity"; Url = "https://github.com/org/repo/pull/20" }
    )
    .\Request-SlackPRReview.ps1 -Channel "C09LB1CM1BK" -RepoName "relias-assistant" -PRs $prs

.NOTES
    LESSON LEARNED: Never use backticks for code formatting in PowerShell strings!
    PowerShell interprets `r as carriage return, `n as newline, etc.
    Use *bold* or _italic_ instead for emphasis in Slack mrkdwn.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Channel,

    [Parameter(Mandatory = $true)]
    [string]$RepoName,

    [Parameter(Mandatory = $true)]
    [hashtable[]]$PRs,

    [Parameter(Mandatory = $false)]
    [string]$Message = "PRs ready for review"
)

$ErrorActionPreference = "Stop"

# Build PR list - use *bold* not `backticks` to avoid PowerShell escape issues
$prList = ($PRs | ForEach-Object {
    "• *PR #$($_.Number)*: <$($_.Url)|$($_.Title)>"
}) -join "`n"

$headers = @{
    "Authorization" = "Bearer $env:SLACK_TOKEN"
    "Content-Type"  = "application/json; charset=utf-8"
}

$body = @{
    channel = $Channel
    text    = "PR Review Request - $Message for $RepoName"
    blocks  = @(
        @{
            type = "header"
            text = @{ type = "plain_text"; text = "🔍 PR Review Request"; emoji = $true }
        }
        @{
            type = "section"
            # Use *bold* instead of `backticks` for repo name - avoids `r escape issue
            text = @{ type = "mrkdwn"; text = "$Message for *$RepoName*:" }
        }
        @{
            type = "section"
            text = @{ type = "mrkdwn"; text = $prList }
        }
        @{ type = "divider" }
        @{
            type     = "context"
            elements = @(
                @{ type = "mrkdwn"; text = "Posted by <@U2XMZDPJ7> • $(Get-Date -Format 'MMM d, yyyy')" }
            )
        }
    )
} | ConvertTo-Json -Depth 10

$response = Invoke-RestMethod -Uri "https://slack.com/api/chat.postMessage" -Headers $headers -Method Post -Body $body

if ($response.ok) {
    Write-Host "✓ Posted to channel $Channel" -ForegroundColor Green
    Write-Host "  Message ts: $($response.ts)" -ForegroundColor Gray
}
else {
    Write-Error "Failed to post: $($response.error)"
}
