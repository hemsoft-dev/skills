<#
.SYNOPSIS
    IMAP authentication and connection helper for hemmer.us account.
.DESCRIPTION
    Provides functions to connect to IMAP server using MailKit.
    Credentials from environment variables:
    - IMAP_HEMMER_HOST (e.g., mail.hemmer.us)
    - IMAP_HEMMER_PORT (default: 993)
    - IMAP_HEMMER_USER (email address)
    - IMAP_HEMMER_PASS (password or app password)
#>

$ErrorActionPreference = 'Stop'

# Load MailKit assemblies from packages folder
$packagesPath = Join-Path (Split-Path -Parent $PSScriptRoot) "packages"
$bouncyCastlePath = Join-Path $packagesPath "BouncyCastle.Cryptography.dll"
$mimeKitPath = Join-Path $packagesPath "MimeKit.dll"
$mailKitPath = Join-Path $packagesPath "MailKit.dll"

# Load in dependency order
if (-not ([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'BouncyCastle.Cryptography' })) {
    Add-Type -Path $bouncyCastlePath
}
if (-not ([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'MimeKit' })) {
    Add-Type -Path $mimeKitPath
}
if (-not ([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'MailKit' })) {
    Add-Type -Path $mailKitPath
}

function Test-ImapConfigured {
    <#
    .SYNOPSIS
        Check if IMAP credentials are configured.
    #>
    $host_ = $env:IMAP_HEMMER_HOST
    $user = $env:IMAP_HEMMER_USER
    $pass = $env:IMAP_HEMMER_PASS
    
    return ($host_ -and $user -and $pass)
}

function Get-ImapConfig {
    <#
    .SYNOPSIS
        Get IMAP configuration from environment.
    #>
    @{
        Host = $env:IMAP_HEMMER_HOST
        Port = if ($env:IMAP_HEMMER_PORT) { [int]$env:IMAP_HEMMER_PORT } else { 993 }
        User = $env:IMAP_HEMMER_USER
        Pass = $env:IMAP_HEMMER_PASS
    }
}

function Connect-Imap {
    <#
    .SYNOPSIS
        Connect to IMAP server and return authenticated client.
    .OUTPUTS
        MailKit.Net.Imap.ImapClient - Connected and authenticated client.
    #>
    $config = Get-ImapConfig
    
    $client = [MailKit.Net.Imap.ImapClient]::new()
    $client.Connect($config.Host, $config.Port, [MailKit.Security.SecureSocketOptions]::SslOnConnect)
    $client.Authenticate($config.User, $config.Pass)
    
    return $client
}

function Disconnect-Imap {
    <#
    .SYNOPSIS
        Safely disconnect IMAP client.
    .PARAMETER Client
        The ImapClient to disconnect.
    #>
    param([MailKit.Net.Imap.ImapClient]$Client)
    
    if ($Client -and $Client.IsConnected) {
        $Client.Disconnect($true)
    }
    if ($Client) {
        $Client.Dispose()
    }
}

function Get-ImapMessages {
    <#
    .SYNOPSIS
        Fetch messages from IMAP inbox.
    .PARAMETER Client
        Connected ImapClient.
    .PARAMETER Query
        MailKit SearchQuery (e.g., [MailKit.Search.SearchQuery]::NotSeen).
    .PARAMETER Count
        Maximum messages to return.
    .OUTPUTS
        Array of message summary objects.
    #>
    param(
        [MailKit.Net.Imap.ImapClient]$Client,
        [MailKit.Search.SearchQuery]$Query,
        [int]$Count = 10
    )
    
    $inbox = $Client.Inbox
    $inbox.Open([MailKit.FolderAccess]::ReadOnly) | Out-Null
    
    $uids = $inbox.Search($Query)
    
    # Get most recent first (reverse order), convert to List<UniqueId>
    $uidList = [System.Collections.Generic.List[MailKit.UniqueId]]::new()
    $uids | Sort-Object { $_.Id } -Descending | Select-Object -First $Count | ForEach-Object { $uidList.Add($_) }
    
    if ($uidList.Count -eq 0) {
        return @()
    }
    
    # Fetch summaries with envelope info using FetchRequest
    $request = [MailKit.FetchRequest]::new(
        [MailKit.MessageSummaryItems]::Envelope -bor 
        [MailKit.MessageSummaryItems]::Flags -bor 
        [MailKit.MessageSummaryItems]::UniqueId
    )
    $summaries = $inbox.Fetch($uidList, $request, [System.Threading.CancellationToken]::None)
    
    $messages = @()
    foreach ($summary in $summaries) {
        $from = if ($summary.Envelope.From.Count -gt 0) {
            $addr = $summary.Envelope.From[0]
            if ($addr.Name) { "$($addr.Name) <$($addr.Address)>" } else { $addr.Address }
        } else { "Unknown" }
        
        $isUnread = -not ($summary.Flags -band [MailKit.MessageFlags]::Seen)
        
        $dateStr = ""
        if ($summary.Envelope.Date -and $summary.Envelope.Date.HasValue) {
            $dateStr = $summary.Envelope.Date.Value.LocalDateTime.ToString("g")
        }
        
        $messages += @{
            id      = $summary.UniqueId.Id.ToString()
            subject = if ($summary.Envelope.Subject) { $summary.Envelope.Subject } else { "(no subject)" }
            from    = $from
            date    = $dateStr
            status  = if ($isUnread) { "NEW" } else { "Read" }
        }
    }
    
    return ,$messages
}
