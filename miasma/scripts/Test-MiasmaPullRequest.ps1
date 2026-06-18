[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter()]
    [string]$Organization = 'relias-engineering',

    [Parameter()]
    [Alias('RepositoryName')]
    [string]$Repo,

    [Parameter()]
    [Alias('PullRequestNumber', 'Number')]
    [int]$PR,

    [Parameter()]
    [Alias('Url')]
    [string]$PullRequestUrl,

    [Parameter()]
    [Alias('KnownCommit', 'OrphanedCommit')]
    [string[]]$AdditionalCommit,

    [Parameter()]
    [string]$ResumeAfter,

    [Parameter()]
    [Alias('ClosedDate')]
    [datetime]$ClosedSince = ([datetime]'2026-06-15'),

    [Parameter()]
    [ValidateRange(1024, 5242880)]
    [int]$MaxBlobBytes = 1048576,

    [Parameter()]
    [switch]$Json,

    [Parameter()]
    [switch]$Report,

    [switch]$RegenerateReport,

    [Parameter()]
    [switch]$FailOnFinding,

    [Parameter()]
    [switch]$Help
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
    $PSNativeCommandUseErrorActionPreference = $false
}

function Show-Help {
    @'
Test-MiasmaPullRequest.ps1

Default:
  .\scripts\Test-MiasmaPullRequest.ps1
  Lists PRs closed since June 15, 2026 in all repositories under relias-engineering, then asks for confirmation before scanning multiple repos.

Single repo:
  .\scripts\Test-MiasmaPullRequest.ps1 -Repo example-repo

Single PR:
  .\scripts\Test-MiasmaPullRequest.ps1 -Repo example-repo -PR 123
  .\scripts\Test-MiasmaPullRequest.ps1 -PullRequestUrl https://github.com/relias-engineering/example-repo/pull/123

Options:
  -Organization <org>  Defaults to relias-engineering.
  -Repo <repo>         Repo name, or OWNER/REPO.
  -PR <number>         Pull request number. Requires -Repo because PR numbers are repository-scoped.
  -AdditionalCommit    Known orphaned/extra commit to scan. Use OWNER/REPO@SHA, REPO@SHA, or SHA with -Repo.
  -ResumeAfter         Skip PR targets through this already-checked PR. Use REPO#PR or OWNER/REPO#PR.
  -ClosedSince <date>  Start date used when discovering closed PRs. Defaults to 2026-06-15 and scans forward to now.
  -Verbose             Show scanned branch/base, commit/file counts, payload indicators, progress, and API detail.
  -Json                Emit structured result.
  -Report              Generate a fixed-name HTML report after the scan.
  -RegenerateReport    Rebuild the fixed-name HTML report from the fixed JSON artifact without scanning GitHub.
  -FailOnFinding       Exit 2 when a blocking finding is found.
  -Help                Show this help.
'@
}

if ($Help) {
    Show-Help
    return
}

$apiRequestCount = 0
$lastGhExitCode = 0
$lastGhError = ''
$null = $Repo
$null = $PullRequestUrl
$null = $AdditionalCommit
$null = $ResumeAfter
$null = $MaxBlobBytes
$closedSinceText = $ClosedSince.ToString('yyyy-MM-dd')
$closedQuery = ">=$closedSinceText"
$lastVerboseOwner = ''
$lastVerboseRepository = ''
$payloadVerboseWritten = $false
$lastOutputOwner = ''
$lastOutputRepository = ''
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$skillRoot = Split-Path -Parent $scriptRoot
$artifactDirectory = Join-Path $skillRoot 'output\pr-check'
$jsonOutputPath = Join-Path $artifactDirectory 'miasma-pr-check-results.json'
$htmlOutputPath = Join-Path $artifactDirectory 'miasma-pr-check-report.html'
$easternTimeZone = [System.TimeZoneInfo]::FindSystemTimeZoneById('Eastern Standard Time')

function ConvertTo-EasternTimestamp {
    param([Parameter(Mandatory)][datetime]$Timestamp)

    $timestampOffset = [datetimeoffset]$Timestamp
    $easternTimestamp = [System.TimeZoneInfo]::ConvertTime($timestampOffset, $script:easternTimeZone)
    return $easternTimestamp.ToString('yyyy-MM-ddTHH:mm:ss.fffzzz')
}

function Invoke-GhApiJson {
    param([Parameter(Mandatory)][string[]]$Arguments)

    $script:apiRequestCount++
    $script:lastGhExitCode = 0
    $script:lastGhError = ''
    $previousErrorActionPreference = $ErrorActionPreference
    $stderrPath = [System.IO.Path]::GetTempFileName()
    try {
        $ErrorActionPreference = 'Continue'
        $raw = & gh api @Arguments 2>$stderrPath
        $script:lastGhExitCode = $LASTEXITCODE
        if (Test-Path -LiteralPath $stderrPath) {
            $script:lastGhError = ((Get-Content -LiteralPath $stderrPath -Raw) -as [string]).Trim()
        }
        if ($LASTEXITCODE -ne 0 -or -not $raw) {
            return $null
        }

        return ($raw -join "`n") | ConvertFrom-Json
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
        Remove-Item -LiteralPath $stderrPath -Force -ErrorAction SilentlyContinue
    }
}

function Get-PaginatedGhApi {
    param([Parameter(Mandatory)][string]$PathWithQuery)

    $pages = Invoke-GhApiJson -Arguments @('--paginate', '--slurp', $PathWithQuery)
    if ($null -eq $pages) {
        if ($script:lastGhExitCode -eq 0) {
            return @()
        }
        throw "GitHub API request failed: $PathWithQuery ExitCode=$script:lastGhExitCode Message=$script:lastGhError"
    }

    $items = [System.Collections.ArrayList]::new()
    foreach ($page in @($pages)) {
        if ($null -eq $page) {
            continue
        }
        foreach ($item in @($page)) {
            if ($null -ne $item) {
                [void]$items.Add($item)
            }
        }
    }

    return @($items)
}

function Invoke-GhJson {
    param([Parameter(Mandatory)][string[]]$Arguments)

    $script:apiRequestCount++
    $script:lastGhExitCode = 0
    $script:lastGhError = ''
    $previousErrorActionPreference = $ErrorActionPreference
    $stderrPath = [System.IO.Path]::GetTempFileName()
    try {
        $ErrorActionPreference = 'Continue'
        $raw = & gh @Arguments 2>$stderrPath
        $script:lastGhExitCode = $LASTEXITCODE
        if (Test-Path -LiteralPath $stderrPath) {
            $script:lastGhError = ((Get-Content -LiteralPath $stderrPath -Raw) -as [string]).Trim()
        }
        if ($LASTEXITCODE -ne 0 -or -not $raw) {
            return $null
        }

        return ($raw -join "`n") | ConvertFrom-Json
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
        Remove-Item -LiteralPath $stderrPath -Force -ErrorAction SilentlyContinue
    }
}

function Get-ClosedPullRequestTarget {
    param(
        [Parameter(Mandatory)][string]$Owner,
        [Parameter()][string]$Repository
    )

    $arguments = @(
        'search',
        'prs',
        '--state',
        'closed',
        '--closed',
        $script:closedQuery,
        '--json',
        'repository,number,state,url,title,closedAt',
        '--limit',
        '1000'
    )

    if ($Repository) {
        $arguments += @('--repo', "$Owner/$Repository")
        Write-Verbose "Searching PRs closed since $script:closedSinceText in $Owner/$Repository"
    }
    else {
        $arguments += @('--owner', $Owner)
        Write-Verbose "Searching PRs closed since $script:closedSinceText in organization $Owner"
    }

    $searchResults = Invoke-GhJson -Arguments $arguments
    if ($null -eq $searchResults) {
        if ($script:lastGhExitCode -eq 0) {
            return @()
        }
        throw "GitHub PR search failed. ExitCode=$script:lastGhExitCode Message=$script:lastGhError"
    }

    $targets = [System.Collections.ArrayList]::new()
    $seen = @{}
    foreach ($searchResult in @($searchResults)) {
        $nameWithOwner = [string]$searchResult.repository.nameWithOwner
        if (-not $nameWithOwner) {
            continue
        }

        $parts = $nameWithOwner.Split('/', 2)
        if ($parts.Count -ne 2) {
            continue
        }

        $number = [int]$searchResult.number
        $key = $nameWithOwner.ToLowerInvariant() + "#$number"
        if ($seen.ContainsKey($key)) {
            continue
        }

        $seen[$key] = $true
        [void]$targets.Add([pscustomobject]@{
                Owner = $parts[0]
                Repository = $parts[1]
                PullRequestNumber = $number
                ClosedAt = [string]$searchResult.closedAt
            })
    }

    return @($targets)
}

function ConvertTo-GitPath {
    param([AllowNull()][string]$Path)

    return ([string]$Path).Replace('\', '/').TrimStart('/')
}

function Get-SeverityRank {
    param([Parameter(Mandatory)][string]$Severity)

    switch ($Severity) {
        'Critical' { return 0 }
        'High' { return 1 }
        'Medium' { return 2 }
        'Info' { return 3 }
        default { return 4 }
    }
}

function Test-ContentScanCandidate {
    param([Parameter(Mandatory)][string]$Path)

    $normalized = ConvertTo-GitPath -Path $Path
    if ($normalized -eq 'binding.gyp') {
        return $true
    }
    if ($normalized -in @(
            '.claude/settings.json',
            '.gemini/settings.json',
            '.cursor/rules/setup.mdc',
            '.vscode/tasks.json',
            'package.json',
            'Gemfile'
        )) {
        return $true
    }
    if ($normalized -like '.github/workflows/*.yml' -or $normalized -like '.github/workflows/*.yaml') {
        return $true
    }

    return $false
}

function Get-ContentCheck {
    return @(
        @{ Severity = 'Critical'; Type = 'Setup command'; Pattern = 'node\s+\.github[\\/]setup\.js' },
        @{ Severity = 'Critical'; Type = 'Miasma marker'; Pattern = 'Miasma[: -]+The Spreading Blight|Spreading Blight' },
        @{ Severity = 'Critical'; Type = 'binding.gyp node execution'; Pattern = '<!\(node\s+index\.js' },
        @{ Severity = 'Critical'; Type = 'package test persistence'; Pattern = '"test"\s*:\s*"node\s+\.github[\\/]setup\.js"' },
        @{ Severity = 'High'; Type = 'package preinstall node index.js'; Pattern = '"preinstall"\s*:\s*"node\s+index\.js"' },
        @{ Severity = 'High'; Type = 'Red Hat wave workflow marker'; Pattern = 'OIDC_PACKAGES|bun\s+run\s+_index\.js' }
    )
}

function Get-PayloadDescription {
    return @(
        'path .github/setup.js',
        'command node .github/setup.js or node .github\setup.js',
        'agent configs .claude/settings.json, .gemini/settings.json, .cursor/rules/setup.mdc',
        'VS Code auto-run config .vscode/tasks.json',
        'binding.gyp node index.js execution',
        'package.json test/preinstall persistence',
        'workflow markers OIDC_PACKAGES or bun run _index.js',
        'Miasma marker text "Miasma: The Spreading Blight"'
    )
}

function Write-PayloadVerboseOnce {
    if ($script:payloadVerboseWritten) {
        return
    }

    Write-Verbose 'Miasma payload indicators scanned for every PR:'
    foreach ($payload in Get-PayloadDescription) {
        Write-Verbose "  - $payload"
    }
    $script:payloadVerboseWritten = $true
}

function Confirm-MultiRepoScan {
    param([Parameter()][object[]]$Targets)

    if (@($Targets).Count -eq 0) {
        return
    }

    $repoKeys = @(
        $Targets |
            ForEach-Object { "$($_.Owner)/$($_.Repository)" } |
            Sort-Object -Unique
    )

    if ($repoKeys.Count -le 1) {
        return
    }

    Write-Information -InformationAction Continue -MessageData "About to scan $($Targets.Count) pull request(s) across $($repoKeys.Count) repositories:"
    foreach ($repoKey in $repoKeys) {
        $count = @($Targets | Where-Object { "$($_.Owner)/$($_.Repository)" -eq $repoKey }).Count
        Write-Information -InformationAction Continue -MessageData "  $repoKey - $count PR(s)"
    }

    $answer = Read-Host 'Type YES to continue'
    if ($answer -ne 'YES') {
        throw 'Scan cancelled. Multi-repo scans require confirmation.'
    }
}

function ConvertFrom-ResumeAfter {
    param([AllowNull()][string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    $trimmed = $Value.Trim()
    $match = [regex]::Match($trimmed, '^(?:(?<owner>[^/\s#]+)/)?(?<repo>[^#\s]+)#(?<number>\d+)$')
    if (-not $match.Success) {
        throw "ResumeAfter is not recognized: $Value. Use REPO#PR or OWNER/REPO#PR, for example incident-service#86."
    }

    [pscustomobject]@{
        Owner = $match.Groups['owner'].Value
        Repository = $match.Groups['repo'].Value
        PullRequestNumber = [int]$match.Groups['number'].Value
        Text = $trimmed
    }
}

function Select-TargetsAfterResumePoint {
    param(
        [Parameter()][object[]]$Targets,
        [AllowNull()][object]$ResumePoint
    )

    if ($null -eq $ResumePoint -or @($Targets).Count -eq 0) {
        return @($Targets)
    }

    $resumeOwner = [string]$ResumePoint.Owner
    $resumeRepository = [string]$ResumePoint.Repository
    $resumePullRequestNumber = [int]$ResumePoint.PullRequestNumber
    $matchIndex = -1

    for ($index = 0; $index -lt @($Targets).Count; $index++) {
        $target = @($Targets)[$index]
        $ownerMatches = [string]::IsNullOrWhiteSpace($resumeOwner) -or [string]$target.Owner -eq $resumeOwner
        if ($ownerMatches -and [string]$target.Repository -eq $resumeRepository -and [int]$target.PullRequestNumber -eq $resumePullRequestNumber) {
            $matchIndex = $index
            break
        }
    }

    if ($matchIndex -lt 0) {
        throw "ResumeAfter target '$($ResumePoint.Text)' was not found in the discovered PR target list. No scan was started."
    }

    if ($matchIndex -ge @($Targets).Count - 1) {
        return @()
    }

    return @($Targets | Select-Object -Skip ($matchIndex + 1))
}

function Get-FindingRecord {
    param(
        [Parameter(Mandatory)][string]$Scope,
        [Parameter(Mandatory)][string]$Severity,
        [Parameter(Mandatory)][string]$Type,
        [Parameter()][string]$CommitSha,
        [Parameter()][string]$Path,
        [Parameter()][string]$Status,
        [Parameter()][string]$Detail
    )

    [pscustomobject]@{
        Scope = $Scope
        Severity = $Severity
        Type = $Type
        CommitSha = $CommitSha
        Path = $Path
        Status = $Status
        Detail = $Detail
    }
}

function Get-WarningRecord {
    param(
        [Parameter(Mandatory)][string]$Type,
        [Parameter()][string]$CommitSha,
        [Parameter()][string]$Path,
        [Parameter()][string]$Detail
    )

    [pscustomobject]@{
        Type = $Type
        CommitSha = $CommitSha
        Path = $Path
        Detail = $Detail
    }
}

function Get-BlobText {
    param(
        [Parameter(Mandatory)][hashtable]$Context,
        [Parameter(Mandatory)][string]$BlobSha,
        [Parameter()][int]$Size = 0
    )

    if ($Context.BlobTextBySha.ContainsKey($BlobSha)) {
        return $Context.BlobTextBySha[$BlobSha]
    }

    if ($Size -gt $MaxBlobBytes) {
        $Context.Warnings.Add((Get-WarningRecord -Type 'blob-too-large-for-content-scan' -Detail "Blob $BlobSha is $Size bytes; limit is $MaxBlobBytes bytes.")) | Out-Null
        $Context.BlobTextBySha[$BlobSha] = $null
        return $null
    }

    $owner = [string]$Context.Owner
    $repository = [string]$Context.Repository
    $blob = Invoke-GhApiJson -Arguments @("repos/$owner/$repository/git/blobs/$BlobSha")
    if ($null -eq $blob) {
        $Context.Warnings.Add((Get-WarningRecord -Type 'blob-read-failed' -Detail "Blob $BlobSha failed. ExitCode=$script:lastGhExitCode Message=$script:lastGhError")) | Out-Null
        $Context.BlobTextBySha[$BlobSha] = $null
        return $null
    }

    $text = $null
    if ([string]$blob.encoding -eq 'base64') {
        $content = ([string]$blob.content) -replace '\s', ''
        try {
            $bytes = [Convert]::FromBase64String($content)
            $text = [System.Text.Encoding]::UTF8.GetString($bytes)
        }
        catch {
            $Context.Warnings.Add((Get-WarningRecord -Type 'blob-decode-failed' -Detail "Blob $BlobSha could not be decoded as UTF-8 base64: $($_.Exception.Message)")) | Out-Null
        }
    }
    else {
        $text = [string]$blob.content
    }

    $Context.BlobTextBySha[$BlobSha] = $text
    return $text
}

function Add-PathPresenceFinding {
    param(
        [Parameter(Mandatory)][hashtable]$Context,
        [Parameter(Mandatory)][string]$Scope,
        [Parameter()][string]$CommitSha,
        [Parameter(Mandatory)][string]$Path,
        [Parameter()][string]$Status
    )

    $normalized = ConvertTo-GitPath -Path $Path
    if ($normalized -ne '.github/setup.js') {
        return
    }

    if ($Scope -eq 'FinalDiff' -and $Status -eq 'removed') {
        $Context.Findings.Add((Get-FindingRecord -Scope $Scope -Severity 'Info' -Type 'Miasma setup dropper path removed by PR' -CommitSha $CommitSha -Path $normalized -Status $Status -Detail 'Removal is not merge-contaminating, but confirms this PR touched a high-signal path.')) | Out-Null
        return
    }

    $Context.Findings.Add((Get-FindingRecord -Scope $Scope -Severity 'Critical' -Type 'Miasma setup dropper path' -CommitSha $CommitSha -Path $normalized -Status $Status)) | Out-Null
}

function Add-ContentFinding {
    param(
        [Parameter(Mandatory)][hashtable]$Context,
        [Parameter(Mandatory)][string]$Scope,
        [Parameter()][string]$CommitSha,
        [Parameter(Mandatory)][string]$Path,
        [Parameter()][string]$Status,
        [AllowNull()][string]$Text
    )

    if (-not $Text) {
        return
    }

    foreach ($check in Get-ContentCheck) {
        if ($Text -match $check.Pattern) {
            $Context.Findings.Add((Get-FindingRecord -Scope $Scope -Severity $check.Severity -Type $check.Type -CommitSha $CommitSha -Path (ConvertTo-GitPath -Path $Path) -Status $Status -Detail "Matched pattern: $($check.Pattern)")) | Out-Null
        }
    }
}

function Get-AddedPatchText {
    param([AllowNull()][string]$Patch)

    if (-not $Patch) {
        return ''
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in ($Patch -split "`n")) {
        if ($line.StartsWith('+') -and -not $line.StartsWith('+++')) {
            $lines.Add($line.Substring(1)) | Out-Null
        }
    }

    return ($lines -join "`n")
}

function Test-CommitTree {
    param(
        [Parameter(Mandatory)][hashtable]$Context,
        [Parameter(Mandatory)][object]$Commit
    )

    $commitSha = [string]$Commit.sha
    $treeSha = [string]$Commit.commit.tree.sha
    if (-not $commitSha -or -not $treeSha) {
        $Context.Warnings.Add((Get-WarningRecord -Type 'commit-missing-tree' -CommitSha $commitSha -Detail 'Pull request commit record did not include a tree SHA.')) | Out-Null
        return
    }

    $message = [string]$Commit.commit.message
    if ($message -match 'chore: update dependencies \[skip ci\]') {
        $Context.Findings.Add((Get-FindingRecord -Scope 'CommitMessage' -Severity 'Info' -Type 'Suspicious commit phrase' -CommitSha $commitSha -Detail 'Plain [skip ci] is noisy; treat as context only unless paired with high-signal indicators.')) | Out-Null
    }

    $owner = [string]$Context.Owner
    $repository = [string]$Context.Repository
    $tree = Invoke-GhApiJson -Arguments @("repos/$owner/$repository/git/trees/$treeSha`?recursive=1")
    if ($null -eq $tree) {
        $Context.Warnings.Add((Get-WarningRecord -Type 'tree-read-failed' -CommitSha $commitSha -Detail "Tree $treeSha failed. ExitCode=$script:lastGhExitCode Message=$script:lastGhError")) | Out-Null
        return
    }
    if ($tree.PSObject.Properties['truncated'] -and [bool]$tree.truncated) {
        $Context.Warnings.Add((Get-WarningRecord -Type 'tree-truncated' -CommitSha $commitSha -Detail "Tree $treeSha was truncated by GitHub; findings may be incomplete.")) | Out-Null
    }

    foreach ($entry in @($tree.tree)) {
        if ([string]$entry.type -ne 'blob') {
            continue
        }

        $path = ConvertTo-GitPath -Path ([string]$entry.path)
        Add-PathPresenceFinding -Context $Context -Scope 'CommitTree' -CommitSha $commitSha -Path $path

        if (-not (Test-ContentScanCandidate -Path $path)) {
            continue
        }

        $text = Get-BlobText -Context $Context -BlobSha ([string]$entry.sha) -Size ([int]$entry.size)
        Add-ContentFinding -Context $Context -Scope 'CommitTree' -CommitSha $commitSha -Path $path -Text $text
    }
}

function Test-FinalDiffFile {
    param(
        [Parameter(Mandatory)][hashtable]$Context,
        [Parameter(Mandatory)][object]$File
    )

    $path = ConvertTo-GitPath -Path ([string]$File.filename)
    $status = [string]$File.status
    Add-PathPresenceFinding -Context $Context -Scope 'FinalDiff' -Path $path -Status $status

    if (-not (Test-ContentScanCandidate -Path $path)) {
        return
    }

    if ($status -eq 'removed') {
        return
    }

    $patch = ''
    if ($File.PSObject.Properties.Name -contains 'patch') {
        $patch = [string]$File.patch
    }
    if ([string]::IsNullOrWhiteSpace($patch)) {
        $Context.Warnings.Add((Get-WarningRecord -Type 'final-diff-patch-unavailable' -Path $path -Detail "GitHub PR files API did not include patch text for status '$status'; added lines in this file could not be scanned.")) | Out-Null
        return
    }

    $addedText = Get-AddedPatchText -Patch $patch
    Add-ContentFinding -Context $Context -Scope 'FinalDiff' -Path $path -Status $status -Text $addedText
}

function Resolve-Target {
    if ($PullRequestUrl) {
        $match = [regex]::Match($PullRequestUrl, 'github\.com/(?<owner>[^/]+)/(?<repo>[^/]+)/pull/(?<number>\d+)')
        if (-not $match.Success) {
            throw "PullRequestUrl is not a recognized GitHub pull request URL: $PullRequestUrl"
        }

        return @([pscustomobject]@{
                Owner = $match.Groups['owner'].Value
                Repository = $match.Groups['repo'].Value
                PullRequestNumber = [int]$match.Groups['number'].Value
            })
    }

    $owner = $Organization
    $repository = $Repo
    if ($repository -and $repository.Contains('/')) {
        $repoParts = $repository.Split('/', 2)
        if ($repoParts.Count -ne 2 -or -not $repoParts[0] -or -not $repoParts[1]) {
            throw "Repo must be REPOSITORY or OWNER/REPOSITORY: $Repo"
        }
        $owner = $repoParts[0]
        $repository = $repoParts[1]
    }

    if (-not $repository -and $PR -gt 0) {
        throw 'Specify -Repo when using -PR. Pull request numbers are repository-scoped, so -PR alone is ambiguous.'
    }

    if ($repository -and $PR -gt 0) {
        return @([pscustomobject]@{
                Owner = $owner
                Repository = $repository
                PullRequestNumber = $PR
            })
    }

    $targets = [System.Collections.ArrayList]::new()
    if ($repository) {
        foreach ($item in Get-ClosedPullRequestTarget -Owner $owner -Repository $repository) {
            [void]$targets.Add([pscustomobject]@{
                    Owner = [string]$item.Owner
                    Repository = [string]$item.Repository
                    PullRequestNumber = [int]$item.PullRequestNumber
                    ClosedAt = [string]$item.ClosedAt
                })
        }
        return @($targets)
    }

    foreach ($item in Get-ClosedPullRequestTarget -Owner $owner) {
        [void]$targets.Add([pscustomobject]@{
                Owner = [string]$item.Owner
                Repository = [string]$item.Repository
                PullRequestNumber = [int]$item.PullRequestNumber
                ClosedAt = [string]$item.ClosedAt
            })
    }

    return @($targets)
}

function Get-ExplicitOwnerRepository {
    $owner = $Organization
    $repository = $Repo

    if ($PullRequestUrl) {
        $match = [regex]::Match($PullRequestUrl, 'github\.com/(?<owner>[^/]+)/(?<repo>[^/]+)/pull/(?<number>\d+)')
        if ($match.Success) {
            return [pscustomobject]@{
                Owner = $match.Groups['owner'].Value
                Repository = $match.Groups['repo'].Value
            }
        }
    }

    if ($repository -and $repository.Contains('/')) {
        $repoParts = $repository.Split('/', 2)
        if ($repoParts.Count -eq 2 -and $repoParts[0] -and $repoParts[1]) {
            $owner = $repoParts[0]
            $repository = $repoParts[1]
        }
    }

    if (-not $repository) {
        return $null
    }

    [pscustomobject]@{
        Owner = $owner
        Repository = $repository
    }
}

function Resolve-AdditionalCommitTarget {
    param([Parameter()][string[]]$CommitSpecs)

    $targets = [System.Collections.ArrayList]::new()
    $seen = @{}
    foreach ($spec in @($CommitSpecs)) {
        $value = ([string]$spec).Trim()
        if (-not $value) {
            continue
        }

        $owner = ''
        $repository = ''
        $sha = ''

        $ownerRepoMatch = [regex]::Match($value, '^(?<owner>[^/\s@:#]+)/(?<repo>[^@\s:#]+)[@:#](?<sha>[0-9a-fA-F]{7,40})$')
        $repoMatch = [regex]::Match($value, '^(?<repo>[^/\s@:#]+)[@:#](?<sha>[0-9a-fA-F]{7,40})$')
        $shaMatch = [regex]::Match($value, '^(?<sha>[0-9a-fA-F]{7,40})$')

        if ($ownerRepoMatch.Success) {
            $owner = $ownerRepoMatch.Groups['owner'].Value
            $repository = $ownerRepoMatch.Groups['repo'].Value
            $sha = $ownerRepoMatch.Groups['sha'].Value
        }
        elseif ($repoMatch.Success) {
            $owner = $Organization
            $repository = $repoMatch.Groups['repo'].Value
            $sha = $repoMatch.Groups['sha'].Value
        }
        elseif ($shaMatch.Success) {
            $explicit = Get-ExplicitOwnerRepository
            if ($null -eq $explicit) {
                throw "AdditionalCommit '$value' needs a repository. Use OWNER/REPO@SHA, REPO@SHA, or specify -Repo."
            }
            $owner = [string]$explicit.Owner
            $repository = [string]$explicit.Repository
            $sha = $shaMatch.Groups['sha'].Value
        }
        else {
            throw "AdditionalCommit is not recognized: $value. Use OWNER/REPO@SHA, REPO@SHA, or SHA with -Repo."
        }

        $key = "$owner/$repository@$sha".ToLowerInvariant()
        if ($seen.ContainsKey($key)) {
            continue
        }

        $seen[$key] = $true
        [void]$targets.Add([pscustomobject]@{
                Owner = $owner
                Repository = $repository
                CommitSha = $sha.ToLowerInvariant()
                Source = $value
            })
    }

    return @($targets)
}

function Invoke-PrScan {
    param(
        [Parameter(Mandatory)][string]$Owner,
        [Parameter(Mandatory)][string]$Repository,
        [Parameter(Mandatory)][int]$PullRequestNumber
    )

    $checkStartedAt = Get-Date
    $context = @{
        Owner = $Owner
        Repository = $Repository
        PullRequestNumber = $PullRequestNumber
        Findings = [System.Collections.Generic.List[object]]::new()
        Warnings = [System.Collections.Generic.List[object]]::new()
        BlobTextBySha = @{}
    }

    $pr = Invoke-GhApiJson -Arguments @("repos/$Owner/$Repository/pulls/$PullRequestNumber")
    if ($null -eq $pr) {
        throw "Unable to load PR $Owner/$Repository#$PullRequestNumber. ExitCode=$script:lastGhExitCode Message=$script:lastGhError"
    }

    if ($script:lastVerboseOwner -ne $Owner) {
        Write-Verbose "Organization: $Owner"
        $script:lastVerboseOwner = $Owner
        $script:lastVerboseRepository = ''
    }
    if ($script:lastVerboseRepository -ne $Repository) {
        Write-Verbose "Repository: $Repository"
        $script:lastVerboseRepository = $Repository
    }
    Write-Verbose "Pull Request: #$PullRequestNumber"
    Write-Verbose "PR State: $([string]$pr.state)"
    Write-Verbose 'Checking source branch (PR head):'
    Write-Verbose "  Source repo: $([string]$pr.head.repo.full_name)"
    Write-Verbose "  Source branch: $([string]$pr.head.ref)"
    Write-Verbose "  Source SHA: $([string]$pr.head.sha)"
    Write-Verbose 'Checking target branch (PR base):'
    Write-Verbose "  Target repo: $Owner/$Repository"
    Write-Verbose "  Target branch: $([string]$pr.base.ref)"
    Write-Verbose "  Target SHA: $([string]$pr.base.sha)"

    $commits = Get-PaginatedGhApi -PathWithQuery "repos/$Owner/$Repository/pulls/$PullRequestNumber/commits?per_page=100"
    $files = Get-PaginatedGhApi -PathWithQuery "repos/$Owner/$Repository/pulls/$PullRequestNumber/files?per_page=100"
    Write-Verbose "Checking current PR commit trees from GitHub PR commit list: $(@($commits).Count) commit(s)"
    Write-Verbose "Checking final PR diff from GitHub PR files list: $(@($files).Count) file(s); only added patch lines are scanned as merge-introducing payloads"

    foreach ($commit in @($commits)) {
        Test-CommitTree -Context $context -Commit $commit
    }
    foreach ($file in @($files)) {
        Test-FinalDiffFile -Context $context -File $file
    }

    $blockingFindings = @($context.Findings | Where-Object { $_.Severity -in @('Critical', 'High', 'Medium') })
    $sortedFindings = @($context.Findings | Sort-Object @{ Expression = { Get-SeverityRank -Severity $_.Severity } }, Scope, CommitSha, Path, Type)
    $sortedWarnings = @($context.Warnings | Sort-Object Type, CommitSha, Path)
    $checkCompletedAt = Get-Date

    [pscustomobject]@{
        Owner = $Owner
        Repository = $Repository
        PullRequestNumber = $PullRequestNumber
        CheckStartedAtEastern = ConvertTo-EasternTimestamp -Timestamp $checkStartedAt
        CheckCompletedAtEastern = ConvertTo-EasternTimestamp -Timestamp $checkCompletedAt
        CheckTimeZone = 'Eastern Standard Time'
        PullRequestUrl = [string]$pr.html_url
        State = [string]$pr.state
        BaseRef = [string]$pr.base.ref
        BaseSha = [string]$pr.base.sha
        HeadRef = [string]$pr.head.ref
        HeadSha = [string]$pr.head.sha
        HeadRepository = [string]$pr.head.repo.full_name
        ScanMode = 'GitHub API only; no clone, no checkout, no code execution'
        CommitRangeScanned = 'Current PR commits from GitHub pulls/{number}/commits'
        FinalDiffScanned = 'Current PR files from GitHub pulls/{number}/files; only added patch lines are treated as merge-introducing content'
        CommitCount = @($commits).Count
        FinalDiffFileCount = @($files).Count
        FindingCount = $context.Findings.Count
        BlockingFindingCount = $blockingFindings.Count
        WarningCount = $context.Warnings.Count
        IsCleanWithWarnings = ($blockingFindings.Count -eq 0)
        Findings = $sortedFindings
        Warnings = $sortedWarnings
    }
}

function Invoke-AdditionalCommitScan {
    param(
        [Parameter(Mandatory)][string]$Owner,
        [Parameter(Mandatory)][string]$Repository,
        [Parameter(Mandatory)][string]$CommitSha
    )

    $checkStartedAt = Get-Date
    $context = @{
        Owner = $Owner
        Repository = $Repository
        PullRequestNumber = 0
        Findings = [System.Collections.Generic.List[object]]::new()
        Warnings = [System.Collections.Generic.List[object]]::new()
        BlobTextBySha = @{}
    }

    if ($script:lastVerboseOwner -ne $Owner) {
        Write-Verbose "Organization: $Owner"
        $script:lastVerboseOwner = $Owner
        $script:lastVerboseRepository = ''
    }
    if ($script:lastVerboseRepository -ne $Repository) {
        Write-Verbose "Repository: $Repository"
        $script:lastVerboseRepository = $Repository
    }
    Write-Verbose "Additional commit: $CommitSha"

    $commit = Invoke-GhApiJson -Arguments @("repos/$Owner/$Repository/commits/$CommitSha")
    if ($null -eq $commit) {
        $context.Warnings.Add((Get-WarningRecord -Type 'additional-commit-read-failed' -CommitSha $CommitSha -Detail "Commit read failed. ExitCode=$script:lastGhExitCode Message=$script:lastGhError")) | Out-Null
    }
    else {
        Test-CommitTree -Context $context -Commit $commit
    }

    $blockingFindings = @($context.Findings | Where-Object { $_.Severity -in @('Critical', 'High', 'Medium') })
    $sortedFindings = @($context.Findings | Sort-Object @{ Expression = { Get-SeverityRank -Severity $_.Severity } }, Scope, CommitSha, Path, Type)
    $sortedWarnings = @($context.Warnings | Sort-Object Type, CommitSha, Path)
    $htmlUrl = if ($null -ne $commit) { [string]$commit.html_url } else { "https://github.com/$Owner/$Repository/commit/$CommitSha" }
    $checkCompletedAt = Get-Date

    [pscustomobject]@{
        Owner = $Owner
        Repository = $Repository
        CommitSha = $CommitSha
        CheckStartedAtEastern = ConvertTo-EasternTimestamp -Timestamp $checkStartedAt
        CheckCompletedAtEastern = ConvertTo-EasternTimestamp -Timestamp $checkCompletedAt
        CheckTimeZone = 'Eastern Standard Time'
        CommitUrl = $htmlUrl
        ScanMode = 'GitHub API only; known additional commit SHA tree scan'
        FindingCount = $context.Findings.Count
        BlockingFindingCount = $blockingFindings.Count
        WarningCount = $context.Warnings.Count
        IsCleanWithWarnings = ($blockingFindings.Count -eq 0)
        Findings = $sortedFindings
        Warnings = $sortedWarnings
    }
}

function Format-FindingSummary {
    param([Parameter()][object[]]$Findings)

    $blocking = @($Findings | Where-Object { $_.Severity -in @('Critical', 'High', 'Medium') })
    $summaries = @(
        $blocking |
            ForEach-Object {
                $location = @($_.Scope, $_.CommitSha, $_.Path, $_.Status) |
                    Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
                "$($_.Severity) $($_.Type) ($($location -join ' '))"
            } |
            Sort-Object -Unique
    )
    return ($summaries -join '; ')
}

function Write-GroupedResult {
    param(
        [Parameter(Mandatory)][object]$Result
    )

    if ($script:lastOutputOwner -ne [string]$Result.Owner) {
        [string]$Result.Owner
        $script:lastOutputOwner = [string]$Result.Owner
        $script:lastOutputRepository = ''
    }

    if ($script:lastOutputRepository -ne [string]$Result.Repository) {
        "  $($Result.Repository)"
        $script:lastOutputRepository = [string]$Result.Repository
    }

    if ($Result.IsCleanWithWarnings) {
        "    PR #$($Result.PullRequestNumber) - Clean"
        return
    }

    $summary = Format-FindingSummary -Findings @($Result.Findings)
    if ($summary) {
        "    PR #$($Result.PullRequestNumber) - Do not reopen this PR - $summary"
    }
    else {
        "    PR #$($Result.PullRequestNumber) - Do not reopen this PR"
    }
}

function Write-GroupedTargetProgress {
    param(
        [Parameter(Mandatory)][object]$Target
    )

    if ($script:lastOutputOwner -ne [string]$Target.Owner) {
        [string]$Target.Owner
        $script:lastOutputOwner = [string]$Target.Owner
        $script:lastOutputRepository = ''
    }

    if ($script:lastOutputRepository -ne [string]$Target.Repository) {
        "  $($Target.Repository)"
        $script:lastOutputRepository = [string]$Target.Repository
    }

    "    PR #$($Target.PullRequestNumber) - Checking"
}

function Get-ScanArtifact {
    param(
        [Parameter()][object[]]$Targets = @(),
        [Parameter()][object[]]$Results = @(),
        [Parameter()][object[]]$AdditionalCommitTargets = @(),
        [Parameter()][object[]]$AdditionalCommitResults = @(),
        [Parameter(Mandatory)][datetime]$StartedAt,
        [Parameter(Mandatory)][datetime]$CompletedAt
    )

    $additionalBlockingCount = @($AdditionalCommitResults | Where-Object { -not $_.IsCleanWithWarnings }).Count

    [pscustomobject]@{
        Tool = 'Test-MiasmaPullRequest'
        ScanMode = 'GitHub API only; no clone, no checkout, no code execution'
        StartedAt = $StartedAt.ToString('o')
        CompletedAt = $CompletedAt.ToString('o')
        StartedAtEastern = ConvertTo-EasternTimestamp -Timestamp $StartedAt
        CompletedAtEastern = ConvertTo-EasternTimestamp -Timestamp $CompletedAt
        TimeZone = 'Eastern Standard Time'
        Organization = $Organization
        Repo = $Repo
        PR = $PR
        PullRequestUrl = $PullRequestUrl
        ResumeAfter = $ResumeAfter
        ClosedSince = $closedSinceText
        ClosedQuery = $closedQuery
        TargetCount = @($Targets).Count
        ResultCount = @($Results).Count
        BlockingResultCount = @($Results | Where-Object { -not $_.IsCleanWithWarnings }).Count
        CleanResultCount = @($Results | Where-Object { $_.IsCleanWithWarnings }).Count
        AdditionalCommitTargetCount = @($AdditionalCommitTargets).Count
        AdditionalCommitResultCount = @($AdditionalCommitResults).Count
        AdditionalCommitBlockingCount = $additionalBlockingCount
        OrphanedCommitEnumeration = 'Not automatic. GitHub does not provide a normal repo-wide API to enumerate orphaned/unreferenced commits; known SHAs must be supplied with -AdditionalCommit.'
        ApiRequestCount = $apiRequestCount
        PayloadIndicators = @(Get-PayloadDescription)
        Targets = @($Targets)
        Results = @($Results)
        AdditionalCommitTargets = @($AdditionalCommitTargets)
        AdditionalCommitResults = @($AdditionalCommitResults)
    }
}

function Save-ScanArtifact {
    param([Parameter(Mandatory)][object]$Artifact)

    if (-not (Test-Path -LiteralPath $artifactDirectory)) {
        New-Item -ItemType Directory -Path $artifactDirectory -Force | Out-Null
    }

    $Artifact | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $jsonOutputPath -Encoding utf8BOM
    Write-Verbose "JSON results written: $jsonOutputPath"
}

function ConvertTo-HtmlText {
    param([AllowNull()][object]$Value)

    return [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

function Join-FindingSummary {
    param([Parameter()][object[]]$Findings)

    $summary = Format-FindingSummary -Findings $Findings
    if ($summary) {
        return $summary
    }

    return ''
}

function Test-ReportProperty {
    param(
        [AllowNull()][object]$InputObject,
        [Parameter(Mandatory)][string]$Name
    )

    return ($null -ne $InputObject -and $InputObject.PSObject.Properties.Name -contains $Name)
}

function Get-ResultWarningCount {
    param([AllowNull()][object]$Result)

    if (Test-ReportProperty -InputObject $Result -Name 'WarningCount') {
        return [int]$Result.WarningCount
    }

    if (Test-ReportProperty -InputObject $Result -Name 'Warnings') {
        return @($Result.Warnings).Count
    }

    return 0
}

function Get-ResultInfoFindingCount {
    param([AllowNull()][object]$Result)

    if (-not (Test-ReportProperty -InputObject $Result -Name 'Findings')) {
        return 0
    }

    return @($Result.Findings | Where-Object { [string]$_.Severity -eq 'Info' }).Count
}

function Get-ResultConfidenceLevel {
    param([Parameter(Mandatory)][object]$Result)

    if (Get-ResultWarningCount -Result $Result) {
        return 'Medium'
    }

    return 'High'
}

function Get-ResultRecommendation {
    param([Parameter(Mandatory)][object]$Result)

    if (-not [bool]$Result.IsCleanWithWarnings) {
        return 'Do not reopen this PR. Preserve the branch evidence and remediate or rebuild before reuse.'
    }

    if ((Get-ResultWarningCount -Result $Result) -gt 0) {
        return 'Special precaution: no blocking indicator was found, but one or more scan warnings reduced confidence. Review warnings before adding this PR to the reopen whitelist.'
    }

    if ((Get-ResultInfoFindingCount -Result $Result) -gt 0) {
        return 'Business as usual for the reopen decision, with contextual non-blocking findings noted.'
    }

    return 'Business as usual: eligible for the reopen whitelist from this Miasma indicator scan.'
}

function Get-ArtifactAdditionalCommitResult {
    param([Parameter(Mandatory)][object]$Artifact)

    if (Test-ReportProperty -InputObject $Artifact -Name 'AdditionalCommitResults') {
        return @($Artifact.AdditionalCommitResults)
    }

    return @()
}

function Get-ArtifactAdditionalCommitTargetCount {
    param([Parameter(Mandatory)][object]$Artifact)

    if (Test-ReportProperty -InputObject $Artifact -Name 'AdditionalCommitTargetCount') {
        return [int]$Artifact.AdditionalCommitTargetCount
    }

    return 0
}

function Get-ArtifactWarningResultCount {
    param([Parameter(Mandatory)][object]$Artifact)

    $prWarningCount = @($Artifact.Results | Where-Object { (Get-ResultWarningCount -Result $_) -gt 0 }).Count
    $additionalWarningCount = @(Get-ArtifactAdditionalCommitResult -Artifact $Artifact | Where-Object { (Get-ResultWarningCount -Result $_) -gt 0 }).Count

    return ($prWarningCount + $additionalWarningCount)
}

function Get-ArtifactConfidenceLevel {
    param([Parameter(Mandatory)][object]$Artifact)

    if ([int]$Artifact.ResultCount -eq 0) {
        return 'Low'
    }

    if ((Get-ArtifactWarningResultCount -Artifact $Artifact) -gt 0) {
        return 'Medium'
    }

    return 'High'
}

function Get-ArtifactConfidenceSummary {
    param([Parameter(Mandatory)][object]$Artifact)

    $level = Get-ArtifactConfidenceLevel -Artifact $Artifact
    $warningCount = Get-ArtifactWarningResultCount -Artifact $Artifact
    if ($level -eq 'Low') {
        return 'Low confidence because this artifact contains no PR results to evaluate.'
    }

    if ($warningCount -gt 0) {
        return "Medium confidence for known Miasma indicators because $warningCount result(s) had scan warnings such as truncated trees, unread blobs, oversized blobs, or decode failures."
    }

    if ((Get-ArtifactAdditionalCommitTargetCount -Artifact $Artifact) -eq 0) {
        return 'High confidence for the known Miasma indicators listed in this report, limited to the current GitHub PR commit list and final PR file delta. Orphaned/unreferenced commits were not enumerated automatically.'
    }

    return 'High confidence for the known Miasma indicators listed in this report, including supplied additional commit SHAs, the current GitHub PR commit list, and the final PR file delta.'
}

function Get-ArtifactRecommendationSummary {
    param([Parameter(Mandatory)][object]$Artifact)

    $blockedCount = [int]$Artifact.BlockingResultCount
    $additionalBlockedCount = @(Get-ArtifactAdditionalCommitResult -Artifact $Artifact | Where-Object { -not $_.IsCleanWithWarnings }).Count
    $warningCount = Get-ArtifactWarningResultCount -Artifact $Artifact
    if ($additionalBlockedCount -gt 0) {
        return "Do not treat the supplied orphaned/extra commit SHA(s) as clean. $additionalBlockedCount supplied commit result(s) had blocking indicators or verification warnings. Coordinate cleanup with GitHub/InfoSec before relying on repository history cleanup."
    }

    if ($blockedCount -gt 0) {
        return "Do not reopen the $blockedCount PR(s) marked Do not reopen. Clean PRs can follow business-as-usual reopening from the Miasma scan perspective unless their row calls out special precautions."
    }

    if ($warningCount -gt 0) {
        return 'No blocking Miasma indicators were found, but PRs with warning-based recommendations should be reviewed before whitelist/reopen handling.'
    }

    return 'Business as usual from the Miasma indicator perspective: the checked PRs can be handled through the normal reopen/whitelist process.'
}

function Read-ScanArtifact {
    if (-not (Test-Path -LiteralPath $jsonOutputPath)) {
        throw "JSON artifact not found: $jsonOutputPath. Run a scan first, then rerun with -RegenerateReport."
    }

    try {
        return Get-Content -LiteralPath $jsonOutputPath -Raw | ConvertFrom-Json
    }
    catch {
        throw "Unable to read JSON artifact: $jsonOutputPath. $($_.Exception.Message)"
    }
}

function Get-ReportHtml {
    param([Parameter(Mandatory)][object]$Artifact)

    $generated = ConvertTo-HtmlText $Artifact.CompletedAt
    $title = 'Miasma PR Check Report'
    $scope = if ($Artifact.Repo) { "$($Artifact.Organization)/$($Artifact.Repo)" } else { [string]$Artifact.Organization }
    $scopeHtml = ConvertTo-HtmlText $scope
    $closedSinceHtml = ConvertTo-HtmlText $Artifact.ClosedSince
    $jsonPathHtml = ConvertTo-HtmlText $jsonOutputPath
    $cleanCount = [int]$Artifact.CleanResultCount
    $blockedCount = [int]$Artifact.BlockingResultCount
    $resultCount = [int]$Artifact.ResultCount
    $apiCount = [int]$Artifact.ApiRequestCount
    $confidenceLevel = ConvertTo-HtmlText (Get-ArtifactConfidenceLevel -Artifact $Artifact)
    $confidenceSummary = ConvertTo-HtmlText (Get-ArtifactConfidenceSummary -Artifact $Artifact)
    $recommendationSummary = ConvertTo-HtmlText (Get-ArtifactRecommendationSummary -Artifact $Artifact)
    $additionalCommitTargetCount = Get-ArtifactAdditionalCommitTargetCount -Artifact $Artifact
    $additionalCommitResults = @(Get-ArtifactAdditionalCommitResult -Artifact $Artifact)
    $resumeAfter = ''
    if (Test-ReportProperty -InputObject $Artifact -Name 'ResumeAfter') {
        $resumeAfter = [string]$Artifact.ResumeAfter
    }
    $resumeDisclosure = if ([string]::IsNullOrWhiteSpace($resumeAfter)) {
        'Full discovered target list was eligible for this run.'
    }
    else {
        "Resumed after $resumeAfter. This artifact contains only targets after that already-checked PR; earlier clean console output is not reconstructed into this JSON/HTML."
    }
    $resumeDisclosureHtml = ConvertTo-HtmlText $resumeDisclosure
    $orphanedDisclosure = if ($additionalCommitTargetCount -gt 0) {
        "Known orphaned/extra commit SHAs supplied and scanned: $additionalCommitTargetCount."
    }
    else {
        'No orphaned/extra commit SHAs were supplied. This report does not claim GitHub has no orphaned commits; it only covers current PR commit lists, final PR file deltas, and any additional SHAs explicitly supplied.'
    }
    $orphanedDisclosureHtml = ConvertTo-HtmlText $orphanedDisclosure

    $repoGroups = @($Artifact.Results | Group-Object Owner, Repository | Sort-Object Name)
    $sections = foreach ($group in $repoGroups) {
        $first = @($group.Group)[0]
        $owner = ConvertTo-HtmlText $first.Owner
        $repo = ConvertTo-HtmlText $first.Repository
        $rows = foreach ($result in @($group.Group | Sort-Object @{ Expression = 'PullRequestNumber'; Descending = $true })) {
            $statusClass = if ($result.IsCleanWithWarnings) { 'clean' } else { 'blocked' }
            $status = if ($result.IsCleanWithWarnings) { 'Clean' } else { 'Do not reopen' }
            $finding = ConvertTo-HtmlText (Join-FindingSummary -Findings @($result.Findings))
            $url = ConvertTo-HtmlText $result.PullRequestUrl
            $sourceBranch = ConvertTo-HtmlText $result.HeadRef
            $targetBranch = ConvertTo-HtmlText $result.BaseRef
            $headSha = ConvertTo-HtmlText $result.HeadSha
            $commitCount = [int]$result.CommitCount
            $fileCount = [int]$result.FinalDiffFileCount
            $warningCount = Get-ResultWarningCount -Result $result
            $confidence = ConvertTo-HtmlText (Get-ResultConfidenceLevel -Result $result)
            $recommendation = ConvertTo-HtmlText (Get-ResultRecommendation -Result $result)
            $checkedAt = ''
            if (Test-ReportProperty -InputObject $result -Name 'CheckCompletedAtEastern') {
                $checkedAt = ConvertTo-HtmlText $result.CheckCompletedAtEastern
            }
            @"
          <tr>
            <td><a href="$url">#$($result.PullRequestNumber)</a></td>
            <td><span class="status $statusClass">$status</span></td>
            <td>$sourceBranch<br><span>$headSha</span></td>
            <td>$targetBranch</td>
            <td>$checkedAt</td>
            <td>$commitCount</td>
            <td>$fileCount</td>
            <td>$warningCount</td>
            <td>$confidence</td>
            <td>$finding</td>
            <td>$recommendation</td>
          </tr>
"@
        }

        @"
    <section>
      <h2>$owner / $repo</h2>
      <table>
        <thead>
          <tr>
            <th>PR</th>
            <th>Status</th>
            <th>Source</th>
            <th>Target</th>
            <th>Checked ET</th>
            <th>Commits</th>
            <th>Files</th>
            <th>Warnings</th>
            <th>Confidence</th>
            <th>Finding</th>
            <th>Recommendation</th>
          </tr>
        </thead>
        <tbody>
$($rows -join "`n")
        </tbody>
      </table>
    </section>
"@
    }

    $additionalCommitRows = foreach ($result in @($additionalCommitResults | Sort-Object Owner, Repository, CommitSha)) {
        $statusClass = if ($result.IsCleanWithWarnings) { 'clean' } else { 'blocked' }
        $status = if ($result.IsCleanWithWarnings) { 'Clean' } else { 'Review required' }
        $finding = ConvertTo-HtmlText (Join-FindingSummary -Findings @($result.Findings))
        $url = ConvertTo-HtmlText $result.CommitUrl
        $owner = ConvertTo-HtmlText $result.Owner
        $repo = ConvertTo-HtmlText $result.Repository
        $sha = ConvertTo-HtmlText $result.CommitSha
        $warningCount = Get-ResultWarningCount -Result $result
        $confidence = ConvertTo-HtmlText (Get-ResultConfidenceLevel -Result $result)
        $checkedAt = ''
        if (Test-ReportProperty -InputObject $result -Name 'CheckCompletedAtEastern') {
            $checkedAt = ConvertTo-HtmlText $result.CheckCompletedAtEastern
        }
        $recommendation = if (-not $result.IsCleanWithWarnings) {
            'Do not treat this supplied commit as clean. Preserve the SHA and coordinate cleanup/verification.'
        }
        elseif ($warningCount -gt 0) {
            'Special precaution: this supplied commit had scan warnings. Validate before considering the orphaned-commit cleanup complete.'
        }
        else {
            'No listed Miasma indicators found in this supplied commit tree.'
        }
        $recommendationHtml = ConvertTo-HtmlText $recommendation
        @"
          <tr>
            <td>$owner / $repo</td>
            <td><a href="$url">$sha</a></td>
            <td><span class="status $statusClass">$status</span></td>
            <td>$checkedAt</td>
            <td>$warningCount</td>
            <td>$confidence</td>
            <td>$finding</td>
            <td>$recommendationHtml</td>
          </tr>
"@
    }

    $additionalCommitSection = if (@($additionalCommitRows).Count -gt 0) {
        @"
    <section>
      <h2>Known Orphaned / Extra Commits</h2>
      <table>
        <thead>
          <tr>
            <th>Repository</th>
            <th>Commit</th>
            <th>Status</th>
            <th>Checked ET</th>
            <th>Warnings</th>
            <th>Confidence</th>
            <th>Finding</th>
            <th>Recommendation</th>
          </tr>
        </thead>
        <tbody>
$($additionalCommitRows -join "`n")
        </tbody>
      </table>
    </section>
"@
    }
    else {
        ''
    }

    $payloadItems = foreach ($payload in @($Artifact.PayloadIndicators)) {
        '<li>' + (ConvertTo-HtmlText $payload) + '</li>'
    }

    @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>$title</title>
  <style>
    :root { color-scheme: dark; --bg: #111315; --panel: #1b1f24; --line: #343b44; --text: #f2f5f8; --muted: #9da7b3; --green: #1fbf75; --red: #ff5b63; --gold: #e4b84d; --blue: #8bc7ff; }
    * { box-sizing: border-box; }
    body { margin: 0; background: var(--bg); color: var(--text); font: 14px/1.45 "Segoe UI", Arial, sans-serif; }
    header { padding: 28px 32px 18px; border-bottom: 1px solid var(--line); background: #15181c; }
    h1 { margin: 0 0 8px; font-size: 28px; font-weight: 700; }
    h2 { margin: 26px 0 12px; font-size: 18px; }
    h3 { margin: 0 0 8px; font-size: 15px; }
    p { margin: 0 0 10px; }
    .meta { color: var(--muted); }
    .summary { display: grid; grid-template-columns: repeat(4, minmax(140px, 1fr)); gap: 12px; padding: 18px 32px; }
    .metric { background: var(--panel); border: 1px solid var(--line); border-radius: 8px; padding: 14px; }
    .metric strong { display: block; font-size: 24px; margin-bottom: 2px; }
    main { padding: 0 32px 32px; }
    section { margin-top: 22px; }
    .note-grid { display: grid; grid-template-columns: repeat(2, minmax(240px, 1fr)); gap: 12px; }
    .note { background: var(--panel); border: 1px solid var(--line); border-radius: 8px; padding: 14px; }
    .note strong { color: var(--gold); }
    .note ul { margin: 8px 0 0 18px; padding: 0; color: var(--muted); }
    table { width: 100%; border-collapse: collapse; background: var(--panel); border: 1px solid var(--line); border-radius: 8px; overflow: hidden; }
    th, td { padding: 10px 12px; border-bottom: 1px solid var(--line); vertical-align: top; text-align: left; }
    th { color: var(--muted); font-weight: 600; background: #20252b; }
    tr:last-child td { border-bottom: 0; }
    a { color: var(--blue); text-decoration: none; }
    td span { color: var(--muted); font-size: 12px; }
    .status { display: inline-block; border-radius: 999px; padding: 3px 9px; color: #08120d; font-weight: 700; }
    .status.clean { background: var(--green); }
    .status.blocked { background: var(--red); color: #1c0507; }
    .payloads { columns: 2; color: var(--muted); }
    .footer { margin-top: 28px; color: var(--muted); }
    @media (max-width: 900px) { .summary, .note-grid { grid-template-columns: 1fr; } .payloads { columns: 1; } }
  </style>
</head>
<body>
  <header>
    <h1>$title</h1>
    <div class="meta">Scope: $scopeHtml | Closed since: $closedSinceHtml | Generated: $generated</div>
    <div class="meta">JSON: $jsonPathHtml</div>
  </header>
  <div class="summary">
    <div class="metric"><strong>$resultCount</strong>Total PRs checked</div>
    <div class="metric"><strong>$cleanCount</strong>Clean</div>
    <div class="metric"><strong>$blockedCount</strong>Do not reopen</div>
    <div class="metric"><strong>$apiCount</strong>GitHub API calls</div>
  </div>
  <main>
    <section class="note-grid">
      <div class="note">
        <h3>Scan Approach</h3>
        <p>This report was generated from the fixed JSON artifact produced by the PR checker.</p>
        <ul>
          <li>GitHub API only: no clone, no checkout, and no project code execution.</li>
          <li>Checked each current PR commit tree returned by <code>pulls/{number}/commits</code>.</li>
          <li>Checked the current final PR file delta returned by <code>pulls/{number}/files</code>.</li>
          <li>Scanned added patch lines in the final delta for merge-introducing payloads.</li>
          <li>Recorded per-PR check start and completion timestamps in Eastern time for runs started after this script version.</li>
        </ul>
      </div>
      <div class="note">
        <h3>Branch-Tip Report Relationship</h3>
        <p>A clean BranchTip report is strong evidence that current branch tips do not contain the checked indicator paths. This PR report is narrower per PR, but deeper for PR reopen decisions.</p>
        <ul>
          <li>It can still flag indicators in the current PR commit list, even if the current branch tip is clean.</li>
          <li>It can still flag suspicious added lines in the final PR delta.</li>
          <li>If BranchTip is clean and this PR's final diff is clean, the result is normally business as usual for reopening from a merge-risk perspective.</li>
        </ul>
      </div>
      <div class="note">
        <h3>PR Metadata Boundary</h3>
        <p>The scan uses GitHub PR metadata only to locate the source branch, target branch, head SHA, base SHA, current PR commit list, and current PR file list.</p>
        <p>It does not inspect PR comments, approvals, review text, timeline events, Teams chat, or old force-pushed-away SHAs unless those SHAs are still in the current PR commit list or supplied as additional commits.</p>
      </div>
      <div class="note">
        <h3>Orphaned Commit Boundary</h3>
        <p>$orphanedDisclosureHtml</p>
        <p>GitHub can still serve known commit URLs after refs move. This tool cannot reliably enumerate every orphaned or unreachable commit in a repository through the normal GitHub API.</p>
      </div>
      <div class="note">
        <h3>Resume Boundary</h3>
        <p>$resumeDisclosureHtml</p>
      </div>
      <div class="note">
        <h3>Confidence</h3>
        <p><strong>$confidenceLevel</strong>: $confidenceSummary</p>
        <p>This is confidence in the listed Miasma indicator check only. It is not a general malware, secrets, endpoint, or supply-chain audit.</p>
      </div>
      <div class="note">
        <h3>Warnings</h3>
        <p>Warnings are not infection findings. They mean part of the scan could not be completed exactly as intended, such as missing patch text, truncated trees, unread blobs, oversized blobs, or decode failures.</p>
        <p>A clean PR with warnings may still be reopenable, but the warning explains why the report gives lower confidence or calls for a manual look.</p>
      </div>
      <div class="note">
        <h3>Summary Recommendation</h3>
        <p>$recommendationSummary</p>
      </div>
      <div class="note">
        <h3>Disclaimer</h3>
        <p><strong>This is an AI generated report, not a professionally generated security audit.</strong></p>
        <p>Use it as triage evidence for known indicators. Security, InfoSec, or incident-response owners should validate decisions for high-risk branches or production-impacting repositories.</p>
      </div>
    </section>
    <section>
      <h2>Payload Indicators</h2>
      <ul class="payloads">
$($payloadItems -join "`n")
      </ul>
    </section>
$additionalCommitSection
$($sections -join "`n")
    <div class="footer">GitHub API only. No clone, checkout, or project code execution.</div>
  </main>
</body>
</html>
"@
}

function Save-ScanReport {
    param([Parameter(Mandatory)][object]$Artifact)

    if (-not (Test-Path -LiteralPath $artifactDirectory)) {
        New-Item -ItemType Directory -Path $artifactDirectory -Force | Out-Null
    }

    Get-ReportHtml -Artifact $Artifact | Set-Content -LiteralPath $htmlOutputPath -Encoding utf8BOM
    Write-Verbose "HTML report written: $htmlOutputPath"
}

if ($RegenerateReport) {
    $artifact = Read-ScanArtifact
    Save-ScanReport -Artifact $artifact
    if ($Json) {
        $artifact | ConvertTo-Json -Depth 12
    }
    else {
        "HTML report written: $htmlOutputPath"
    }
    return
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'GitHub CLI (gh) is required.'
}

$startedAt = Get-Date
$resumePoint = ConvertFrom-ResumeAfter -Value $ResumeAfter
$additionalCommitTargets = @(Resolve-AdditionalCommitTarget -CommitSpecs $AdditionalCommit)
$targets = @(Resolve-Target)
$targets = @(
    $targets |
        Sort-Object Owner, Repository, @{ Expression = 'PullRequestNumber'; Descending = $true }
)
$targets = @(Select-TargetsAfterResumePoint -Targets $targets -ResumePoint $resumePoint)
$additionalCommitTargets = @(
    $additionalCommitTargets |
        Sort-Object Owner, Repository, CommitSha
)
$results = [System.Collections.Generic.List[object]]::new()
$additionalCommitResults = [System.Collections.Generic.List[object]]::new()
if ($targets.Count -eq 0 -and $additionalCommitTargets.Count -eq 0) {
    if ($PR -gt 0) {
        throw "No accessible PR #$PR found under organization $Organization. Specify -Repo if the repository is known."
    }

    $artifact = Get-ScanArtifact -Targets @() -Results @() -AdditionalCommitTargets @() -AdditionalCommitResults @() -StartedAt $startedAt -CompletedAt (Get-Date)
    Save-ScanArtifact -Artifact $artifact
    if ($Report) {
        Save-ScanReport -Artifact $artifact
    }

    if ($Json) {
        $artifact | ConvertTo-Json -Depth 12
    }
    elseif ($resumePoint) {
        "No remaining PRs found after $($resumePoint.Text)."
    }
    else {
        "No closed PRs found since $closedSinceText."
    }
    return
}

Confirm-MultiRepoScan -Targets @($targets + $additionalCommitTargets)
if ($VerbosePreference -ne 'SilentlyContinue') {
    Write-PayloadVerboseOnce
}

if ($Json) {
    foreach ($target in $targets) {
        $results.Add((Invoke-PrScan -Owner ([string]$target.Owner) -Repository ([string]$target.Repository) -PullRequestNumber ([int]$target.PullRequestNumber))) | Out-Null
    }
    foreach ($target in $additionalCommitTargets) {
        $additionalCommitResults.Add((Invoke-AdditionalCommitScan -Owner ([string]$target.Owner) -Repository ([string]$target.Repository) -CommitSha ([string]$target.CommitSha))) | Out-Null
    }

    $artifact = Get-ScanArtifact -Targets $targets -Results @($results) -AdditionalCommitTargets $additionalCommitTargets -AdditionalCommitResults @($additionalCommitResults) -StartedAt $startedAt -CompletedAt (Get-Date)
    Save-ScanArtifact -Artifact $artifact
    if ($Report) {
        Save-ScanReport -Artifact $artifact
    }
    $artifact | ConvertTo-Json -Depth 12
}
else {
    foreach ($target in $targets) {
        Write-GroupedTargetProgress -Target $target
        $result = Invoke-PrScan -Owner ([string]$target.Owner) -Repository ([string]$target.Repository) -PullRequestNumber ([int]$target.PullRequestNumber)
        $results.Add($result) | Out-Null

        if ($VerbosePreference -ne 'SilentlyContinue') {
            Write-Verbose "Scan result for $($result.Owner)/$($result.Repository)#$($result.PullRequestNumber): commits=$($result.CommitCount) files=$($result.FinalDiffFileCount) findings=$($result.FindingCount) warnings=$($result.WarningCount)"
            foreach ($warning in @($result.Warnings)) {
                Write-Verbose "Warning $($warning.Type) $($warning.CommitSha) $($warning.Path) $($warning.Detail)"
            }
        }

        Write-GroupedResult -Result $result
    }
    foreach ($target in $additionalCommitTargets) {
        $result = Invoke-AdditionalCommitScan -Owner ([string]$target.Owner) -Repository ([string]$target.Repository) -CommitSha ([string]$target.CommitSha)
        $additionalCommitResults.Add($result) | Out-Null

        if ($VerbosePreference -ne 'SilentlyContinue') {
            Write-Verbose "Additional commit result for $($result.Owner)/$($result.Repository)@$($result.CommitSha): findings=$($result.FindingCount) warnings=$($result.WarningCount)"
            foreach ($warning in @($result.Warnings)) {
                Write-Verbose "Warning $($warning.Type) $($warning.CommitSha) $($warning.Path) $($warning.Detail)"
            }
        }

        if ($result.IsCleanWithWarnings) {
            "$($result.Owner)/$($result.Repository)@$($result.CommitSha) - Clean"
        }
        else {
            $summary = Format-FindingSummary -Findings @($result.Findings)
            if ($summary) {
                "$($result.Owner)/$($result.Repository)@$($result.CommitSha) - Review required - $summary"
            }
            else {
                "$($result.Owner)/$($result.Repository)@$($result.CommitSha) - Review required"
            }
        }
    }

    $artifact = Get-ScanArtifact -Targets $targets -Results @($results) -AdditionalCommitTargets $additionalCommitTargets -AdditionalCommitResults @($additionalCommitResults) -StartedAt $startedAt -CompletedAt (Get-Date)
    Save-ScanArtifact -Artifact $artifact
    if ($Report) {
        Save-ScanReport -Artifact $artifact
    }
}

if ($FailOnFinding -and (@($results | Where-Object { -not $_.IsCleanWithWarnings }).Count -gt 0 -or @($additionalCommitResults | Where-Object { -not $_.IsCleanWithWarnings }).Count -gt 0)) {
    exit 2
}
