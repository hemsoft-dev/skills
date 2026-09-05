#requires -Version 7.0
BeforeAll {
    $script:cleanup = Join-Path $PSScriptRoot '../scripts/repo-cleanup.ps1'
    function Invoke-FixtureGit {
        param([string]$Path, [string[]]$Arguments)
        $output = & git -C $Path @Arguments 2>&1
        if ($LASTEXITCODE) { throw ($output | Out-String) }
        ($output | Out-String).Trim()
    }
    function Add-RemoteCommit {
        $other = Join-Path $fixture 'other'
        Invoke-FixtureGit $fixture @('clone', $remote, $other) | Out-Null
        Invoke-FixtureGit $other @('config', 'user.name', 'Cleanup Test') | Out-Null
        Invoke-FixtureGit $other @('config', 'user.email', 'cleanup@example.invalid') | Out-Null
        Invoke-FixtureGit $other @('config', 'core.hooksPath', $emptyHooks) | Out-Null
        Set-Content -LiteralPath (Join-Path $other 'seed.txt') -Value 'remote edit'
        Invoke-FixtureGit $other @('add', '--all') | Out-Null
        Invoke-FixtureGit $other @('commit', '-m', 'remote update') | Out-Null
        Invoke-FixtureGit $other @('push', 'origin', 'main') | Out-Null
    }
}

Describe 'Deterministic repository cleanup with real local Git remotes' {
    BeforeEach {
        $fixture = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $remote = Join-Path $fixture 'origin.git'
        $checkout = Join-Path $fixture 'checkout with spaces'
        $emptyHooks = Join-Path $fixture 'empty-hooks'
        New-Item -ItemType Directory -Path $fixture, $emptyHooks | Out-Null
        Invoke-FixtureGit $fixture @('init', '--bare', '--initial-branch=main', $remote) | Out-Null
        Invoke-FixtureGit $fixture @('clone', $remote, $checkout) | Out-Null
        Invoke-FixtureGit $checkout @('config', 'user.name', 'Cleanup Test') | Out-Null
        Invoke-FixtureGit $checkout @('config', 'user.email', 'cleanup@example.invalid') | Out-Null
        Invoke-FixtureGit $checkout @('config', 'core.hooksPath', $emptyHooks) | Out-Null
        Set-Content -LiteralPath (Join-Path $checkout 'seed.txt') -Value 'seed'
        Set-Content -LiteralPath (Join-Path $checkout 'delete.txt') -Value 'delete me'
        Set-Content -LiteralPath (Join-Path $checkout '.gitignore') -Value '*.ignored'
        Invoke-FixtureGit $checkout @('add', '--all') | Out-Null
        Invoke-FixtureGit $checkout @('commit', '-m', 'seed') | Out-Null
        Invoke-FixtureGit $checkout @('push', '-u', 'origin', 'main') | Out-Null
    }

    It 'publishes staged, unstaged, deleted and unrelated untracked files, excludes ignored files, then becomes a no-op' {
        Set-Content -LiteralPath (Join-Path $checkout 'seed.txt') -Value 'staged edit'
        Invoke-FixtureGit $checkout @('add', 'seed.txt') | Out-Null
        Add-Content -LiteralPath (Join-Path $checkout 'seed.txt') -Value 'unstaged edit'
        Remove-Item -LiteralPath (Join-Path $checkout 'delete.txt')
        Set-Content -LiteralPath (Join-Path $checkout 'unrelated file.txt') -Value 'prior task'
        Set-Content -LiteralPath (Join-Path $checkout 'secret.ignored') -Value 'ignored fixture'
        $result = & $script:cleanup -RepoPath $checkout -LocalRemote
        $result.Status | Should -Be 'Complete'
        $result.Main | Should -Be (Invoke-FixtureGit $remote @('rev-parse', 'main'))
        Invoke-FixtureGit $checkout @('status', '--porcelain') | Should -BeNullOrEmpty
        Invoke-FixtureGit $remote @('ls-tree', '-r', '--name-only', 'main') | Should -Match 'unrelated file.txt'
        Invoke-FixtureGit $remote @('ls-tree', '-r', '--name-only', 'main') | Should -Not -Match 'delete.txt|secret.ignored'
        $again = & $script:cleanup -RepoPath $checkout -LocalRemote
        $again.Commit | Should -BeNullOrEmpty
        $again.Main | Should -Be $result.Main
    }

    It 'keeps Audit and WhatIf read-only including the index' {
        Set-Content -LiteralPath (Join-Path $checkout 'pending.txt') -Value 'pending'
        $before = Invoke-FixtureGit $checkout @('status', '--porcelain')
        $head = Invoke-FixtureGit $checkout @('rev-parse', 'HEAD')
        (& $script:cleanup -RepoPath $checkout -LocalRemote -Audit).Status | Should -Be 'Audit'
        (& $script:cleanup -RepoPath $checkout -LocalRemote -WhatIf).Status | Should -Be 'Audit'
        Invoke-FixtureGit $checkout @('status', '--porcelain') | Should -Be $before
        Invoke-FixtureGit $checkout @('rev-parse', 'HEAD') | Should -Be $head
    }

    It 'stops on a failing commit hook without publishing or discarding changes' {
        Set-Content -LiteralPath (Join-Path $emptyHooks 'pre-commit') -Value "#!/bin/sh`nexit 1" -NoNewline
        Set-Content -LiteralPath (Join-Path $checkout 'pending.txt') -Value 'pending'
        $head = Invoke-FixtureGit $remote @('rev-parse', 'main')
        { & $script:cleanup -RepoPath $checkout -LocalRemote } | Should -Throw '*commit failed*'
        Invoke-FixtureGit $remote @('rev-parse', 'main') | Should -Be $head
        Get-Content -LiteralPath (Join-Path $checkout 'pending.txt') | Should -Be 'pending'
    }

    It 'fast-forwards a clean checkout behind origin' {
        Add-RemoteCommit
        $result = & $script:cleanup -RepoPath $checkout -LocalRemote
        $result.Commit | Should -BeNullOrEmpty
        Get-Content -LiteralPath (Join-Path $checkout 'seed.txt') | Should -Be 'remote edit'
    }

    It 'preserves and replays a dirty checkout behind origin before publishing' {
        Add-RemoteCommit
        Set-Content -LiteralPath (Join-Path $checkout 'pending.txt') -Value 'pending'
        $result = & $script:cleanup -RepoPath $checkout -LocalRemote
        $result.Status | Should -Be 'Complete'
        Get-Content -LiteralPath (Join-Path $checkout 'seed.txt') | Should -Be 'remote edit'
        Invoke-FixtureGit $remote @('show', 'main:pending.txt') | Should -Be 'pending'
    }

    It 'aborts a conflicting replay while retaining the cleanup commit and remote work' {
        Add-RemoteCommit
        Set-Content -LiteralPath (Join-Path $checkout 'seed.txt') -Value 'local edit'
        $remoteHead = Invoke-FixtureGit $remote @('rev-parse', 'main')
        { & $script:cleanup -RepoPath $checkout -LocalRemote } | Should -Throw '*preserved locally*'
        Get-Content -LiteralPath (Join-Path $checkout 'seed.txt') | Should -Be 'local edit'
        Invoke-FixtureGit $remote @('rev-parse', 'main') | Should -Be $remoteHead
        Invoke-FixtureGit $checkout @('status', '--porcelain') | Should -BeNullOrEmpty
    }

    It 'stops on pre-existing divergence before staging pending files' {
        Add-RemoteCommit
        Set-Content -LiteralPath (Join-Path $checkout 'local.txt') -Value 'local'
        Invoke-FixtureGit $checkout @('add', '--all') | Out-Null
        Invoke-FixtureGit $checkout @('commit', '-m', 'local work') | Out-Null
        Set-Content -LiteralPath (Join-Path $checkout 'pending.txt') -Value 'pending'
        $before = Invoke-FixtureGit $checkout @('status', '--porcelain')
        { & $script:cleanup -RepoPath $checkout -LocalRemote } | Should -Throw '*diverged*'
        Invoke-FixtureGit $checkout @('status', '--porcelain') | Should -Be $before
    }

    It 'removes only merged unused branches and retains worktrees, unique branches and stashes' {
        Invoke-FixtureGit $checkout @('branch', 'obsolete') | Out-Null
        $tree = Join-Path $fixture 'retained tree'
        Invoke-FixtureGit $checkout @('worktree', 'add', '-b', 'active', $tree) | Out-Null
        Set-Content -LiteralPath (Join-Path $tree 'active.txt') -Value 'unfinished'
        Invoke-FixtureGit $checkout @('switch', '-c', 'unique') | Out-Null
        Set-Content -LiteralPath (Join-Path $checkout 'unique.txt') -Value 'unique'
        Invoke-FixtureGit $checkout @('add', '--all') | Out-Null
        Invoke-FixtureGit $checkout @('commit', '-m', 'unique') | Out-Null
        Invoke-FixtureGit $checkout @('switch', 'main') | Out-Null
        Set-Content -LiteralPath (Join-Path $checkout 'seed.txt') -Value 'stash'
        Invoke-FixtureGit $checkout @('stash', 'push', '-m', 'retain') | Out-Null
        $result = & $script:cleanup -RepoPath $checkout -LocalRemote
        $result.Status | Should -Be 'PublishedWithRetainedWork'
        $result.RemovedBranches | Should -Contain 'obsolete'
        $result.RetainedBranches | Should -Contain 'unique'
        $result.RetainedBranches | Should -Contain 'active'
        $result.Stashes.Count | Should -Be 1
        Get-Content -LiteralPath (Join-Path $tree 'active.txt') | Should -Be 'unfinished'
    }

    It 'retains committed work after a rejected push' {
        Set-Content -LiteralPath (Join-Path $remote 'hooks/pre-receive') -Value "#!/bin/sh`nexit 1" -NoNewline
        Set-Content -LiteralPath (Join-Path $checkout 'pending.txt') -Value 'pending'
        $head = Invoke-FixtureGit $remote @('rev-parse', 'main')
        { & $script:cleanup -RepoPath $checkout -LocalRemote } | Should -Throw '*push failed*'
        Invoke-FixtureGit $remote @('rev-parse', 'main') | Should -Be $head
        Invoke-FixtureGit $checkout @('show', 'HEAD:pending.txt') | Should -Be 'pending'
    }

    It 'rejects non-main checkouts before staging' {
        Invoke-FixtureGit $checkout @('switch', '-c', 'feature') | Out-Null
        { & $script:cleanup -RepoPath $checkout -LocalRemote } | Should -Throw '*main checkout*'
    }

    It 'validates the final replayed tree and keeps a failed validation local' {
        Add-RemoteCommit
        Set-Content -LiteralPath (Join-Path $checkout 'pending.txt') -Value 'pending'
        $validation = Join-Path $fixture 'validate.ps1'
        Set-Content -LiteralPath $validation -Value "if ((Get-Content -LiteralPath seed.txt) -ne 'remote edit') { exit 2 }; exit 1"
        $remoteHead = Invoke-FixtureGit $remote @('rev-parse', 'main')
        { & $script:cleanup -RepoPath $checkout -LocalRemote -ValidationScript $validation } | Should -Throw '*Validation script failed*'
        Invoke-FixtureGit $remote @('rev-parse', 'main') | Should -Be $remoteHead
        Invoke-FixtureGit $checkout @('show', 'HEAD:pending.txt') | Should -Be 'pending'
        Get-Content -LiteralPath (Join-Path $checkout 'seed.txt') | Should -Be 'remote edit'
    }

    It 'does not publish changes created by a post-commit hook' {
        Set-Content -LiteralPath (Join-Path $emptyHooks 'post-commit') -Value "#!/bin/sh`necho concurrent > concurrent.txt" -NoNewline
        Set-Content -LiteralPath (Join-Path $checkout 'pending.txt') -Value 'pending'
        $remoteHead = Invoke-FixtureGit $remote @('rev-parse', 'main')
        { & $script:cleanup -RepoPath $checkout -LocalRemote } | Should -Throw '*changed during validation or commit*'
        Invoke-FixtureGit $remote @('rev-parse', 'main') | Should -Be $remoteHead
        Get-Content -LiteralPath (Join-Path $checkout 'concurrent.txt') | Should -Be 'concurrent'
    }

    It 'refuses concurrent cleanup while an OS guard is held' {
        $guardPath = Join-Path $checkout '.git/repo-cleanup.guard'
        $heldGuard = [IO.File]::Open($guardPath, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        try { { & $script:cleanup -RepoPath $checkout -LocalRemote } | Should -Throw }
        finally { $heldGuard.Dispose() }
        (& $script:cleanup -RepoPath $checkout -LocalRemote).Status | Should -Be 'Complete'
    }

    It 'does not treat a network origin as a local test remote or accept another owner' {
        Invoke-FixtureGit $checkout @('remote', 'set-url', 'origin', 'https://github.com/another-owner/example.git') | Out-Null
        { & $script:cleanup -RepoPath $checkout -LocalRemote } | Should -Throw '*local bare*'
        { & $script:cleanup -RepoPath $checkout } | Should -Throw '*HemSoft*'
    }
}
