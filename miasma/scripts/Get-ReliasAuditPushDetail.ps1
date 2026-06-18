#Requires -Version 7.0
<#
.SYNOPSIS
    Resolve a recent Miasma monitor git.push audit id and inspect current branch tips.
.DESCRIPTION
    Reads the local monitor-state.json written by Watch-ReliasAuditMonitor.ps1,
    prints the stored GitHub audit metadata, and performs a read-only GraphQL
    branch-tip indicator check for the pushed repository. GitHub org audit
    git.push events often omit exact ref/SHA; when that happens this script
    reports the limitation and scopes analysis to current default/recent branch
    tips.
.EXAMPLE
    .\scripts\Get-ReliasAuditPushDetail.ps1 -AuditId 4f8a0d12a3bc
#>
[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$AuditId,

    [string]$Owner = 'relias-engineering',

    [string]$StateDirectory,

    [ValidateRange(1, 10)]
    [int]$MaxBranchPages = 4,

    [ValidateRange(1, 100)]
    [int]$BatchSize = 20,

    [switch]$SkipBranchTipScan,

    [switch]$Json
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$skillRoot = Split-Path -Parent $scriptRoot
if (-not $StateDirectory) {
    $StateDirectory = Join-Path $skillRoot "output\monitor\$Owner"
}
$statePath = Join-Path $StateDirectory 'monitor-state.json'

$setupJsPath = '.github/' + 'setup' + '.js'
$indicatorPaths = @(
    $setupJsPath,
    '.claude/settings.json',
    '.gemini/settings.json',
    ('.cursor/rules/' + 'setup' + '.mdc'),
    '.vscode/tasks.json',
    'binding.gyp'
)
$blobDangerPatterns = @(
    @{ Pattern = ('\.github[\\/]set' + 'up\.js'); Reason = 'references the dropper payload path'; Verdict = 'malicious' },
    @{ Pattern = ('Miasma: The Spr' + 'eading Bl' + 'ight'); Reason = 'campaign marker string'; Verdict = 'malicious' },
    @{ Pattern = ('bun\s+run\s+_in' + 'dex\.js'); Reason = 'known worm workflow payload runner'; Verdict = 'malicious' },
    @{ Pattern = ('OIDC_PACK' + 'AGES'); Reason = 'Red Hat npm wave workflow indicator'; Verdict = 'malicious' },
    @{ Pattern = ('"runOn"\s*:\s*"folder' + 'Open"'); Reason = 'VS Code auto-run on folder open'; Verdict = 'suspicious' },
    @{ Pattern = ('"Session' + 'Start"'); Reason = 'agent session-start hook'; Verdict = 'suspicious' },
    @{ Pattern = ('always' + 'Apply:\s*true'); Reason = 'Cursor rule applies automatically'; Verdict = 'suspicious' },
    @{ Pattern = ('curl\s+|wget\s+|Invoke-Web' + 'Request|Download' + 'String|Download' + 'File'); Reason = 'download command inside config'; Verdict = 'suspicious' },
    @{ Pattern = ('child_pro' + 'cess|node\s+-e\s'); Reason = 'inline code execution'; Verdict = 'suspicious' },
    @{ Pattern = ('node\s+\S*in' + 'dex\.js'); Reason = 'invokes node script (worm v2 binding.gyp vector)'; Verdict = 'suspicious' }
)

function Get-HashValue {
    param($Object, [string]$Key, $Default = $null)
    if ($null -eq $Object) { return $Default }
    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($Key)) { return $Object[$Key] }
        return $Default
    }
    $property = $Object.PSObject.Properties[$Key]
    if ($null -ne $property) { return $property.Value }
    return $Default
}

function Format-IsoTimestamp {
    param($Value)

    if ($null -eq $Value) { return '' }
    if ($Value -is [DateTimeOffset]) { return $Value.UtcDateTime.ToString('o') }
    if ($Value -is [datetime]) { return $Value.ToUniversalTime().ToString('o') }
    return [string]$Value
}

function ConvertTo-GraphQLString {
    param([AllowNull()][string]$Value)
    return ($Value | ConvertTo-Json -Compress)
}

function Invoke-GhApiJson {
    param([Parameter(Mandatory)][string[]]$Arguments)

    $stderrPath = [System.IO.Path]::GetTempFileName()
    try {
        $raw = & gh api @Arguments 2>$stderrPath
        if ($LASTEXITCODE -ne 0 -or -not $raw) {
            $detail = ''
            if (Test-Path -LiteralPath $stderrPath) {
                $detail = ((Get-Content -LiteralPath $stderrPath -Raw) -as [string]).Trim()
            }
            throw "gh api failed: $detail"
        }
        return ($raw -join "`n") | ConvertFrom-Json
    }
    finally {
        Remove-Item -LiteralPath $stderrPath -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-GhGraphqlJson {
    param([Parameter(Mandatory)][string]$Query)
    return Invoke-GhApiJson -Arguments @('graphql', '-f', "query=$Query")
}

function Get-AuditEventShortId {
    param([Parameter(Mandatory)][string]$Id)

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Id)
        $hash = $sha.ComputeHash($bytes)
        return (($hash | Select-Object -First 6 | ForEach-Object { $_.ToString('x2') }) -join '')
    }
    finally {
        $sha.Dispose()
    }
}

function Resolve-PushEvent {
    param(
        [Parameter(Mandatory)]$State,
        [Parameter(Mandatory)][string]$IdOrShortId
    )

    $events = Get-HashValue $State 'recentPushEvents' @{}
    if ($events.Count -eq 0) {
        throw "No recentPushEvents in $statePath. Wait for a new monitor cycle with pushes, or restart the monitor after this update."
    }

    $matchingEvents = [System.Collections.ArrayList]::new()
    foreach ($entry in @($events.GetEnumerator())) {
        $fullId = [string]$entry.Key
        $value = $entry.Value
        $shortId = [string](Get-HashValue $value 'ShortId' '')
        if ($fullId -eq $IdOrShortId -or $shortId -eq $IdOrShortId -or $fullId.StartsWith($IdOrShortId, [StringComparison]::OrdinalIgnoreCase)) {
            [void]$matchingEvents.Add([pscustomobject]@{ Id = $fullId; Event = $value })
        }
    }

    if ($matchingEvents.Count -eq 0) {
        throw "Audit id '$IdOrShortId' was not found in recentPushEvents in $statePath."
    }
    if ($matchingEvents.Count -gt 1) {
        $ids = @($matchingEvents | ForEach-Object { '{0} ({1})' -f $_.Id, (Get-HashValue $_.Event 'ShortId' '') })
        throw "Audit id '$IdOrShortId' is ambiguous: $($ids -join ', ')"
    }
    return $matchingEvents[0]
}

function Get-RepoBranchTips {
    param([Parameter(Mandatory)][string]$RepoName)

    $branches = [System.Collections.ArrayList]::new()
    $defaultBranch = ''
    $cursor = $null
    $page = 0
    do {
        $page++
        $cursorArgument = if ($cursor) { ', after: ' + (ConvertTo-GraphQLString $cursor) } else { '' }
        $query = @"
query {
  repository(owner: $(ConvertTo-GraphQLString $Owner), name: $(ConvertTo-GraphQLString $RepoName)) {
    url
    defaultBranchRef { name }
    refs(refPrefix: "refs/heads/", first: 100$cursorArgument) {
      nodes {
        name
        target {
          ... on Commit {
            oid
            committedDate
            messageHeadline
            author { name email }
            committer { name email }
          }
        }
      }
      pageInfo { hasNextPage endCursor }
    }
  }
}
"@
        $response = Invoke-GhGraphqlJson -Query $query
        $repository = Get-HashValue (Get-HashValue $response 'data') 'repository'
        if ($null -eq $repository) { throw "Repository not found or inaccessible: $Owner/$RepoName" }

        $defaultBranchRef = Get-HashValue $repository 'defaultBranchRef'
        if ($null -ne $defaultBranchRef) {
            $defaultBranch = [string](Get-HashValue $defaultBranchRef 'name' '')
        }

        foreach ($node in @($repository.refs.nodes)) {
            $target = Get-HashValue $node 'target'
            if ((Get-HashValue $node 'name') -and $null -ne $target -and (Get-HashValue $target 'oid')) {
                [void]$branches.Add([pscustomobject]@{
                    Name = [string]$node.name
                    Target = $target
                })
            }
        }

        $cursor = [string]$repository.refs.pageInfo.endCursor
        $hasNextPage = [bool]$repository.refs.pageInfo.hasNextPage
        if ($hasNextPage -and $page -ge $MaxBranchPages) {
            $hasNextPage = $false
        }
    } while ($hasNextPage)

    return [pscustomobject]@{
        Branches = @($branches)
        DefaultBranch = $defaultBranch
    }
}

function Get-BranchTipIndicatorMatches {
    param(
        [Parameter(Mandatory)][string]$RepoName,
        [Parameter()][AllowEmptyCollection()][object[]]$Branches = @()
    )

    $tipMatches = [System.Collections.ArrayList]::new()
    $Branches = @($Branches)
    if ($Branches.Count -eq 0) { return @($tipMatches) }

    for ($offset = 0; $offset -lt $Branches.Count; $offset += $BatchSize) {
        $batch = @($Branches | Select-Object -Skip $offset -First $BatchSize)
        $aliasMap = @{}
        $fieldLines = [System.Collections.Generic.List[string]]::new()
        $aliasIndex = 0

        foreach ($branch in $batch) {
            foreach ($path in $indicatorPaths) {
                $alias = "p$aliasIndex"
                $expression = '{0}:{1}' -f [string]$branch.Name, $path
                $fieldLines.Add("    ${alias}: object(expression: $(ConvertTo-GraphQLString $expression)) { ... on Blob { oid byteSize } ... on Tree { oid } }") | Out-Null
                $aliasMap[$alias] = [pscustomobject]@{ Branch = $branch; Path = $path }
                $aliasIndex++
            }
        }
        if ($fieldLines.Count -eq 0) { continue }

        $query = @"
query {
  repository(owner: $(ConvertTo-GraphQLString $Owner), name: $(ConvertTo-GraphQLString $RepoName)) {
$($fieldLines -join "`n")
  }
}
"@
        $response = Invoke-GhGraphqlJson -Query $query
        $repository = Get-HashValue (Get-HashValue $response 'data') 'repository'
        if ($null -eq $repository) { continue }

        foreach ($property in @($repository.PSObject.Properties)) {
            if ($null -eq $property.Value) { continue }
            if (-not $aliasMap.ContainsKey($property.Name)) { continue }

            $hit = $aliasMap[$property.Name]
            $target = $hit.Branch.Target
            [void]$tipMatches.Add([pscustomobject]@{
                Repository = $RepoName
                Branch = [string]$hit.Branch.Name
                Path = [string]$hit.Path
                BlobSha = [string](Get-HashValue $property.Value 'oid' '')
                ByteSize = [long](Get-HashValue $property.Value 'byteSize' 0)
                TipSha = [string](Get-HashValue $target 'oid' '')
                CommittedDate = [string](Get-HashValue $target 'committedDate' '')
                Author = [string](Get-HashValue (Get-HashValue $target 'author') 'name' '')
                Subject = [string](Get-HashValue $target 'messageHeadline' '')
            })
        }
    }

    return @($tipMatches)
}

function Get-BlobVerdict {
    param(
        [Parameter(Mandatory)][string]$RepoName,
        [Parameter(Mandatory)][string]$Path,
        [string]$BlobSha,
        [long]$ByteSize = 0
    )

    if ($Path -eq $setupJsPath) {
        return [pscustomobject]@{ Verdict = 'malicious'; Reasons = @("high-signal dropper path $setupJsPath exists at branch tip") }
    }
    if (-not $BlobSha) {
        return [pscustomobject]@{ Verdict = 'suspicious'; Reasons = @('indicator path exists but blob SHA unavailable') }
    }
    if ($ByteSize -gt 524288) {
        return [pscustomobject]@{ Verdict = 'suspicious'; Reasons = @("config blob unusually large ($ByteSize bytes); not fetched") }
    }

    $blob = Invoke-GhApiJson -Arguments @("repos/$Owner/$RepoName/git/blobs/$BlobSha")
    $content = ''
    try {
        $encoded = ([string](Get-HashValue $blob 'content' '')) -replace '\s', ''
        $content = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($encoded))
    }
    catch {
        return [pscustomobject]@{ Verdict = 'suspicious'; Reasons = @('content could not be decoded') }
    }

    $reasons = [System.Collections.Generic.List[string]]::new()
    $maliciousHits = 0
    $suspiciousHits = 0
    foreach ($rule in $blobDangerPatterns) {
        if ($content -match $rule.Pattern) {
            $reasons.Add(('{0} [{1}]' -f $rule.Reason, $rule.Verdict)) | Out-Null
            if ($rule.Verdict -eq 'malicious') { $maliciousHits++ } else { $suspiciousHits++ }
        }
    }

    $verdict = 'benign'
    if ($maliciousHits -gt 0 -or $suspiciousHits -ge 2) { $verdict = 'malicious' }
    elseif ($suspiciousHits -eq 1) { $verdict = 'suspicious' }
    if ($reasons.Count -eq 0) { $reasons.Add('no dangerous content patterns matched') | Out-Null }

    return [pscustomobject]@{ Verdict = $verdict; Reasons = @($reasons) }
}

if (-not (Test-Path -LiteralPath $statePath)) {
    throw "State file not found: $statePath"
}

$state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json -AsHashtable
$resolved = Resolve-PushEvent -State $state -IdOrShortId $AuditId
$pushEvent = $resolved.Event
$repoFull = [string](Get-HashValue $pushEvent 'Repo' '')
$repoName = [string](Get-HashValue $pushEvent 'RepoName' '')
if (-not $repoName -and $repoFull) { $repoName = ($repoFull -split '/')[-1] }
if ($repoFull -match '^([^/]+)/(.+)$') {
    $Owner = $Matches[1]
    $repoName = $Matches[2]
}

$timestampMs = [long](Get-HashValue $pushEvent 'TimestampMs' 0)
$since = if ($timestampMs -gt 0) { [DateTimeOffset]::FromUnixTimeMilliseconds($timestampMs).AddHours(-2) } else { [DateTimeOffset]::UtcNow.AddHours(-2) }
$exactFields = @{
    Ref = [string](Get-HashValue $pushEvent 'Ref' '')
    Branch = [string](Get-HashValue $pushEvent 'Branch' '')
    HeadSha = [string](Get-HashValue $pushEvent 'HeadSha' '')
    Before = [string](Get-HashValue $pushEvent 'Before' '')
    After = [string](Get-HashValue $pushEvent 'After' '')
}
$hasExactRef = @($exactFields.Values | Where-Object { $_ }).Count -gt 0

$analysis = [ordered]@{
    AuditId = $resolved.Id
    ShortId = [string](Get-HashValue $pushEvent 'ShortId' (Get-AuditEventShortId -Id $resolved.Id))
    Actor = [string](Get-HashValue $pushEvent 'Actor' '')
    Repository = $repoFull
    RepositoryUrl = if ($repoFull) { "https://github.com/$repoFull" } else { '' }
    TimestampUtc = Format-IsoTimestamp (Get-HashValue $pushEvent 'TimestampUtc' '')
    ProgrammaticAccessType = [string](Get-HashValue $pushEvent 'ProgrammaticAccessType' '')
    TransportProtocolName = [string](Get-HashValue $pushEvent 'TransportProtocolName' '')
    UserAgent = [string](Get-HashValue $pushEvent 'UserAgent' '')
    ExactRefFields = $exactFields
    ExactRefAvailable = $hasExactRef
    ScopeNote = if ($hasExactRef) { 'Audit event included at least one ref/SHA field.' } else { 'Audit event did not include exact ref/SHA; branch-tip scan is current default/recent branch tips, not definitive pushed ref attribution.' }
    BranchTipScan = $null
    RawAuditEvent = Get-HashValue $pushEvent 'Raw' $null
}

if (-not $SkipBranchTipScan) {
    $tips = Get-RepoBranchTips -RepoName $repoName
    $candidates = [System.Collections.ArrayList]::new()
    foreach ($branch in @($tips.Branches)) {
        $committedRaw = [string](Get-HashValue $branch.Target 'committedDate' '')
        $isDefault = ($branch.Name -eq $tips.DefaultBranch)
        $isRecent = $false
        if ($committedRaw) {
            $isRecent = ([DateTimeOffset]::Parse($committedRaw, [cultureinfo]::InvariantCulture) -ge $since)
        }
        if ($isRecent -or $isDefault) {
            [void]$candidates.Add($branch)
        }
    }

    $indicatorMatches = Get-BranchTipIndicatorMatches -RepoName $repoName -Branches @($candidates)
    $findings = [System.Collections.ArrayList]::new()
    foreach ($match in @($indicatorMatches)) {
        $verdict = Get-BlobVerdict -RepoName $repoName -Path $match.Path -BlobSha $match.BlobSha -ByteSize $match.ByteSize
        [void]$findings.Add([pscustomobject]@{
            Branch = $match.Branch
            Path = $match.Path
            Verdict = $verdict.Verdict
            Reasons = @($verdict.Reasons)
            BlobSha = $match.BlobSha
            ByteSize = $match.ByteSize
            TipSha = $match.TipSha
            CommittedDate = $match.CommittedDate
            Author = $match.Author
            Subject = $match.Subject
            BranchUrl = "https://github.com/$Owner/$repoName/tree/$([uri]::EscapeDataString($match.Branch))"
            CommitUrl = "https://github.com/$Owner/$repoName/commit/$($match.TipSha)"
        })
    }

    $analysis.BranchTipScan = [ordered]@{
        Scope = 'current default branch plus branches with tip commits since audit timestamp minus 2h'
        DefaultBranch = $tips.DefaultBranch
        BranchesSeen = @($tips.Branches).Count
        CandidateBranches = @($candidates | ForEach-Object {
            [pscustomobject]@{
                Name = $_.Name
                TipSha = [string](Get-HashValue $_.Target 'oid' '')
                CommittedDate = [string](Get-HashValue $_.Target 'committedDate' '')
                Subject = [string](Get-HashValue $_.Target 'messageHeadline' '')
            }
        })
        IndicatorFindings = @($findings)
    }
}

if ($Json) {
    $analysis | ConvertTo-Json -Depth 20
    return
}

Write-Host "Audit push detail" -ForegroundColor Cyan
Write-Host ("  id:        {0} ({1})" -f $analysis.AuditId, $analysis.ShortId)
Write-Host ("  actor:     {0}" -f $analysis.Actor)
Write-Host ("  repo:      {0}" -f $analysis.Repository)
Write-Host ("  repo url:  {0}" -f $analysis.RepositoryUrl)
Write-Host ("  time utc:  {0}" -f $analysis.TimestampUtc)
Write-Host ("  access:    {0}" -f $analysis.ProgrammaticAccessType)
Write-Host ("  transport: {0}" -f $analysis.TransportProtocolName)
Write-Host ("  userAgent: {0}" -f $analysis.UserAgent)

Write-Host ''
Write-Host 'Exact ref/SHA fields' -ForegroundColor Cyan
foreach ($key in @('Ref', 'Branch', 'HeadSha', 'Before', 'After')) {
    $value = [string]$analysis.ExactRefFields[$key]
    if (-not $value) { $value = '(not provided)' }
    Write-Host ("  {0,-7} {1}" -f "${key}:", $value)
}
Write-Host ("  note:    {0}" -f $analysis.ScopeNote)

if ($analysis.BranchTipScan) {
    Write-Host ''
    Write-Host 'Branch-tip scan' -ForegroundColor Cyan
    Write-Host ("  scope:      {0}" -f $analysis.BranchTipScan.Scope)
    Write-Host ("  branches:   {0} seen, {1} candidates" -f $analysis.BranchTipScan.BranchesSeen, @($analysis.BranchTipScan.CandidateBranches).Count)
    Write-Host ("  indicators: {0}" -f @($analysis.BranchTipScan.IndicatorFindings).Count)

    foreach ($candidate in @($analysis.BranchTipScan.CandidateBranches | Select-Object -First 20)) {
        Write-Host ("  candidate:  {0} {1} {2}" -f $candidate.Name, $candidate.TipSha, $candidate.Subject)
    }
    if (@($analysis.BranchTipScan.CandidateBranches).Count -gt 20) {
        Write-Host ("  candidate:  ... {0} more" -f (@($analysis.BranchTipScan.CandidateBranches).Count - 20))
    }

    foreach ($finding in @($analysis.BranchTipScan.IndicatorFindings)) {
        $reason = (@($finding.Reasons) -join '; ')
        Write-Host ("  finding:    {0}:{1} verdict={2} blob={3}" -f $finding.Branch, $finding.Path, $finding.Verdict, $finding.BlobSha)
        Write-Host ("              {0}" -f $reason)
        Write-Host ("              {0}" -f $finding.CommitUrl)
    }
}
