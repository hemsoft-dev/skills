[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter()]
    [string]$Owner = 'relias-engineering',

    [Parameter()]
    [ValidateSet('', 'public', 'private', 'internal')]
    [string]$Visibility = '',

    [Parameter()]
    [datetime]$Since = (Get-Date -Year (Get-Date).Year -Month 5 -Day 1 -Hour 0 -Minute 0 -Second 0),

    [Parameter()]
    [datetime]$Until = (Get-Date),

    [Parameter()]
    [ValidateSet('BranchTip', 'CommitWindow', 'Both')]
    [string]$ScanMode = 'BranchTip',

    [Parameter()]
    [string]$OutputDirectory,

    [Parameter()]
    [Alias('JsonOutPath')]
    [string]$JsonOutputPath,

    [Parameter()]
    [Alias('TextOutPath')]
    [string]$TextOutputPath,

    [Parameter()]
    [string[]]$RepositoryName = @(),

    [Parameter()]
    [string]$RepositoryNamePath,

    [Parameter()]
    [ValidateRange(0, 5000)]
    [int]$RepositoryLimit = 0,

    [Parameter()]
    [ValidateRange(0, 5000)]
    [int]$ThrottleMilliseconds = 250
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$skillRoot = Split-Path -Parent $scriptRoot
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $skillRoot "output\remote\$Owner\$stamp"
}
if (-not $JsonOutputPath) {
    $JsonOutputPath = Join-Path $OutputDirectory 'miasma-remote-scan.json'
}
if (-not $TextOutputPath) {
    $TextOutputPath = Join-Path $OutputDirectory 'miasma-remote-scan.txt'
}

$indicatorPaths = @(
    '.github/setup.js',
    '.claude/settings.json',
    '.gemini/settings.json',
    '.cursor/rules/setup.mdc',
    '.vscode/tasks.json',
    'binding.gyp'
)
$criticalPath = '.github/setup.js'
$sinceIso = $Since.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$untilIso = $Until.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$apiRequestCount = 0
$scanErrors = [System.Collections.Generic.List[object]]::new()
$lastGhExitCode = 0
$lastGhError = ''
$apiThrottleMilliseconds = $ThrottleMilliseconds

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
        if ($script:apiThrottleMilliseconds -gt 0) {
            Start-Sleep -Milliseconds $script:apiThrottleMilliseconds
        }
    }
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
        if ($script:apiThrottleMilliseconds -gt 0) {
            Start-Sleep -Milliseconds $script:apiThrottleMilliseconds
        }
    }
}

function Invoke-GhGraphqlJson {
    param([Parameter(Mandatory)][string]$Query)

    $script:apiRequestCount++
    $script:lastGhExitCode = 0
    $script:lastGhError = ''
    $previousErrorActionPreference = $ErrorActionPreference
    $stderrPath = [System.IO.Path]::GetTempFileName()
    try {
        $ErrorActionPreference = 'Continue'
        $raw = & gh api graphql -f "query=$Query" 2>$stderrPath
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
        if ($script:apiThrottleMilliseconds -gt 0) {
            Start-Sleep -Milliseconds $script:apiThrottleMilliseconds
        }
    }
}

function ConvertTo-GraphQLString {
    param([AllowNull()][string]$Value)

    return ($Value | ConvertTo-Json -Compress)
}

function Get-PaginatedGhApi {
    param(
        [Parameter(Mandatory)][string]$PathWithQuery,
        [Parameter()][string]$FailureType,
        [Parameter()][string]$Repository,
        [Parameter()][string]$Branch
    )

    $pages = Invoke-GhApiJson -Arguments @('--paginate', '--slurp', $PathWithQuery)
    if ($null -eq $pages) {
        if ($FailureType) {
            $scanErrors.Add([pscustomobject]@{
                Repository = $Repository
                Branch = $Branch
                Type = $FailureType
                Path = $PathWithQuery
                ExitCode = $script:lastGhExitCode
                Message = $script:lastGhError
            }) | Out-Null
        }
        return @()
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

function Write-ScanLine {
    param([AllowEmptyString()][string]$Line)

    $Line
    Add-Content -LiteralPath $TextOutputPath -Value $Line
}

function Add-CommitRecord {
    param(
        [Parameter(Mandatory)][hashtable]$CommitBySha,
        [Parameter(Mandatory)][object]$Commit,
        [Parameter(Mandatory)][string]$BranchName
    )

    $sha = [string]$Commit.sha
    if (-not $sha) {
        return
    }

    if (-not $CommitBySha.ContainsKey($sha)) {
        $CommitBySha[$sha] = [pscustomobject]@{
            Sha = $sha
            TreeSha = [string]$Commit.commit.tree.sha
            AuthorDate = [string]$Commit.commit.author.date
            CommitterDate = [string]$Commit.commit.committer.date
            Author = [string]$Commit.commit.author.name
            Committer = [string]$Commit.commit.committer.name
            Subject = (([string]$Commit.commit.message) -split "`n", 2)[0]
            Branches = [System.Collections.ArrayList]::new()
            MatchedPaths = @()
            TreeTruncated = $false
        }
    }

    if (-not $CommitBySha[$sha].Branches.Contains($BranchName)) {
        [void]$CommitBySha[$sha].Branches.Add($BranchName)
    }
}

function Add-FindingRecord {
    param(
        [Parameter(Mandatory)][hashtable]$CommitBySha,
        [Parameter(Mandatory)][object]$Branch,
        [Parameter(Mandatory)][string]$MatchedPath
    )

    $target = $Branch.Target
    $sha = [string]$target.oid
    if (-not $sha) {
        return
    }

    if (-not $CommitBySha.ContainsKey($sha)) {
        $CommitBySha[$sha] = [pscustomobject]@{
            Sha = $sha
            TreeSha = ''
            AuthorDate = [string]$target.committedDate
            CommitterDate = [string]$target.committedDate
            Author = [string]$target.author.name
            Committer = [string]$target.committer.name
            Subject = [string]$target.messageHeadline
            Branches = [System.Collections.ArrayList]::new()
            MatchedPaths = [System.Collections.ArrayList]::new()
            TreeTruncated = $false
        }
    }

    if (-not $CommitBySha[$sha].Branches.Contains([string]$Branch.Name)) {
        [void]$CommitBySha[$sha].Branches.Add([string]$Branch.Name)
    }
    if (-not $CommitBySha[$sha].MatchedPaths.Contains($MatchedPath)) {
        [void]$CommitBySha[$sha].MatchedPaths.Add($MatchedPath)
    }
}

function Get-GraphqlBranchTip {
    param(
        [Parameter(Mandatory)][string]$RepositoryOwner,
        [Parameter(Mandatory)][string]$RepositoryName
    )

    $branches = [System.Collections.ArrayList]::new()
    $cursor = $null
    do {
        $cursorArgument = if ($cursor) { ', after: ' + (ConvertTo-GraphQLString $cursor) } else { '' }
        $query = @"
query {
  repository(owner: $(ConvertTo-GraphQLString $RepositoryOwner), name: $(ConvertTo-GraphQLString $RepositoryName)) {
    refs(refPrefix: "refs/heads/", first: 100$cursorArgument) {
      nodes {
        name
        target {
          ... on Commit {
            oid
            committedDate
            messageHeadline
            author { name }
            committer { name }
          }
        }
      }
      pageInfo { hasNextPage endCursor }
    }
  }
}
"@
        $response = Invoke-GhGraphqlJson -Query $query
        if ($null -eq $response -or $null -eq $response.data.repository) {
            $scanErrors.Add([pscustomobject]@{
                Repository = $RepositoryName
                Type = 'graphql-branch-list-failed'
                ExitCode = $script:lastGhExitCode
                Message = $script:lastGhError
            }) | Out-Null
            break
        }

        foreach ($node in @($response.data.repository.refs.nodes)) {
            if ($node.name -and $node.target -and $node.target.oid) {
                [void]$branches.Add([pscustomobject]@{
                    Name = [string]$node.name
                    Target = $node.target
                })
            }
        }

        $cursor = [string]$response.data.repository.refs.pageInfo.endCursor
        $hasNextPage = [bool]$response.data.repository.refs.pageInfo.hasNextPage
    } while ($hasNextPage)

    return @($branches)
}

function Add-GraphqlBranchTipFinding {
    param(
        [Parameter(Mandatory)][string]$RepositoryOwner,
        [Parameter(Mandatory)][string]$RepositoryName,
        [Parameter()]
        [AllowEmptyCollection()]
        [object[]]$Branches = @(),
        [Parameter(Mandatory)][string[]]$Paths,
        [Parameter(Mandatory)][hashtable]$CommitBySha,
        [Parameter()][int]$BatchSize = 25
    )

    $Branches = @($Branches)
    if ($Branches.Count -eq 0) {
        return
    }

    for ($offset = 0; $offset -lt $Branches.Count; $offset += $BatchSize) {
        $batch = @($Branches | Select-Object -Skip $offset -First $BatchSize)
        $aliasMap = @{}
        $fieldLines = [System.Collections.Generic.List[string]]::new()
        $aliasIndex = 0

        foreach ($branch in $batch) {
            foreach ($path in $Paths) {
                $alias = "p$aliasIndex"
                $expression = '{0}:{1}' -f [string]$branch.Name, $path
                $fieldLines.Add("    ${alias}: object(expression: $(ConvertTo-GraphQLString $expression)) { ... on Blob { oid byteSize } ... on Tree { oid } }") | Out-Null
                $aliasMap[$alias] = [pscustomobject]@{
                    Branch = $branch
                    Path = $path
                }
                $aliasIndex++
            }
        }

        if ($fieldLines.Count -eq 0) {
            continue
        }

        $query = @"
query {
  repository(owner: $(ConvertTo-GraphQLString $RepositoryOwner), name: $(ConvertTo-GraphQLString $RepositoryName)) {
$($fieldLines -join "`n")
  }
}
"@
        $response = Invoke-GhGraphqlJson -Query $query
        if ($null -eq $response -or $null -eq $response.data.repository) {
            $scanErrors.Add([pscustomobject]@{
                Repository = $RepositoryName
                Type = 'graphql-path-check-failed'
                BranchOffset = $offset
                BranchCount = $batch.Count
                PathCount = $Paths.Count
                ExitCode = $script:lastGhExitCode
                Message = $script:lastGhError
            }) | Out-Null
            continue
        }

        foreach ($property in @($response.data.repository.PSObject.Properties)) {
            if ($null -eq $property.Value) {
                continue
            }
            if (-not $aliasMap.ContainsKey($property.Name)) {
                continue
            }

            $match = $aliasMap[$property.Name]
            Add-FindingRecord -CommitBySha $CommitBySha -Branch $match.Branch -MatchedPath $match.Path
        }
    }
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'GitHub CLI (gh) is required.'
}

$jsonParent = Split-Path -Parent $JsonOutputPath
if ($jsonParent -and -not (Test-Path -LiteralPath $jsonParent)) {
    New-Item -ItemType Directory -Path $jsonParent -Force | Out-Null
}
$textParent = Split-Path -Parent $TextOutputPath
if ($textParent -and -not (Test-Path -LiteralPath $textParent)) {
    New-Item -ItemType Directory -Path $textParent -Force | Out-Null
}

Set-Content -LiteralPath $TextOutputPath -Value @(
    "Remote API Miasma scan for $Owner",
    "Window: $sinceIso through $untilIso",
    "Started: $(Get-Date -Format o)",
    "Scan mode: $ScanMode",
    'Mode: GitHub API only, no clone, no checkout, no code execution',
    "Output directory: $OutputDirectory",
    ''
)

$startedAt = Get-Date
$repoListArgs = @(
    'repo',
    'list',
    $Owner,
    '--limit',
    '5000',
    '--json',
    'name,isArchived,isFork,visibility'
)
if ($Visibility) {
    $repoListArgs += @('--visibility', $Visibility)
}

$repos = Invoke-GhJson -Arguments $repoListArgs
if ($null -eq $repos) {
    throw "Unable to list repositories for $Owner with gh. ExitCode=$script:lastGhExitCode Message=$script:lastGhError"
}

if ($RepositoryNamePath) {
    if (-not (Test-Path -LiteralPath $RepositoryNamePath)) {
        throw "RepositoryNamePath not found: $RepositoryNamePath"
    }

    $RepositoryName += @(Get-Content -LiteralPath $RepositoryNamePath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

if ($RepositoryName.Count -gt 0) {
    $wanted = @{}
    foreach ($name in $RepositoryName) {
        if ($name) {
            $wanted[$name.ToLowerInvariant()] = $true
        }
    }
    $repos = @($repos | Where-Object { $wanted.ContainsKey(([string]$_.name).ToLowerInvariant()) })
}
if ($RepositoryLimit -gt 0) {
    $repos = @($repos | Select-Object -First $RepositoryLimit)
}

$results = [System.Collections.ArrayList]::new()
$repoIndex = 0

foreach ($repo in @($repos)) {
    $repoIndex++
    $repoName = [string]$repo.name
    Write-Progress -Activity "Remote Miasma scan: $Owner" -Status "$repoIndex/$(@($repos).Count) $repoName" -PercentComplete (($repoIndex / [math]::Max(@($repos).Count, 1)) * 100)
    Write-ScanLine "Scanning $repoIndex/$(@($repos).Count): $repoName"

    if ($ScanMode -eq 'BranchTip') {
        $branches = Get-GraphqlBranchTip -RepositoryOwner $Owner -RepositoryName $repoName
    }
    else {
        $branches = Get-PaginatedGhApi -PathWithQuery "repos/$Owner/$repoName/branches?per_page=100" -FailureType 'branch-list-failed' -Repository $repoName
    }
    $commitBySha = @{}

    if ($ScanMode -eq 'BranchTip') {
        Add-GraphqlBranchTipFinding -RepositoryOwner $Owner -RepositoryName $repoName -Branches @($branches) -Paths $indicatorPaths -CommitBySha $commitBySha
    }
    else {
        foreach ($branch in $branches) {
            $branchName = [string]$branch.name
            if (-not $branchName) {
                continue
            }

            if ($ScanMode -eq 'CommitWindow' -or $ScanMode -eq 'Both') {
                $branchEscaped = [uri]::EscapeDataString($branchName)
                $commitPages = Get-PaginatedGhApi -PathWithQuery "repos/$Owner/$repoName/commits?sha=$branchEscaped&since=$sinceIso&until=$untilIso&per_page=100" -FailureType 'branch-commit-list-failed' -Repository $repoName -Branch $branchName

                foreach ($commit in $commitPages) {
                    Add-CommitRecord -CommitBySha $commitBySha -Commit $commit -BranchName $branchName
                }
            }

            if ($ScanMode -eq 'Both') {
                $tipSha = [string]$branch.commit.sha
                if (-not $tipSha) {
                    continue
                }

                if ($commitBySha.ContainsKey($tipSha)) {
                    if (-not $commitBySha[$tipSha].Branches.Contains($branchName)) {
                        [void]$commitBySha[$tipSha].Branches.Add($branchName)
                    }
                    continue
                }

                $tipCommit = Invoke-GhApiJson -Arguments @("repos/$Owner/$repoName/commits/$tipSha")
                if ($null -eq $tipCommit) {
                    $scanErrors.Add([pscustomobject]@{
                        Repository = $repoName
                        Branch = $branchName
                        Sha = $tipSha
                        Type = 'tip-commit-read-failed'
                        ExitCode = $script:lastGhExitCode
                        Message = $script:lastGhError
                    }) | Out-Null
                    continue
                }

                Add-CommitRecord -CommitBySha $commitBySha -Commit $tipCommit -BranchName $branchName
            }
        }
    }

    if ($ScanMode -ne 'BranchTip') {
        $treePathCache = @{}
        foreach ($commit in @($commitBySha.Values)) {
            if (-not $commit.TreeSha) {
                continue
            }

            if (-not $treePathCache.ContainsKey($commit.TreeSha)) {
                $tree = Invoke-GhApiJson -Arguments @("repos/$Owner/$repoName/git/trees/$($commit.TreeSha)?recursive=1")
                if ($null -eq $tree) {
                    $treePathCache[$commit.TreeSha] = [pscustomobject]@{
                        Paths = @{}
                        Truncated = $true
                    }
                    $scanErrors.Add([pscustomobject]@{
                        Repository = $repoName
                        TreeSha = $commit.TreeSha
                        Type = 'tree-read-failed'
                        ExitCode = $script:lastGhExitCode
                        Message = $script:lastGhError
                    }) | Out-Null
                }
                else {
                    $paths = @{}
                    foreach ($entry in @($tree.tree)) {
                        if ($entry.type -eq 'blob' -or $entry.type -eq 'tree') {
                            $paths[[string]$entry.path] = $true
                        }
                    }

                    $treePathCache[$commit.TreeSha] = [pscustomobject]@{
                        Paths = $paths
                        Truncated = [bool]$tree.truncated
                    }
                }
            }

            $treeInfo = $treePathCache[$commit.TreeSha]
            $matchedPaths = foreach ($indicator in $indicatorPaths) {
                if ($treeInfo.Paths.ContainsKey($indicator)) {
                    $indicator
                }
            }

            $commit.MatchedPaths = @($matchedPaths)
            $commit.TreeTruncated = $treeInfo.Truncated
        }
    }

    $findings = @($commitBySha.Values | Where-Object { $_.MatchedPaths.Count -gt 0 })
    [void]$results.Add([pscustomobject]@{
        Repository = $repoName
        IsArchived = [bool]$repo.isArchived
        IsFork = [bool]$repo.isFork
        Visibility = [string]$repo.visibility
        BranchCount = @($branches).Count
        ScannedCommitCount = @($commitBySha.Values).Count
        JuneCommitCount = @($commitBySha.Values).Count
        FindingCount = $findings.Count
        Findings = @($findings | Sort-Object CommitterDate, Sha)
    })

    Write-ScanLine "Done $repoName branches=$(@($branches).Count) commits=$(@($commitBySha.Values).Count) findings=$($findings.Count)"
    foreach ($finding in $findings | Sort-Object CommitterDate, Sha) {
        Write-ScanLine "MATCH $repoName $($finding.Sha.Substring(0, 12)) paths=[$($finding.MatchedPaths -join ', ')] committerDate=$($finding.CommitterDate) author=$($finding.Author) committer=$($finding.Committer) branches=[$($finding.Branches -join ', ')] subject=$($finding.Subject)"
    }
}

Write-Progress -Activity "Remote Miasma scan: $Owner" -Completed

$affectedRepos = @($results | Where-Object { $_.FindingCount -gt 0 })
$criticalRepos = @($results | Where-Object {
    @($_.Findings | Where-Object { $_.MatchedPaths -contains $criticalPath }).Count -gt 0
})

$summary = [pscustomobject]@{
    Owner = $Owner
    StartedAt = $startedAt.ToString('o')
    FinishedAt = (Get-Date).ToString('o')
    Since = $sinceIso
    Until = $untilIso
    ScanMode = $ScanMode
    RepositoriesScanned = @($repos).Count
    Visibility = if ($Visibility) { $Visibility } else { 'all-visible' }
    RepositoryFilter = @($RepositoryName)
    RepositoryLimit = $RepositoryLimit
    ApiRequestsApproximate = $apiRequestCount
    RepositoriesWithSetupJs = $criticalRepos.Count
    RepositoriesWithAnyIndicator = $affectedRepos.Count
    IndicatorPaths = $indicatorPaths
    Errors = @($scanErrors)
    Results = @($results | Sort-Object Repository)
}

$summary | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $JsonOutputPath

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("Remote Miasma scan for $Owner")
$lines.Add("Window: $sinceIso through $untilIso")
$lines.Add("Scan mode: $ScanMode")
$lines.Add("Repositories scanned: $($summary.RepositoriesScanned)")
$lines.Add("Approximate gh/GitHub API calls: $($summary.ApiRequestsApproximate)")
$lines.Add("Repositories with .github/setup.js: $($summary.RepositoriesWithSetupJs)")
$lines.Add("Repositories with any checked indicator path: $($summary.RepositoriesWithAnyIndicator)")
$lines.Add("Errors: $(@($scanErrors).Count)")
foreach ($errorGroup in @($scanErrors | Group-Object Type | Sort-Object Count -Descending)) {
    $lines.Add("Error type $($errorGroup.Name): $($errorGroup.Count)")
}
$lines.Add('')

foreach ($repoResult in $affectedRepos | Sort-Object Repository) {
    $lines.Add("== $($repoResult.Repository) ==")
    $lines.Add("branches=$($repoResult.BranchCount) commits=$($repoResult.JuneCommitCount) findings=$($repoResult.FindingCount) archived=$($repoResult.IsArchived) fork=$($repoResult.IsFork)")
    foreach ($finding in $repoResult.Findings) {
        $lines.Add("MATCH $($finding.Sha.Substring(0, 12)) paths=[$($finding.MatchedPaths -join ', ')] committerDate=$($finding.CommitterDate) author=$($finding.Author) committer=$($finding.Committer) branches=[$($finding.Branches -join ', ')] subject=$($finding.Subject)")
    }
    $lines.Add('')
}

if ($affectedRepos.Count -eq 0) {
    if (@($scanErrors).Count -gt 0) {
        $lines.Add('No checked indicator paths were found in successfully scanned commit trees. Coverage errors occurred, so this is not a clean bill of health; rerun failed repositories.')
    }
    else {
        $lines.Add('No checked indicator paths were found in any scanned commit reachable from any branch.')
    }
}

$lines | Set-Content -LiteralPath $TextOutputPath
$lines
