<#
.SYNOPSIS
    Backs up Git configuration and SSH keys to this folder.
.DESCRIPTION
    Copies .gitconfig and .ssh folder contents (excluding private keys by default).
    Private keys should be backed up separately via secure means.
#>

[CmdletBinding()]
param(
    [switch]$IncludePrivateKeys
)

$InformationPreference = 'Continue'

$backupDir = $PSScriptRoot
$gitConfig = "$env:USERPROFILE\.gitconfig"
$sshDir = "$env:USERPROFILE\.ssh"

Write-Information "[36mBacking up Git configuration...`e[0m"

# Backup .gitconfig
if (Test-Path $gitConfig) {
    Copy-Item $gitConfig -Destination (Join-Path $backupDir ".gitconfig") -Force
    Write-Information "[32m  ✓ .gitconfig`e[0m"
}
else {
    Write-Warning "  .gitconfig not found"
}

# Backup SSH config and public keys
if (Test-Path $sshDir) {
    $sshBackupDir = Join-Path $backupDir "ssh"
    if (-not (Test-Path $sshBackupDir)) {
        New-Item -Path $sshBackupDir -ItemType Directory -Force | Out-Null
    }
    
    # Always backup config and public keys
    @("config", "known_hosts", "*.pub") | ForEach-Object {
        Get-ChildItem "$sshDir\$_" -ErrorAction SilentlyContinue | ForEach-Object {
            Copy-Item $_.FullName -Destination $sshBackupDir -Force
            Write-Information "[32m  ✓ ssh/$($_.Name)`e[0m"
        }
    }
    
    # Optionally backup private keys (use with caution!)
    if ($IncludePrivateKeys) {
        Write-Warning "Including private keys - ensure this backup is secure!"
        Get-ChildItem $sshDir -File | Where-Object { 
            $_.Name -notmatch '\.pub$' -and $_.Name -notin @("config", "known_hosts", "known_hosts.old")
        } | ForEach-Object {
            Copy-Item $_.FullName -Destination $sshBackupDir -Force
            Write-Information "[33m  ✓ ssh/$($_.Name) (PRIVATE KEY)`e[0m"
        }
    }
}
else {
    Write-Warning "  .ssh folder not found"
}

Write-Information "[32mGit backup complete!`e[0m"
