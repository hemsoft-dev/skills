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
    function Invoke-FixtureHookSetup {
        param([string]$Path, [string]$Content)
        Set-Content -LiteralPath $Path -Value $Content -NoNewline
        if (-not $IsWindows) {
            & chmod +x $Path
            if ($LASTEXITCODE) { throw 'Could not make the fixture hook executable.' }
        }
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

    It 'preserves native transport configuration while auditing the same approved repository' {
        Invoke-FixtureGit $checkout @('config', 'remote.origin.url', 'https://github.com/HemSoft/cleanup-fixture.git') | Out-Null
        Invoke-FixtureGit $checkout @('config', 'remote.origin.pushurl', 'git@github.com:HemSoft/cleanup-fixture.git') | Out-Null
        $before = Invoke-FixtureGit $checkout @('config', '--local', '--list')
        (& $script:cleanup -RepoPath $checkout -Audit).Status | Should -Be 'Audit'
        Invoke-FixtureGit $checkout @('config', '--local', '--list') | Should -Be $before
    }
    It 'rejects different repositories before mutation across recognized transports' {
        Invoke-FixtureGit $checkout @('config', 'remote.origin.url', 'https://github.com/HemSoft/cleanup-fixture.git') | Out-Null
        Invoke-FixtureGit $checkout @('config', 'remote.origin.pushurl', 'git@github.com:HemSoft/other-fixture.git') | Out-Null
        $before = Invoke-FixtureGit $checkout @('rev-parse', 'HEAD')
        { & $script:cleanup -RepoPath $checkout -Audit } | Should -Throw '*Origin fetch and push destinations differ*'
        Invoke-FixtureGit $checkout @('rev-parse', 'HEAD') | Should -Be $before
    }
    It 'rejects multiple push destinations before mutation' {
        Invoke-FixtureGit $checkout @('config', '--add', 'remote.origin.pushurl', $remote) | Out-Null
        Invoke-FixtureGit $checkout @('config', '--add', 'remote.origin.pushurl', 'git@github.com:HemSoft/cleanup-fixture.git') | Out-Null
        $before = Invoke-FixtureGit $checkout @('rev-parse', 'HEAD')
        { & $script:cleanup -RepoPath $checkout -Audit } | Should -Throw '*Origin fetch and push destinations differ*'
        Invoke-FixtureGit $checkout @('rev-parse', 'HEAD') | Should -Be $before
    }

    It 'stops on a failing commit hook without publishing or discarding changes' {
        Invoke-FixtureHookSetup (Join-Path $emptyHooks 'pre-commit') "#!/bin/sh`nexit 1"
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

    It 'removes integrated owned remote branches and clean confirmed inactive worktrees' {
        Invoke-FixtureGit $checkout @('branch', 'obsolete-remote') | Out-Null
        Invoke-FixtureGit $checkout @('push', 'origin', 'obsolete-remote') | Out-Null
        $tree = Join-Path $fixture 'inactive tree'
        Invoke-FixtureGit $checkout @('worktree', 'add', '-b', 'inactive', $tree) | Out-Null
        $result = & $script:cleanup -RepoPath $checkout -LocalRemote -InactiveWorktree $tree
        $result.Status | Should -Be 'Complete'
        $result.RemovedRemoteBranches | Should -Contain 'origin/obsolete-remote'
        $result.RemovedWorktrees | Should -Contain ([IO.Path]::GetFullPath($tree).Replace('\', '/'))
        Test-Path -LiteralPath $tree | Should -BeFalse
        Invoke-FixtureGit $remote @('branch', '--list', 'obsolete-remote') | Should -BeNullOrEmpty
    }

    It 'recognizes an explicitly approved inactive worktree through a filesystem alias' -Skip:$IsWindows {
        $tree = Join-Path $fixture 'real tree'
        $alias = Join-Path $fixture 'tree alias'
        Invoke-FixtureGit $checkout @('worktree', 'add', '-b', 'aliased', $tree) | Out-Null
        New-Item -ItemType SymbolicLink -Path $alias -Target $tree | Out-Null
        $result = & $script:cleanup -RepoPath $checkout -LocalRemote -InactiveWorktree $alias
        $result.Status | Should -Be 'Complete'
        $result.RemovedWorktrees.Count | Should -Be 1
        Test-Path -LiteralPath $tree | Should -BeFalse
    }
    It 'rejects an inactive-worktree subdirectory before publishing or removing anything' {
        $tree = Join-Path $fixture 'subdirectory tree'
        Invoke-FixtureGit $checkout @('worktree', 'add', '-b', 'subdirectory', $tree) | Out-Null
        $subdirectory = Join-Path $tree 'child'
        New-Item -ItemType Directory $subdirectory | Out-Null
        { & $script:cleanup -RepoPath $checkout -LocalRemote -InactiveWorktree $subdirectory } | Should -Throw '*worktree root*'
        Test-Path -LiteralPath $tree | Should -BeTrue
    }

    It 'retains a remote branch when another writer changes its tip before deletion' {
        Invoke-FixtureGit $checkout @('branch', 'obsolete-remote') | Out-Null
        Invoke-FixtureGit $checkout @('push', 'origin', 'obsolete-remote') | Out-Null
        Invoke-FixtureGit $checkout @('switch', '-c', 'later-work') | Out-Null
        Set-Content (Join-Path $checkout 'later.txt') 'concurrent work'
        Invoke-FixtureGit $checkout @('add', '--all') | Out-Null
        Invoke-FixtureGit $checkout @('commit', '-m', 'later work') | Out-Null
        $later = Invoke-FixtureGit $checkout @('rev-parse', 'HEAD')
        Invoke-FixtureGit $checkout @('push', 'origin', 'later-work') | Out-Null
        Invoke-FixtureGit $checkout @('switch', 'main') | Out-Null
        # The pre-push hook moves the obsolete ref only during a deletion push.
        $hook = "#!/bin/sh`nwhile read local_ref local_oid remote_ref remote_oid; do`nif [ `"`$remote_ref`" = refs/heads/obsolete-remote ]; then git --git-dir='$remote' update-ref refs/heads/obsolete-remote '$later'; fi`ndone`nexit 0"
        Invoke-FixtureHookSetup (Join-Path $emptyHooks 'pre-push') $hook
        $result = & $script:cleanup -RepoPath $checkout -LocalRemote
        $result.RemovedRemoteBranches | Should -Not -Contain 'origin/obsolete-remote'
        Invoke-FixtureGit $remote @('rev-parse', 'obsolete-remote') | Should -Be $later
        ($result.Dispositions | Where-Object Name -EQ 'origin/obsolete-remote').Reason | Should -Match 'rejected'
    }

    It 'keeps ignored worktree files even when its branch is integrated and inactive' {
        $tree = Join-Path $fixture 'ignored tree'
        Invoke-FixtureGit $checkout @('worktree', 'add', '-b', 'ignored-content', $tree) | Out-Null
        Set-Content (Join-Path $tree 'irreplaceable.ignored') 'only copy'
        $result = & $script:cleanup -RepoPath $checkout -LocalRemote -InactiveWorktree $tree
        $result.Status | Should -Be 'PublishedWithRetainedWork'
        ($result.Dispositions | Where-Object Kind -EQ 'Worktree').Reason | Should -Match 'Ignored content'
        Get-Content (Join-Path $tree 'irreplaceable.ignored') | Should -Be 'only copy'
    }

    It 'keeps unique remote branches, preserved remote release refs, and additional remote refs' {
        Invoke-FixtureGit $checkout @('branch', 'release/frozen') | Out-Null
        Invoke-FixtureGit $checkout @('push', 'origin', 'release/frozen') | Out-Null
        Invoke-FixtureGit $checkout @('switch', '-c', 'unique-remote') | Out-Null
        Set-Content (Join-Path $checkout 'remote-only.txt') 'unique'
        Invoke-FixtureGit $checkout @('add', '--all') | Out-Null
        Invoke-FixtureGit $checkout @('commit', '-m', 'unique remote') | Out-Null
        Invoke-FixtureGit $checkout @('push', 'origin', 'unique-remote') | Out-Null
        Invoke-FixtureGit $checkout @('switch', 'main') | Out-Null
        Invoke-FixtureGit $checkout @('remote', 'add', 'secondary', $remote) | Out-Null
        $result = & $script:cleanup -RepoPath $checkout -LocalRemote -PreserveBranch 'release/frozen'
        $result.RemovedRemoteBranches.Count | Should -Be 0
        @($result.Dispositions | Where-Object { $_.Kind -eq 'RemoteBranch' -and $_.Name -like 'secondary/*' }).Count | Should -Be 2
        Invoke-FixtureGit $remote @('branch', '--list', 'unique-remote') | Should -Match 'unique-remote'
    }

    It 'drops all stashes whose complete contents match main without confusing shifted selectors' {
        foreach ($name in @('first', 'second')) {
            Set-Content (Join-Path $checkout 'seed.txt') 'already shipped'
            Invoke-FixtureGit $checkout @('stash', 'push', '-m', $name) | Out-Null
        }
        Set-Content (Join-Path $checkout 'seed.txt') 'already shipped'
        $result = & $script:cleanup -RepoPath $checkout -LocalRemote
        $result.RemovedStashes.Count | Should -Be 2
        $result.Stashes.Count | Should -Be 0
        $result.Status | Should -Be 'Complete'
    }

    It 'preserves useful staged and untracked stash content even when the working file matches main' {
        Set-Content (Join-Path $checkout 'seed.txt') 'index only'
        Invoke-FixtureGit $checkout @('add', 'seed.txt') | Out-Null
        Set-Content (Join-Path $checkout 'seed.txt') 'working shipped'
        Set-Content (Join-Path $checkout 'untracked.txt') 'unique untracked'
        Invoke-FixtureGit $checkout @('stash', 'push', '--include-untracked', '-m', 'all layers') | Out-Null
        Set-Content (Join-Path $checkout 'seed.txt') 'working shipped'
        $result = & $script:cleanup -RepoPath $checkout -LocalRemote
        $result.RemovedStashes.Count | Should -Be 0
        $result.Stashes.Count | Should -Be 1
        Invoke-FixtureGit $checkout @('show', 'stash@{0}^2:seed.txt') | Should -Be 'index only'
        Invoke-FixtureGit $checkout @('show', 'stash@{0}^3:untracked.txt') | Should -Be 'unique untracked'
    }

    It 'retains committed work after a rejected push' {
        Invoke-FixtureHookSetup (Join-Path $remote 'hooks/pre-receive') "#!/bin/sh`nexit 1"
        Set-Content -LiteralPath (Join-Path $checkout 'pending.txt') -Value 'pending'
        $head = Invoke-FixtureGit $remote @('rev-parse', 'main')
        { & $script:cleanup -RepoPath $checkout -LocalRemote } | Should -Throw '*push failed*'
        Invoke-FixtureGit $remote @('rev-parse', 'main') | Should -Be $head
        Invoke-FixtureGit $checkout @('show', 'HEAD:pending.txt') | Should -Be 'pending'
    }

    It 'preserves an explicitly named release branch while removing obsolete unused branches' {
        Invoke-FixtureGit $checkout @('branch', 'release/active-candidate') | Out-Null
        Invoke-FixtureGit $checkout @('branch', 'obsolete') | Out-Null
        $result = & $script:cleanup -RepoPath $checkout -LocalRemote -PreserveBranch 'release/active-candidate'
        $result.RetainedBranches | Should -Contain 'release/active-candidate'
        $result.RemovedBranches | Should -Contain 'obsolete'
        Invoke-FixtureGit $checkout @('rev-parse', 'release/active-candidate') | Should -Be $result.Main
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
        Invoke-FixtureHookSetup (Join-Path $emptyHooks 'post-commit') "#!/bin/sh`necho concurrent > concurrent.txt"
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

    It 'audits another owner read-only but refuses direct publication' {
        Invoke-FixtureGit $checkout @('remote', 'set-url', 'origin', 'https://github.com/another-owner/example.git') | Out-Null
        { & $script:cleanup -RepoPath $checkout -LocalRemote } | Should -Throw '*local bare*'
        (& $script:cleanup -RepoPath $checkout -Audit).Status | Should -Be 'Audit'
        (& $script:cleanup -RepoPath $checkout -WhatIf).Status | Should -Be 'Audit'
        { & $script:cleanup -RepoPath $checkout } | Should -Throw '*HemSoft*'
    }
}

Describe 'GitHub origin identity across transports' {
    BeforeAll { . (Join-Path $PSScriptRoot '../scripts/github-origin.ps1') }

    It 'accepts HTTPS and standard SSH for the same repository' {
        Test-CleanupOriginPair 'https://github.com/HemSoft/example.git' @('git@github.com:hemsoft/Example.git') | Should -BeTrue
        Test-CleanupOriginPair 'https://github.com/HemSoft/example.git' @('ssh://git@github.com/HemSoft/example') | Should -BeTrue
    }

    It 'accepts an SSH alias only when its effective host and user are GitHub git' {
        Mock Resolve-CleanupSshHost { [pscustomobject]@{ HostName = 'github.com'; User = 'git' } }
        Test-CleanupOriginPair 'https://github.com/HemSoft/example.git' @('git@github.com-hemsoft:HemSoft/example.git') | Should -BeTrue
        Should -Invoke Resolve-CleanupSshHost -Times 1 -Exactly -ParameterFilter { $HostName -eq 'github.com-hemsoft' }
    }

    It 'rejects an SSH alias resolving to another host or user' {
        Mock Resolve-CleanupSshHost { [pscustomobject]@{ HostName = 'example.invalid'; User = 'git' } }
        Test-CleanupOriginPair 'https://github.com/HemSoft/example.git' @('git@another-host:HemSoft/example.git') | Should -BeFalse
        Mock Resolve-CleanupSshHost { [pscustomobject]@{ HostName = 'github.com'; User = 'another-user' } }
        Test-CleanupOriginPair 'https://github.com/HemSoft/example.git' @('git@another-host:HemSoft/example.git') | Should -BeFalse
    }

    It 'rejects different repositories and multiple push destinations' {
        Test-CleanupOriginPair 'https://github.com/HemSoft/example.git' @('git@github.com:HemSoft/other.git') | Should -BeFalse
        Test-CleanupOriginPair 'https://github.com/HemSoft/example.git' @('git@github.com:other-owner/example.git') | Should -BeFalse
        Test-CleanupOriginPair 'https://github.com/HemSoft/example.git' @('https://github.com/HemSoft/example.git', 'git@github.com:HemSoft/example.git') | Should -BeFalse
    }

    It 'does not recognize misleading hosts, embedded credentials or malformed repository paths' {
        foreach ($url in @('https://github.com.example.invalid/HemSoft/example.git', 'https://user:secret@github.com/HemSoft/example.git', 'git@github.com:HemSoft/example/extra.git')) {
            Get-CleanupGitHubRepository $url | Should -BeNullOrEmpty
        }
        Get-CleanupGitHubRepository 'git@github.com:another-owner/example.git' | Should -Be 'another-owner/example'
    }
}

Describe 'Canonical personal GitHub destination allowlist' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '../scripts/github-origin.ps1')
        $tokens = $null
        $errors = $null
        $ast = [Management.Automation.Language.Parser]::ParseFile($script:cleanup, [ref]$tokens, [ref]$errors)
        $guard = $ast.Find({
            param($node)
            $node -is [Management.Automation.Language.BinaryExpressionAst] -and
            $node.Operator -eq [Management.Automation.Language.TokenKind]::Inotmatch -and
            $node.Left.Extent.Text -eq '(Get-CleanupGitHubRepository $origin)'
        }, $true)
        $script:originPattern = $guard.Right.Value
    }
    It 'preserves destination authority for <Url>' -TestCases @(
        @{ Url = 'https://github.com/hemsoft-dev/example.git'; Allowed = $true }
        @{ Url = 'git@github-personal1:hemsoft-dev/example.git'; Allowed = $true }
        @{ Url = 'ssh://git@github.com/hemsoft-dev/example.git'; Allowed = $true }
        @{ Url = 'https://github.com/HemSoft/example.git'; Allowed = $true }
        @{ Url = 'https://github.com/another-owner/example.git'; Allowed = $false }
        @{ Url = 'git@github-work1:hemsoft-dev/example.git'; Allowed = $false }
        @{ Url = 'https://github.com/hemsoft-dev/example/extra'; Allowed = $false }
        @{ Url = 'https://github.com.evil.invalid/hemsoft-dev/example.git'; Allowed = $false }
    ) {
        param($Url, $Allowed)
        Mock Resolve-CleanupSshHost {
            if ($HostName -eq 'github-personal1') { [pscustomobject]@{ HostName = 'github.com'; User = 'git' } }
            else { [pscustomobject]@{ HostName = 'example.invalid'; User = 'git' } }
        }
        ((Get-CleanupGitHubRepository $Url) -match $script:originPattern) | Should -Be $Allowed
    }
}

Describe 'Required GitHub status reporting' {
    BeforeAll { . (Join-Path $PSScriptRoot '../scripts/cleanup-sweep.ps1'); $script:LocalRemote = $false }
    It 'runs gh x status with fresh GitHub data and captures the actual output' {
        Mock Invoke-CleanupGh { 'actual status output including pending checks' }
        $result = Get-CleanupGitHubStatus
        $result.Status | Should -Be 'Captured'
        $result.Output | Should -Match 'pending checks'
        Should -Invoke Invoke-CleanupGh -Times 1 -Exactly -ParameterFilter { ($Arguments -join ' ') -eq 'x status --refresh' }
    }
    It 'reports a missing extension or failed command instead of claiming success' {
        Mock Invoke-CleanupGh { throw 'unknown command x' }
        $result = Get-CleanupGitHubStatus
        $result.Status | Should -Be 'Unavailable'
        $result.Reason | Should -Match 'unknown command'
    }
    It 'skips GitHub status only for explicitly offline bare fixtures' {
        $script:LocalRemote = $true
        Mock Invoke-CleanupGh { throw 'must not call' }
        (Get-CleanupGitHubStatus).Status | Should -Be 'Skipped'
        Should -Invoke Invoke-CleanupGh -Times 0 -Exactly
    }
}
