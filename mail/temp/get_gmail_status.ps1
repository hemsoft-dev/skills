param(
    [Parameter(Mandatory=$false)]
    [string]$MessageId = '19b3828cfee82924'
)

$ErrorActionPreference = 'Stop'
$LibPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'lib'
. (Join-Path $LibPath 'gmail-auth.ps1')

if (-not (Test-GmailConfigured)) { throw 'Gmail not configured. Set GMAIL_CLIENT_ID and GMAIL_CLIENT_SECRET.' }

$accessToken = Get-GmailAccessToken
if (-not $accessToken) { throw 'Failed to get access token.' }

$details = Get-GmailMessageDetails -AccessToken $accessToken -MessageId $MessageId -Format 'metadata'
$labels = $details.labelIds
$status = if ($labels -contains 'UNREAD') { 'NEW' } else { 'Read' }

@{
    id = $MessageId
    labels = $labels
    status = $status
    snippet = ($details.snippet ?? '')
} | ConvertTo-Json -Depth 5
