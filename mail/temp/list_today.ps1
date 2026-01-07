$ErrorActionPreference = 'Stop'

$lib = Join-Path (Split-Path -Parent $PSScriptRoot) 'lib'
. (Join-Path $lib 'imap-auth.ps1')

$client = Connect-Imap
try {
    $inbox = $client.Inbox
    $inbox.Open([MailKit.FolderAccess]::ReadOnly) | Out-Null
    $searchQuery = [MailKit.Search.SearchQuery]::And(
        [MailKit.Search.SearchQuery]::DeliveredAfter((Get-Date).Date),
        [MailKit.Search.SearchQuery]::DeliveredBefore((Get-Date).AddDays(1))
    )

    $messages = Get-ImapMessages -Client $client -Query $searchQuery -Count 10

    $messages | ConvertTo-Json -Depth 5
}
finally {
    Disconnect-Imap -Client $client
}