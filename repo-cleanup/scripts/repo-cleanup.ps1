#requires -Version 7.0
<#
.SYNOPSIS
Commits all pending main-checkout changes, synchronizes, pushes, and removes merged local branches.
.DESCRIPTION
Explicit invocation authorizes staging all non-ignored changes, including unrelated work.
Commit hooks and an optional validation script run normally. No force push, stash,
automatic conflict resolution, or object pruning. Obsolete state is deleted only with proof.
Returns one receipt. Exceptions terminate the run and leave recoverable Git state.
.PARAMETER LocalRemote
Allows a local bare origin for offline integration tests. Never permits a network remote.
.EXAMPLE
./repo-cleanup.ps1 -RepoPath C:/Users/User/.agents/skills
.EXAMPLE
./repo-cleanup.ps1 -RepoPath D:/github/HemSoft/example -Audit
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [string]$RepoPath = '.',
    [string]$Message = 'chore: commit pending repository changes',
    [string]$ValidationScript,
    [string[]]$PreserveBranch = @(),
    [string[]]$InactiveWorktree = @(),
    [string[]]$OwnedBranch = @(),
    [switch]$Audit,
    [switch]$LocalRemote
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$timer = [Diagnostics.Stopwatch]::StartNew()
$repo = (Resolve-Path -LiteralPath $RepoPath).Path
$guard = $null
. (Join-Path $PSScriptRoot 'github-origin.ps1')
. (Join-Path $PSScriptRoot 'cleanup-sweep.ps1')
$cleanupPullRequests = @()
$cleanupLogin = ''

function Invoke-CleanupGit {
    param([string[]]$Arguments, [int[]]$AllowedExitCodes = @(0))
    $start = [Diagnostics.ProcessStartInfo]::new('git')
    $start.WorkingDirectory = $repo
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.Environment['GIT_TERMINAL_PROMPT'] = '0'
    foreach ($argument in $Arguments) { $start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::Start($start)
    try {
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        $output = $stdout.GetAwaiter().GetResult()
        $errorText = $stderr.GetAwaiter().GetResult()
        if ($process.ExitCode -notin $AllowedExitCodes) {
            throw "git $($Arguments[0]) failed ($($process.ExitCode)): $errorText$output"
        }
        [pscustomobject]@{ Text = $output.TrimEnd("`r", "`n"); ExitCode = $process.ExitCode }
    }
    finally { $process.Dispose() }
}

function Get-CleanupInventory {
    $trees = [Collections.Generic.List[object]]::new()
    $tree = $null
    $records = (Invoke-CleanupGit @('worktree', 'list', '--porcelain', '-z')).Text.Split([char]0)
    foreach ($record in $records) {
        if ($record.StartsWith('worktree ')) {
            $tree = [ordered]@{ Path = $record.Substring(9); Head = ''; Branch = ''; Locked = $false }
            $trees.Add($tree)
        }
        elseif ($record.StartsWith('HEAD ')) { $tree.Head = $record.Substring(5) }
        elseif ($record.StartsWith('branch ')) { $tree.Branch = $record.Substring(7) }
        elseif ($record.StartsWith('locked')) { $tree.Locked = $true }
    }
    foreach ($item in $trees) {
        $item['Changes'] = if (Test-Path -LiteralPath $item.Path) { (Invoke-CleanupGit @('-C', $item.Path, 'status', '--porcelain=v1', '--untracked-files=all')).Text } else { 'Path missing' }
        $item['Ignored'] = if ($item.Path -ne $repo -and (Test-Path -LiteralPath $item.Path)) { (Invoke-CleanupGit @('-C', $item.Path, 'ls-files', '--others', '--ignored', '--exclude-standard', '-z')).Text } else { '' }
    }
    [pscustomobject]@{
        Changes = (Invoke-CleanupGit @('status', '--porcelain=v1', '-z', '--untracked-files=all')).Text
        Worktrees = @($trees.ToArray())
        Branches = @((Invoke-CleanupGit @('for-each-ref', '--format=%(refname:short)', 'refs/heads')).Text -split '\r?\n' | Where-Object { $_ })
        RemoteBranches = @((Invoke-CleanupGit @('for-each-ref', '--format=%(refname:strip=2)', 'refs/remotes')).Text -split '\r?\n' | Where-Object { $_ })
        Stashes = @((Invoke-CleanupGit @('stash', 'list', '--format=%gd %H %gs')).Text -split '\r?\n' | Where-Object { $_ })
    }
}

try {
    $repo = (Invoke-CleanupGit @('rev-parse', '--show-toplevel')).Text
    $InactiveWorktree = @($InactiveWorktree | ForEach-Object {
        $absolute = [IO.Path]::GetFullPath($_)
        if ((Invoke-CleanupGit @('-C', $absolute, 'rev-parse', '--show-prefix')).Text) { throw 'InactiveWorktree must name a worktree root, not a subdirectory.' }
        (Invoke-CleanupGit @('-C', $absolute, 'rev-parse', '--show-toplevel')).Text.Replace('\', '/')
    })
    $branch = (Invoke-CleanupGit @('symbolic-ref', '--quiet', '--short', 'HEAD') @(0, 1)).Text
    if ($branch -ne 'main') { throw "Run from the main checkout. Current branch: '$branch'. No files changed." }
    foreach ($state in @('MERGE_HEAD', 'CHERRY_PICK_HEAD', 'REVERT_HEAD', 'rebase-merge', 'rebase-apply', 'BISECT_LOG')) {
        $statePath = (Invoke-CleanupGit @('rev-parse', '--path-format=absolute', '--git-path', $state)).Text
        if (Test-Path -LiteralPath $statePath) { throw "Finish the existing Git operation first: $state" }
    }
    if ((Invoke-CleanupGit @('ls-files', '--unmerged')).Text) { throw 'Unresolved index conflicts remain.' }
    $origin = (Invoke-CleanupGit @('remote', 'get-url', 'origin')).Text
    $pushOrigin = (Invoke-CleanupGit @('remote', 'get-url', '--push', '--all', 'origin')).Text
    $pushUrls = @($pushOrigin -split '\r?\n' | Where-Object { $_ })
    if (-not (Test-CleanupOriginPair $origin $pushUrls)) { throw 'Origin fetch and push destinations differ. Resolve the destination first.' }
    if ($LocalRemote) {
        if (-not (Test-Path -LiteralPath $origin -PathType Container)) { throw 'LocalRemote requires an existing local bare repository.' }
        $bare = (Invoke-CleanupGit @('-C', $origin, 'rev-parse', '--is-bare-repository')).Text
        if ($bare -ne 'true') { throw 'LocalRemote requires a bare repository.' }
    }
    $inventory = Get-CleanupInventory
    if ($Audit -or -not $PSCmdlet.ShouldProcess($repo, 'Commit all non-ignored changes, synchronize and push main, clean obsolete branches, worktrees and stashes')) {
        [pscustomobject]@{ Status = 'Audit'; Repository = $repo; Branch = $branch; Inventory = $inventory }
        return
    }
    if (-not $LocalRemote -and (Get-CleanupGitHubRepository $origin) -notmatch '^(?:HemSoft|hemsoft-dev)/[^/]+$') {
        throw 'Automatic direct-main publication is limited to HemSoft and hemsoft-dev GitHub origins. Use the repository PR workflow for other owners.'
    }

    # An OS-held guard coordinates invocations without leaving a stale lock after a crash.
    $common = (Invoke-CleanupGit @('rev-parse', '--path-format=absolute', '--git-common-dir')).Text
    $guard = [IO.File]::Open((Join-Path $common 'repo-cleanup.guard'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    $githubBefore = Get-CleanupGitHubStatus
    if ($githubBefore.Status -eq 'Unavailable') { throw "Pre-cleanup gh x status unavailable. No Git mutations performed: $($githubBefore.Reason)" }
    if (-not $LocalRemote) {
        $githubRepository = Get-CleanupGitHubRepository $origin
        $cleanupLogin = (Invoke-CleanupGh @('api', 'user', '--jq', '.login')).Trim()
        # REST pagination includes every PR, not just gh pr list's default limit.
        $allPulls = Invoke-CleanupGh @('api', '--paginate', '--slurp', "repos/$githubRepository/pulls?state=all&per_page=100") | ConvertFrom-Json
        $cleanupPullRequests = @($allPulls | ForEach-Object { $_ } | ForEach-Object {
            [pscustomobject]@{ state = $(if ($_.merged_at) { 'MERGED' } else { $_.state.ToUpperInvariant() }); headRefName = $_.head.ref; headRefOid = $_.head.sha; author = [pscustomobject]@{ login = $_.user.login }; mergeCommit = $(if ($_.merged_at) { [pscustomobject]@{ oid = $_.merge_commit_sha } } else { $null }); SameRepository = ($_.head.repo -and $_.head.repo.full_name -eq $githubRepository) }
        } | Where-Object SameRepository)
    }
    $defaultRef = (Invoke-CleanupGit @('ls-remote', '--symref', 'origin', 'HEAD')).Text
    if ($defaultRef -notmatch '(?m)^ref: refs/heads/main\s+HEAD\r?$') { throw 'Origin default branch is not main.' }
    Invoke-CleanupGit @('fetch', '--prune', 'origin') | Out-Null
    Invoke-CleanupGit @('rev-parse', '--verify', 'refs/remotes/origin/main') | Out-Null
    $relationship = (Invoke-CleanupGit @('rev-list', '--left-right', '--count', 'HEAD...origin/main')).Text -split '\s+'
    if ([int]$relationship[0] -gt 0 -and [int]$relationship[1] -gt 0) {
        throw 'main has diverged from origin/main. Changes remain untouched; reconcile the commits before rerunning.'
    }
    $commit = $null
    Invoke-CleanupGit @('add', '--all', '--', '.') | Out-Null
    Invoke-CleanupGit @('diff', '--cached', '--check') | Out-Null
    if ((Invoke-CleanupGit @('diff', '--cached', '--quiet') @(0, 1)).ExitCode -eq 1) {
        Invoke-CleanupGit @('commit', '-m', $Message) | Out-Null
        $commit = (Invoke-CleanupGit @('rev-parse', 'HEAD')).Text
    }
    if ((Invoke-CleanupGit @('status', '--porcelain=v1', '--untracked-files=all')).Text) {
        throw 'Files changed during validation or commit. The commit is preserved locally; inspect the remaining edits and rerun.'
    }
    if ([int]$relationship[1] -gt 0) {
        if ($commit) {
            # Only the new cleanup commit is replayed. A conflict is aborted, preserving it.
            $rebase = Invoke-CleanupGit @('rebase', 'origin/main') @(0, 1)
            if ($rebase.ExitCode -ne 0) {
                Invoke-CleanupGit @('rebase', '--abort') | Out-Null
                throw "Cleanup commit $commit is preserved locally; rebase conflicted. Resolve it before rerunning."
            }
            $commit = (Invoke-CleanupGit @('rev-parse', 'HEAD')).Text
        }
        else { Invoke-CleanupGit @('merge', '--ff-only', 'origin/main') | Out-Null }
    }
    if ($ValidationScript) {
        $validation = (Resolve-Path -LiteralPath $ValidationScript).Path
        Push-Location -LiteralPath $repo
        try {
            & (Join-Path $PSHOME 'pwsh') -NoProfile -File $validation | Out-Host
            if (-not $? -or $LASTEXITCODE -ne 0) { throw 'Validation script failed.' }
        }
        finally { Pop-Location }
    }
    if ((Invoke-CleanupGit @('status', '--porcelain=v1', '--untracked-files=all')).Text) { throw 'Validation left new edits; inspect them before rerunning.' }
    Invoke-CleanupGit @('push', 'origin', 'refs/heads/main:refs/heads/main') | Out-Null
    $head = (Invoke-CleanupGit @('rev-parse', 'HEAD')).Text
    $remoteHead = ((Invoke-CleanupGit @('ls-remote', '--exit-code', 'origin', 'refs/heads/main')).Text -split '\s+')[0]
    if ($head -ne $remoteHead) { throw 'Remote main changed during publication. Rerun to synchronize.' }
    if ((Invoke-CleanupGit @('status', '--porcelain=v1', '--untracked-files=all')).Text) { throw 'New edits appeared after publication; they were retained.' }

    $sweep = Invoke-CleanupSweep -CleanupPullRequests $cleanupPullRequests -CleanupLogin $cleanupLogin -OwnedBranch $OwnedBranch
    $removed = [Collections.Generic.List[string]]::new()
    $localDispositions = [Collections.Generic.List[object]]::new()
    $inventory = Get-CleanupInventory
    foreach ($candidate in $inventory.Branches) {
        if ($candidate -eq 'main') { continue }
        $tip = (Invoke-CleanupGit @('rev-parse', "refs/heads/$candidate")).Text
        $reason = if ($candidate -in $PreserveBranch) { 'Explicitly preserved' }
        elseif ("refs/heads/$candidate" -in $inventory.Worktrees.Branch) { 'Still checked out; see worktree disposition' }
        elseif (-not (Test-CleanupIntegratedTip $tip $candidate)) { 'Unique or unverified commits; inspect PR/history and integrate or archive' }
        elseif ("refs/heads/$candidate" -in (Get-CleanupInventory).Worktrees.Branch) { 'New worktree appeared during cleanup' }
        else { '' }
        if ($reason) {
            $localDispositions.Add([pscustomobject]@{ Kind = 'LocalBranch'; Name = $candidate; Result = 'Retained'; Reason = $reason })
            continue
        }
        Invoke-CleanupGit @('update-ref', '-d', "refs/heads/$candidate", $tip) | Out-Null
        $removed.Add($candidate)
        $localDispositions.Add([pscustomobject]@{ Kind = 'LocalBranch'; Name = $candidate; Result = 'Removed'; Reason = "Exact integrated tip $tip; not checked out" })
    }
    $inventory = Get-CleanupInventory
    if ($inventory.Changes) { throw 'New edits appeared during branch cleanup; they were retained.' }
    $remaining = @($inventory.Branches | Where-Object { $_ -ne 'main' })
    $status = if ($remaining.Count -or $inventory.Worktrees.Count -gt 1 -or $inventory.Stashes.Count -or @($sweep.Dispositions | Where-Object { $_.Result -ne 'Removed' }).Count) { 'PublishedWithRetainedWork' } else { 'Complete' }
    if ((Invoke-CleanupGit @('rev-parse', 'HEAD')).Text -ne $head -or
        (((Invoke-CleanupGit @('ls-remote', '--exit-code', 'origin', 'refs/heads/main')).Text -split '\s+')[0] -ne $head)) { throw 'Main changed during cleanup; rerun from fresh evidence.' }
    $githubAfter = Get-CleanupGitHubStatus
    if (@($sweep.Dispositions | Where-Object Result -EQ 'RetainedOrOrphaned').Count -or @($sweep.Dispositions | Where-Object Kind -EQ 'Remote').Count) { $status = 'PublishedWithRetainedWork' }
    if ($githubAfter.Status -eq 'Unavailable') { $status = 'PublishedGitHubVerificationIncomplete' }
    [pscustomobject]@{
        Status = $status
        Repository = $repo
        Main = $head
        RemoteMain = $remoteHead
        Commit = $commit
        GitHubBefore = $githubBefore
        GitHubAfter = $githubAfter
        Dispositions = @($sweep.Dispositions) + @($localDispositions.ToArray())
        RemovedWorktrees = $sweep.RemovedWorktrees
        RemovedRemoteBranches = $sweep.RemovedRemoteBranches
        RemovedStashes = $sweep.RemovedStashes
        RemovedBranches = @($removed.ToArray())
        RetainedBranches = $remaining
        Worktrees = $inventory.Worktrees
        RemoteBranches = $inventory.RemoteBranches
        Stashes = $inventory.Stashes
        DurationSeconds = [math]::Round($timer.Elapsed.TotalSeconds, 2)
    }
}
finally {
    if ($guard) { $guard.Dispose() }
}
