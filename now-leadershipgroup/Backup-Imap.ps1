<#
.SYNOPSIS
    Back up all email from hemmer.us IMAP to local .eml files.
.DESCRIPTION
    Downloads every message from every folder for a hemmer.us mailbox.
    Uses MailKit (same libraries as the mail skill).
    Each message is saved as {folder}/{uid}.eml.
.PARAMETER User
    Email address to back up (e.g., franz@hemmer.us or rebecca@hemmer.us).
.PARAMETER Password
    IMAP password for the account.
.PARAMETER OutputDir
    Directory to save .eml files. Defaults to ./imap-backup/{username}.
.PARAMETER Credential
    PSCredential for the IMAP account. If not provided, you will be prompted.
.EXAMPLE
    pwsh -File Backup-Imap.ps1 -User franz@hemmer.us
#>
param(
    [Parameter(Mandatory)]
    [string]$User,

    [PSCredential]$Credential,

    [string]$OutputDir
)

$ErrorActionPreference = 'Stop'

# If no credential provided, prompt or build from env var
if (-not $Credential) {
    $imapPass = [Environment]::GetEnvironmentVariable("IMAP_HEMMER_PASS", "User")
    if (-not $imapPass) { $imapPass = $env:IMAP_HEMMER_PASS }
    if ($imapPass) {
        $netCred = [System.Net.NetworkCredential]::new($User, $imapPass)
        $Credential = [PSCredential]::new($User, $netCred.SecurePassword)
    }
    else {
        $Credential = Get-Credential -UserName $User -Message "Enter IMAP password for $User"
    }
}
$PlainPass = $Credential.GetNetworkCredential().Password

$Host_ = "mail.hemmer.us"
$Port = 993

# Derive output directory from username if not specified
if (-not $OutputDir) {
    $username = $User.Split('@')[0]
    $OutputDir = Join-Path $PSScriptRoot "imap-backup\$username"
}

# Load MailKit assemblies
$packagesPath = Join-Path (Split-Path -Parent $PSScriptRoot) "mail\packages"
$bouncyCastlePath = Join-Path $packagesPath "BouncyCastle.Cryptography.dll"
$mimeKitPath = Join-Path $packagesPath "MimeKit.dll"
$mailKitPath = Join-Path $packagesPath "MailKit.dll"

foreach ($dll in @($bouncyCastlePath, $mimeKitPath, $mailKitPath)) {
    $name = [System.IO.Path]::GetFileNameWithoutExtension($dll)
    if (-not ([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq $name })) {
        Add-Type -Path $dll
    }
}

Write-Host "Connecting to $Host_`:$Port as $User..."
$client = [MailKit.Net.Imap.ImapClient]::new()
$client.Connect($Host_, $Port, [MailKit.Security.SecureSocketOptions]::SslOnConnect)
$client.Authenticate($User, $PlainPass)
Write-Host "Connected and authenticated."

# Get all folders
$personal = $client.GetFolder($client.PersonalNamespaces[0])
$allFolders = @($client.Inbox)

function Get-SubfolderTree($parent) {
    try {
        $children = $parent.GetSubfolders($false, [System.Threading.CancellationToken]::None)
        foreach ($child in $children) {
            $script:allFolders += $child
            Get-SubfolderTree $child
        }
    }
    catch {
        Write-Warning "Could not enumerate subfolders of $($parent.FullName): $($_.Exception.Message)"
    }
}
Get-SubfolderTree $personal

Write-Host "Found $($allFolders.Count) folder(s):"
foreach ($f in $allFolders) {
    Write-Host "  - $($f.FullName)"
}

$totalMessages = 0
$totalDownloaded = 0

foreach ($folder in $allFolders) {
    try {
        $folder.Open([MailKit.FolderAccess]::ReadOnly) | Out-Null
    }
    catch {
        Write-Host "  Skipping $($folder.FullName) (cannot open)"
        continue
    }

    $count = $folder.Count
    $totalMessages += $count
    if ($count -eq 0) {
        Write-Host "  $($folder.FullName): 0 messages"
        $folder.Close($false)
        continue
    }

    # Sanitize folder name for filesystem
    $safeName = $folder.FullName -replace '[\\/:*?"<>|]', '_'
    $folderDir = Join-Path $OutputDir $safeName
    if (-not (Test-Path $folderDir)) {
        New-Item -ItemType Directory -Path $folderDir -Force | Out-Null
    }

    Write-Host "  $($folder.FullName): $count messages..."

    # Fetch all UIDs
    $allQuery = [MailKit.Search.SearchQuery]::All
    $uids = $folder.Search($allQuery)

    $downloaded = 0
    foreach ($uid in $uids) {
        $emlPath = Join-Path $folderDir "$($uid.Id).eml"

        # Skip if already downloaded (resume support)
        if (Test-Path $emlPath) {
            $downloaded++
            continue
        }

        try {
            $message = $folder.GetMessage($uid, [System.Threading.CancellationToken]::None)
            $message.WriteTo($emlPath)
            $downloaded++
            $totalDownloaded++

            if ($downloaded % 50 -eq 0) {
                Write-Host "    $downloaded / $count"
            }
        }
        catch {
            Write-Host "    FAILED uid=$($uid.Id): $($_.Exception.Message)"
        }
    }

    Write-Host "    Done: $downloaded / $count downloaded"
    $folder.Close($false)
}

$client.Disconnect($true)
$client.Dispose()

Write-Host ""
Write-Host "=== Backup Complete ==="
Write-Host "Account:    $User"
Write-Host "Output:     $OutputDir"
Write-Host "Folders:    $($allFolders.Count)"
Write-Host "Messages:   $totalMessages"
Write-Host "Downloaded: $totalDownloaded (new)"
Write-Host "Skipped:    $($totalMessages - $totalDownloaded) (already existed)"
