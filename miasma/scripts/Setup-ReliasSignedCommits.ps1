[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter()]
    [string]$WorkRoot = 'D:\github\Relias',

    [Parameter()]
    [string]$WorkValidationRepo = 'D:\github\Relias\org-metrics',

    [Parameter()]
    [string]$PersonalValidationRepo = 'D:\github\hemsoft\codexbar',

    [Parameter()]
    [string]$ReliasEmail = 'fhemmer@relias.com',

    [Parameter()]
    [string]$SigningKeyPath = (Join-Path $HOME '.ssh\id_ed25519_relias_git_signing'),

    [Parameter()]
    [string]$AllowedSignersPath = (Join-Path $HOME '.ssh\allowed-signers'),

    [Parameter()]
    [string]$GitConfigPath = (Join-Path $HOME '.gitconfig-relias'),

    [Parameter()]
    [string]$GitHubKeyTitle = "Relias Git signing $([Environment]::MachineName)",

    [Parameter()]
    [switch]$SkipGitHubUpload,

    [Parameter()]
    [switch]$ConfigureOnly,

    [Parameter()]
    [switch]$PreflightOnly
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function ConvertTo-FullPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathValue
    )

    if ($PathValue -eq '~') {
        $expanded = $HOME
    }
    elseif ($PathValue.StartsWith('~/') -or $PathValue.StartsWith('~\')) {
        $expanded = Join-Path $HOME $PathValue.Substring(2)
    }
    else {
        $expanded = $PathValue
    }

    try {
        return (Resolve-Path -LiteralPath $expanded -ErrorAction Stop).Path
    }
    catch {
        return [System.IO.Path]::GetFullPath($expanded)
    }
}

function ConvertTo-GitPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathValue
    )

    $fullPath = ConvertTo-FullPath -PathValue $PathValue
    $gitPath = $fullPath.Replace('\', '/')
    if (-not $gitPath.EndsWith('/')) {
        $gitPath = "$gitPath/"
    }

    return $gitPath
}

function Get-HomeRelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathValue
    )

    $fullPath = ConvertTo-FullPath -PathValue $PathValue
    $homePath = (ConvertTo-FullPath -PathValue $HOME).TrimEnd('\')
    if ($fullPath.StartsWith("$homePath\", [System.StringComparison]::OrdinalIgnoreCase)) {
        return "~/$($fullPath.Substring($homePath.Length + 1).Replace('\', '/'))"
    }

    return $fullPath
}

function Invoke-RequiredCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [Parameter(Mandatory = $true)]
        [string]$FailureMessage
    )

    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw $FailureMessage
    }
}

function Get-SshIdentityFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        return @()
    }

    $identityFiles = @()
    foreach ($line in Get-Content -LiteralPath $ConfigPath) {
        if ($line -match '^\s*IdentityFile\s+(.+?)\s*(?:#.*)?$') {
            $identityPath = $Matches[1].Trim().Trim('"')
            $identityFiles += ConvertTo-FullPath -PathValue $identityPath
        }
    }

    return $identityFiles
}

function Get-GitConfigValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoPath,

        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    if (-not (Test-Path -LiteralPath (Join-Path $RepoPath '.git'))) {
        return $null
    }

    $value = & git -C $RepoPath config --show-origin --get $Key 2>$null
    if ($LASTEXITCODE -eq 1) {
        return $null
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to read Git config key '$Key' in $RepoPath."
    }

    return $value
}

function Assert-GitHubSigningKeyScope {
    $probe = & gh api 'user/ssh_signing_keys?per_page=1' 2>&1
    if ($LASTEXITCODE -eq 0) {
        return
    }

    $probeText = ($probe | Out-String).Trim()
    if ($probeText -match 'admin:ssh_signing_key' -or $probeText -match 'HTTP 404') {
        throw "GitHub CLI auth is missing the admin:ssh_signing_key scope. Run: gh auth refresh -h github.com -s admin:ssh_signing_key"
    }

    throw "Unable to verify GitHub signing-key API access: $probeText"
}

foreach ($commandName in @('git', 'ssh-keygen')) {
    if (-not (Get-Command $commandName -ErrorAction SilentlyContinue)) {
        throw "$commandName is required."
    }
}
if (-not $SkipGitHubUpload -and -not $PreflightOnly -and -not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'GitHub CLI (gh) is required unless -SkipGitHubUpload is used.'
}
if (-not $SkipGitHubUpload -and -not $PreflightOnly) {
    Assert-GitHubSigningKeyScope
}

$privateKeyPath = ConvertTo-FullPath -PathValue $SigningKeyPath
$publicKeyPath = "$privateKeyPath.pub"
$allowedSignersFullPath = ConvertTo-FullPath -PathValue $AllowedSignersPath
$gitConfigFullPath = ConvertTo-FullPath -PathValue $GitConfigPath
$sshDirectory = Split-Path -Parent $privateKeyPath
$sshConfigPath = Join-Path $HOME '.ssh\config'
$authIdentityFiles = Get-SshIdentityFile -ConfigPath $sshConfigPath
$usesAuthKeyAsSigningKey = $authIdentityFiles -contains $privateKeyPath

if ($usesAuthKeyAsSigningKey) {
    throw "Signing key path matches an SSH authentication IdentityFile. Choose a dedicated signing key path: $privateKeyPath"
}

$includePattern = ConvertTo-GitPath -PathValue $WorkRoot
$includeKey = "includeIf.gitdir:$includePattern.path"
$includeTarget = Get-HomeRelativePath -PathValue $gitConfigFullPath
$workCommitSigning = Get-GitConfigValue -RepoPath $WorkValidationRepo -Key 'commit.gpgsign'
$workSigningKey = Get-GitConfigValue -RepoPath $WorkValidationRepo -Key 'user.signingkey'
$personalCommitSigning = Get-GitConfigValue -RepoPath $PersonalValidationRepo -Key 'commit.gpgsign'

if ($PreflightOnly) {
    return [pscustomobject]@{
        WorkRoot = $WorkRoot
        WorkValidationRepo = $WorkValidationRepo
        PersonalValidationRepo = $PersonalValidationRepo
        SigningPrivateKeyPath = $privateKeyPath
        SigningPublicKeyPath = $publicKeyPath
        SigningPrivateKeyExists = Test-Path -LiteralPath $privateKeyPath
        SigningPublicKeyExists = Test-Path -LiteralPath $publicKeyPath
        SigningKeyConflictsWithAuthKey = $usesAuthKeyAsSigningKey
        IncludeKey = $includeKey
        IncludeTarget = $includeTarget
        WorkCommitSigning = $workCommitSigning
        WorkSigningKey = $workSigningKey
        PersonalCommitSigning = $personalCommitSigning
    }
}

if (-not (Test-Path -LiteralPath $sshDirectory)) {
    New-Item -ItemType Directory -Path $sshDirectory -Force | Out-Null
}

if (-not (Test-Path -LiteralPath $privateKeyPath)) {
    if ($ConfigureOnly) {
        throw "Signing private key not found: $privateKeyPath"
    }

    Write-Host "Creating a dedicated Relias SSH signing key. Enter a passphrase when ssh-keygen prompts."
    Invoke-RequiredCommand `
        -Command 'ssh-keygen' `
        -Arguments @('-t', 'ed25519', '-f', $privateKeyPath, '-C', "$ReliasEmail git signing $([Environment]::MachineName)") `
        -FailureMessage "Failed to create signing key: $privateKeyPath"
}

if (-not (Test-Path -LiteralPath $publicKeyPath)) {
    $publicKeyMaterial = & ssh-keygen -y -f $privateKeyPath
    if ($LASTEXITCODE -ne 0 -or -not $publicKeyMaterial) {
        throw "Failed to derive public key from $privateKeyPath"
    }

    Set-Content -LiteralPath $publicKeyPath -Value $publicKeyMaterial
}

$publicKey = (Get-Content -LiteralPath $publicKeyPath -Raw).Trim()
if (-not $publicKey.StartsWith('ssh-ed25519 ')) {
    throw "Expected an Ed25519 public signing key at $publicKeyPath"
}

if (-not $SkipGitHubUpload) {
    Invoke-RequiredCommand `
        -Command 'gh' `
        -Arguments @('ssh-key', 'add', $publicKeyPath, '--type', 'signing', '--title', $GitHubKeyTitle) `
        -FailureMessage "Failed to upload signing public key to GitHub. If gh reported a missing admin:ssh_signing_key scope, run: gh auth refresh -h github.com -s admin:ssh_signing_key. If the key already exists, rerun with -SkipGitHubUpload."
}

$allowedLine = "$ReliasEmail $publicKey"
if (Test-Path -LiteralPath $allowedSignersFullPath) {
    $allowedSigners = @(Get-Content -LiteralPath $allowedSignersFullPath)
    if ($allowedSigners -notcontains $allowedLine) {
        Add-Content -LiteralPath $allowedSignersFullPath -Value $allowedLine
    }
}
else {
    Set-Content -LiteralPath $allowedSignersFullPath -Value $allowedLine
}

Invoke-RequiredCommand `
    -Command 'git' `
    -Arguments @('config', '--global', $includeKey, $includeTarget) `
    -FailureMessage "Failed to configure global work-root include: $includeKey"

$publicKeyConfigPath = Get-HomeRelativePath -PathValue $publicKeyPath
$allowedSignersConfigPath = Get-HomeRelativePath -PathValue $allowedSignersFullPath
$gitConfigValues = [ordered]@{
    'user.email' = $ReliasEmail
    'gpg.format' = 'ssh'
    'user.signingkey' = $publicKeyConfigPath
    'commit.gpgsign' = 'true'
    'gpg.ssh.allowedSignersFile' = $allowedSignersConfigPath
}

foreach ($entry in $gitConfigValues.GetEnumerator()) {
    Invoke-RequiredCommand `
        -Command 'git' `
        -Arguments @('config', '--file', $gitConfigFullPath, $entry.Key, $entry.Value) `
        -FailureMessage "Failed to set $($entry.Key) in $gitConfigFullPath"
}

[pscustomobject]@{
    WorkRoot = $WorkRoot
    IncludeKey = $includeKey
    IncludeTarget = $includeTarget
    GitConfigPath = $gitConfigFullPath
    SigningPublicKeyPath = $publicKeyPath
    AllowedSignersPath = $allowedSignersFullPath
    WorkCommitSigning = Get-GitConfigValue -RepoPath $WorkValidationRepo -Key 'commit.gpgsign'
    WorkSigningKey = Get-GitConfigValue -RepoPath $WorkValidationRepo -Key 'user.signingkey'
    PersonalCommitSigning = Get-GitConfigValue -RepoPath $PersonalValidationRepo -Key 'commit.gpgsign'
}
