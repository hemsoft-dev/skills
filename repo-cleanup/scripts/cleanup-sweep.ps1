# Loaded by repo-cleanup.ps1. All native calls use argument lists, never a shell.
function Invoke-CleanupGh {
    param([string[]]$Arguments)
    $start = [Diagnostics.ProcessStartInfo]::new('gh')
    $start.WorkingDirectory = $repo
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.Environment['GH_PROMPT_DISABLED'] = '1'
    $start.Environment['NO_COLOR'] = '1'
    foreach ($argument in $Arguments) { $start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::Start($start)
    try {
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(120000)) { $process.Kill($true); throw 'gh timed out after 120 seconds.' }
        $output = $stdout.GetAwaiter().GetResult()
        $errorText = $stderr.GetAwaiter().GetResult()
        if ($process.ExitCode) { throw "gh $($Arguments -join ' ') failed ($($process.ExitCode)): $errorText$output" }
        $output.TrimEnd("`r", "`n")
    }
    finally { $process.Dispose() }
}

function Get-CleanupGitHubStatus {
    if ($LocalRemote) {
        return [pscustomobject]@{ Status = 'Skipped'; Reason = 'Offline local-bare test fixture only'; Command = 'gh x status --refresh'; Output = '' }
    }
    try {
        $output = Invoke-CleanupGh @('x', 'status', '--refresh')
        [pscustomobject]@{ Status = 'Captured'; Command = 'gh x status --refresh'; At = [DateTimeOffset]::Now.ToString('o'); Output = $output }
    }
    catch {
        [pscustomobject]@{ Status = 'Unavailable'; Command = 'gh x status --refresh'; Reason = $_.Exception.Message; Output = '' }
    }
}

function Get-CleanupBranchPullRequest {
    param([string]$Repository, [string]$Branch)
    $owner = ($Repository -split '/')[0]
    $headQuery = [Uri]::EscapeDataString("${owner}:$Branch")
    $pages = Invoke-CleanupGh @('api', '--paginate', '--slurp', "repos/$Repository/pulls?state=all&head=$headQuery&per_page=100") | ConvertFrom-Json
    @($pages | ForEach-Object { $_ } | ForEach-Object { $_ })
}

function Test-CleanupIntegratedTip {
    param([string]$Tip, [string]$Name)
    if ((Invoke-CleanupGit @('merge-base', '--is-ancestor', $Tip, $head) @(0, 1)).ExitCode -eq 0) { return $true }
    # Squash/rebase proof: exact merged PR head, with its merge commit in published main.
    foreach ($pr in $cleanupPullRequests) {
        if ($pr.state -eq 'MERGED' -and $pr.headRefName -eq $Name -and $pr.headRefOid -eq $Tip -and $pr.mergeCommit -and
            (Invoke-CleanupGit @('merge-base', '--is-ancestor', $pr.mergeCommit.oid, $head) @(0, 1, 128)).ExitCode -eq 0) { return $true }
    }
    return $false
}

function Test-CleanupStashIntegrated {
    param([string]$Oid)
    $parents = (Invoke-CleanupGit @('rev-list', '--parents', '-n', '1', $Oid)).Text -split ' '
    if ($parents.Count -lt 3) { return $false }
    $base = $parents[1]
    # Compare both the working and staged versions. An index-only value remains useful.
    foreach ($layer in @($Oid, $parents[2])) {
        $paths = (Invoke-CleanupGit @('diff', '--name-only', '--no-renames', '-z', $base, $layer, '--')).Text.Split([char]0) | Where-Object { $_ }
        foreach ($path in $paths) {
            $expected = (Invoke-CleanupGit @('ls-tree', $layer, '--', ":(literal)$path")).Text
            $published = (Invoke-CleanupGit @('ls-tree', $head, '--', ":(literal)$path")).Text
            if ($expected -cne $published) { return $false }
        }
    }
    if ($parents.Count -gt 3) {
        $paths = (Invoke-CleanupGit @('ls-tree', '-r', '--name-only', '-z', $parents[3])).Text.Split([char]0) | Where-Object { $_ }
        foreach ($path in $paths) {
            if ((Invoke-CleanupGit @('ls-tree', $parents[3], '--', ":(literal)$path")).Text -cne
                (Invoke-CleanupGit @('ls-tree', $head, '--', ":(literal)$path")).Text) { return $false }
        }
    }
    return $true
}

function Invoke-CleanupSweep {
    param([object[]]$CleanupPullRequests, [string]$CleanupLogin, [string[]]$OwnedBranch)
    $dispositions = [Collections.Generic.List[object]]::new()
    $removedTrees = [Collections.Generic.List[string]]::new()
    $removedRemote = [Collections.Generic.List[string]]::new()
    $removedStashes = [Collections.Generic.List[string]]::new()
    function Add-Disposition([string]$Kind, [string]$Name, [string]$Result, [string]$Reason) {
        $dispositions.Add([pscustomobject]@{ Kind = $Kind; Name = $Name; Result = $Result; Reason = $Reason })
    }
    $inventory = Get-CleanupInventory
    foreach ($tree in $inventory.Worktrees) {
        if ($tree.Path -eq $repo) { continue }
        $name = $tree.Branch -replace '^refs/heads/', ''
        $reason = if ($name -in $PreserveBranch) { 'Explicitly preserved' }
        elseif ($tree.Locked) { 'Locked worktree; resolve ownership first' }
        elseif (-not (Test-Path -LiteralPath $tree.Path)) { 'Missing path; inspect ownership and recovery before pruning registration' }
        elseif ($tree.Path -notin $InactiveWorktree) { 'Inactivity not verified; inspect owner and rerun with -InactiveWorktree for a confirmed inactive path' }
        elseif (-not (Test-CleanupIntegratedTip $tree.Head $name)) { 'Unintegrated commits; inspect PR or preserve/archive unique work' }
        elseif ((Invoke-CleanupGit @('-C', $tree.Path, 'status', '--porcelain=v1', '--untracked-files=all')).Text) { 'Uncommitted work; inspect and integrate or preserve it' }
        elseif ((Invoke-CleanupGit @('-C', $tree.Path, 'ls-files', '--others', '--ignored', '--exclude-standard', '-z')).Text) { 'Ignored content present; preserve it outside the worktree before removal' }
        else { '' }
        if ($reason) { Add-Disposition 'Worktree' $tree.Path 'Retained' $reason; continue }
        $live = @((Get-CleanupInventory).Worktrees | Where-Object Path -EQ $tree.Path)
        if ($live.Count -ne 1 -or $live[0].Head -ne $tree.Head -or $live[0].Branch -ne $tree.Branch -or $live[0].Locked) {
            Add-Disposition 'Worktree' $tree.Path 'Retained' 'Registration or tip changed during cleanup'; continue
        }
        try {
            Invoke-CleanupGit @('worktree', 'remove', '--', $tree.Path) | Out-Null
            if ((Test-Path -LiteralPath $tree.Path) -or @((Get-CleanupInventory).Worktrees | Where-Object Path -EQ $tree.Path).Count) { throw 'Directory or registration remains' }
            $removedTrees.Add($tree.Path)
            Add-Disposition 'Worktree' $tree.Path 'Removed' 'Clean, confirmed inactive, integrated, with no ignored files'
        }
        catch { Add-Disposition 'Worktree' $tree.Path 'RetainedOrOrphaned' "Removal failed; preserve and inspect this exact path: $($_.Exception.Message)" }
    }
    $stashInventory = @((Get-CleanupInventory).Stashes)
    [array]::Reverse($stashInventory)
    foreach ($stash in $stashInventory) {
        $parts = $stash -split ' ', 3
        $selector = $parts[0]; $oid = $parts[1]
        if (-not (Test-CleanupStashIntegrated $oid)) { Add-Disposition 'Stash' $selector 'Retained' 'Working, index, or untracked content differs from published main; inspect all layers'; continue }
        $live = (Invoke-CleanupGit @('rev-parse', '--verify', $selector) @(0, 128)).Text
        if ($live -ne $oid) { Add-Disposition 'Stash' $selector 'Retained' 'Stash selector changed; rerun from a fresh inventory'; continue }
        # Oldest first avoids shifting later selectors; each selector is rechecked against its OID.
        Invoke-CleanupGit @('stash', 'drop', $selector) | Out-Null
        $removedStashes.Add($oid)
        Add-Disposition 'Stash' $oid 'Removed' 'All working, index, and untracked changes exactly match published main'
    }
    foreach ($remote in ((Invoke-CleanupGit @('remote')).Text -split '\r?\n' | Where-Object { $_ })) {
        $url = (Invoke-CleanupGit @('remote', 'get-url', $remote)).Text
        $pushUrls = @((Invoke-CleanupGit @('remote', 'get-url', '--push', '--all', $remote)).Text -split '\r?\n' | Where-Object { $_ })
        $approved = $remote -eq 'origin' -and (Test-CleanupOriginPair $url $pushUrls)
        $defaultOutput = (Invoke-CleanupGit @('ls-remote', '--symref', $remote, 'HEAD') @(0, 128)).Text
        $defaultName = if ($defaultOutput -match '(?m)^ref: refs/heads/(.+)\s+HEAD\r?$') { $Matches[1] } else { '' }
        $liveRefs = Invoke-CleanupGit @('ls-remote', '--heads', $remote) @(0, 128)
        if ($liveRefs.ExitCode) { Add-Disposition 'Remote' $remote 'Retained' 'Remote unavailable; branch inventory incomplete'; continue }
        foreach ($line in ($liveRefs.Text -split '\r?\n' | Where-Object { $_ })) {
            $parts = $line -split '\s+', 2
            $tip = $parts[0]; $name = $parts[1] -replace '^refs/heads/', ''
            if ($name -eq 'main' -or $name -eq $defaultName) { continue }
            $matching = @($cleanupPullRequests | Where-Object { $_.headRefName -eq $name })
            $ownedMerged = @($matching | Where-Object { $_.state -eq 'MERGED' -and $_.headRefOid -eq $tip -and $_.author.login -eq $cleanupLogin })
            $reason = if ($name -in $PreserveBranch) { 'Explicitly preserved release or evidence ref' }
            elseif (-not $approved) { 'Additional remote inventoried; ownership/publication policy must be verified before deletion' }
            elseif (@($matching | Where-Object state -EQ 'OPEN').Count) { 'Open PR still uses this branch' }
            elseif (-not $LocalRemote -and $name -notin $OwnedBranch -and -not $ownedMerged.Count) { 'Ownership or exact merged PR not verified; inspect branch history and author' }
            elseif (-not (Test-CleanupIntegratedTip $tip $name)) { 'Unintegrated tip; retain unpublished or later work' }
            else { '' }
            if ($reason) { Add-Disposition 'RemoteBranch' "$remote/$name" 'Retained' $reason; continue }
            if (-not $LocalRemote) {
                $freshPulls = @(Get-CleanupBranchPullRequest -Repository $githubRepository -Branch $name)
                if (@($freshPulls | Where-Object state -EQ 'open').Count -or
                    ($name -notin $OwnedBranch -and -not @($freshPulls | Where-Object { $_.merged_at -and $_.head.sha -eq $tip -and $_.user.login -eq $cleanupLogin }).Count)) {
                    Add-Disposition 'RemoteBranch' "$remote/$name" 'Retained' 'Fresh PR ownership/state no longer permits deletion'; continue
                }
            }
            # A lease protects against another writer adding commits after the inventory.
            $deleted = Invoke-CleanupGit @('push', "--force-with-lease=refs/heads/${name}:$tip", $remote, ":refs/heads/$name") @(0, 1)
            if ($deleted.ExitCode) { Add-Disposition 'RemoteBranch' "$remote/$name" 'Retained' 'Lease-guarded deletion rejected; inspect fresh tip/protection'; continue }
            if ((Invoke-CleanupGit @('ls-remote', '--heads', $remote, "refs/heads/$name")).Text) { Add-Disposition 'RemoteBranch' "$remote/$name" 'Retained' 'Branch was recreated after deletion'; continue }
            $removedRemote.Add("$remote/$name")
            Add-Disposition 'RemoteBranch' "$remote/$name" 'Removed' "Verified integrated and owned; deletion guarded by exact tip $tip"
        }
    }
    [pscustomobject]@{ Dispositions = @($dispositions.ToArray()); RemovedWorktrees = @($removedTrees.ToArray()); RemovedRemoteBranches = @($removedRemote.ToArray()); RemovedStashes = @($removedStashes.ToArray()) }
}
