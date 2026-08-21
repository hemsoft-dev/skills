# Pester 5 tests for hooks/pre-commit-skills-lint.ps1.
# Seeds fixture skill trees with known violations and asserts the lint catches them.

BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '..\pre-commit-skills-lint.ps1'

    function New-TestRepo {
        [CmdletBinding(SupportsShouldProcess)]
        param()
        $root = Join-Path ([System.IO.Path]::GetTempPath()) ("skills-lint-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        return $root
    }

    function New-TestSkill {
        [CmdletBinding(SupportsShouldProcess)]
        param(
            [string]$Root,
            [string]$Name,
            [string]$Frontmatter,
            [string]$Body = '',
            [string[]]$Files = @()
        )
        $dir = Join-Path $Root $Name
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        if (-not [string]::IsNullOrWhiteSpace($Frontmatter)) {
            Set-Content -LiteralPath (Join-Path $dir 'SKILL.md') -Value "---$([Environment]::NewLine)$Frontmatter$([Environment]::NewLine)---$([Environment]::NewLine)$Body" -Encoding utf8
        }
        else {
            Set-Content -LiteralPath (Join-Path $dir 'SKILL.md') -Value "# no frontmatter here" -Encoding utf8
        }
        foreach ($file in $Files) {
            $target = Join-Path $dir $file
            New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
            Set-Content -LiteralPath $target -Value 'placeholder' -Encoding utf8
        }
        return $dir
    }

    function Invoke-SkillsLint {
        param([string]$Root)
        $output = & pwsh -NoProfile -File $scriptPath -RepoRoot $Root 2>&1 | Out-String
        return @{
            ExitCode = $LASTEXITCODE
            Output   = $output
        }
    }
}

AfterAll {
    # Temp fixtures live under the system temp path and are cleaned up per test below.
}

Describe 'pre-commit-skills-lint' {

    Context 'a fully valid skill' {
        BeforeAll {
            $root = New-TestRepo
            New-TestSkill -Root $root -Name 'valid-skill' `
                -Frontmatter "name: valid-skill`ndescription: A valid skill for testing." `
                -Body @'
See [details](references/details.md) and `scripts/run.ps1`.
'@ `
                -Files @('references/details.md', 'scripts/run.ps1')
        }

        AfterAll {
            if ($root -and (Test-Path $root)) { Remove-Item -LiteralPath $root -Recurse -Force }
        }

        It 'passes with exit code 0 and reports the checked skill' {
            $result = Invoke-SkillsLint -Root $root
            $result.ExitCode | Should -Be 0
            $result.Output | Should -Match 'valid-skill'
        }
    }

    Context 'frontmatter violations' {

        It 'blocks when frontmatter is missing entirely' {
            $root = New-TestRepo
            try {
                New-TestSkill -Root $root -Name 'no-fm' -Frontmatter $null
                $result = Invoke-SkillsLint -Root $root
                $result.ExitCode | Should -Be 1
                $result.Output | Should -Match 'missing YAML frontmatter'
            }
            finally { Remove-Item -LiteralPath $root -Recurse -Force }
        }

        It 'blocks when name does not match the directory' {
            $root = New-TestRepo
            try {
                New-TestSkill -Root $root -Name 'actual-dir' -Frontmatter "name: other-name`ndescription: Something useful."
                $result = Invoke-SkillsLint -Root $root
                $result.ExitCode | Should -Be 1
                $result.Output | Should -Match "does not match directory 'actual-dir'"
            }
            finally { Remove-Item -LiteralPath $root -Recurse -Force }
        }

        It 'blocks when name violates the lowercase-hyphen pattern' {
            $root = New-TestRepo
            try {
                New-TestSkill -Root $root -Name 'bad_name' -Frontmatter "name: bad_Name`ndescription: Something useful."
                $result = Invoke-SkillsLint -Root $root
                $result.ExitCode | Should -Be 1
                $result.Output | Should -Match 'does not match \^\[a-z0-9\]'
            }
            finally { Remove-Item -LiteralPath $root -Recurse -Force }
        }

        It 'blocks when description is missing' {
            $root = New-TestRepo
            try {
                New-TestSkill -Root $root -Name 'desc-less' -Frontmatter "name: desc-less"
                $result = Invoke-SkillsLint -Root $root
                $result.ExitCode | Should -Be 1
                $result.Output | Should -Match "'description' is missing or empty"
            }
            finally { Remove-Item -LiteralPath $root -Recurse -Force }
        }

        It 'blocks when description exceeds 1024 characters' {
            $root = New-TestRepo
            try {
                $longDescription = 'x' * 1025
                New-TestSkill -Root $root -Name 'long-desc' -Frontmatter "name: long-desc`ndescription: $longDescription"
                $result = Invoke-SkillsLint -Root $root
                $result.ExitCode | Should -Be 1
                $result.Output | Should -Match 'exceeds 1024 characters'
            }
            finally { Remove-Item -LiteralPath $root -Recurse -Force }
        }

        It 'accepts a 1024 character description at the boundary' {
            $root = New-TestRepo
            try {
                $maxDescription = 'x' * 1024
                New-TestSkill -Root $root -Name 'max-desc' -Frontmatter "name: max-desc`ndescription: $maxDescription"
                $result = Invoke-SkillsLint -Root $root
                $result.ExitCode | Should -Be 0
            }
            finally { Remove-Item -LiteralPath $root -Recurse -Force }
        }
    }

    Context 'referenced file checks' {

        It 'blocks when a markdown link target is missing from the skill folder' {
            $root = New-TestRepo
            try {
                New-TestSkill -Root $root -Name 'dead-link' `
                    -Frontmatter "name: dead-link`ndescription: Has a dead reference." `
                    -Body @'
Read [the format](GLOSSARY-FORMAT.md) first.
'@ `
                    -Files @()
                $result = Invoke-SkillsLint -Root $root
                $result.ExitCode | Should -Be 1
                $result.Output | Should -Match "references 'GLOSSARY-FORMAT\.md' but it does not exist"
            }
            finally { Remove-Item -LiteralPath $root -Recurse -Force }
        }

        It 'blocks when a bare relative path token is missing' {
            $root = New-TestRepo
            try {
                New-TestSkill -Root $root -Name 'bare-token' `
                    -Frontmatter "name: bare-token`ndescription: Mentions a script path in prose." `
                    -Body 'Run references/missing-guide.md before starting.' `
                    -Files @()
                $result = Invoke-SkillsLint -Root $root
                $result.ExitCode | Should -Be 1
                $result.Output | Should -Match "references 'references/missing-guide\.md'"
            }
            finally { Remove-Item -LiteralPath $root -Recurse -Force }
        }

        It 'ignores paths inside fenced code blocks and inline code spans' {
            $root = New-TestRepo
            try {
                New-TestSkill -Root $root -Name 'code-only' `
                    -Frontmatter "name: code-only`ndescription: Only mentions paths as examples." `
                    -Body @'
Use `vercel/next.js` style ids. Example tree:

```
docs/agents/issue-tracker.md
/opt/actions-runner/bin/Runner.Listener
```

External docs at https://example.com/guide.md and /absolute/path/file.md.
'@ `
                    -Files @()
                $result = Invoke-SkillsLint -Root $root
                $result.ExitCode | Should -Be 0
            }
            finally { Remove-Item -LiteralPath $root -Recurse -Force }
        }

        It 'accepts existing relative references' {
            $root = New-TestRepo
            try {
                New-TestSkill -Root $root -Name 'good-links' `
                    -Frontmatter "name: good-links`ndescription: All references resolve." `
                    -Body @'
See references/a.md and [b](./references/b.md).
'@ `
                    -Files @('references/a.md', 'references/b.md')
                $result = Invoke-SkillsLint -Root $root
                $result.ExitCode | Should -Be 0
            }
            finally { Remove-Item -LiteralPath $root -Recurse -Force }
        }
    }

    Context 'duplicate reference basenames' {

        It 'warns but does not block when two skills ship the same reference basename' {
            $root = New-TestRepo
            try {
                New-TestSkill -Root $root -Name 'skill-one' `
                    -Frontmatter "name: skill-one`ndescription: First divergent copy." `
                    -Files @('references/review-loop.md')
                New-TestSkill -Root $root -Name 'skill-two' `
                    -Frontmatter "name: skill-two`ndescription: Second divergent copy." `
                    -Files @('references/review-loop.md')
                $result = Invoke-SkillsLint -Root $root
                $result.ExitCode | Should -Be 0
                $result.Output | Should -Match "reference basename 'review-loop\.md' ships in multiple skills"
                $result.Output | Should -Match 'WARNING'
            }
            finally { Remove-Item -LiteralPath $root -Recurse -Force }
        }
    }

    Context 'block scalar descriptions' {

        It 'blocks a folded description whose expanded text exceeds 1024 characters' {
            $root = New-TestRepo
            try {
                $chunk = 'x' * 600
                $frontmatter = "name: folded-long`ndescription: >-$([Environment]::NewLine)  $chunk$([Environment]::NewLine)  $chunk"
                New-TestSkill -Root $root -Name 'folded-long' -Frontmatter $frontmatter
                $result = Invoke-SkillsLint -Root $root
                $result.ExitCode | Should -Be 1
                $result.Output | Should -Match "'description' exceeds 1024 characters \(got 1201\)"
            }
            finally { Remove-Item -LiteralPath $root -Recurse -Force }
        }

        It 'accepts a literal block description within the limit' {
            $root = New-TestRepo
            try {
                $frontmatter = "name: literal-ok`ndescription: |$([Environment]::NewLine)  A perfectly reasonable$([Environment]::NewLine)  multi-line description."
                New-TestSkill -Root $root -Name 'literal-ok' -Frontmatter $frontmatter
                $result = Invoke-SkillsLint -Root $root
                $result.ExitCode | Should -Be 0
            }
            finally { Remove-Item -LiteralPath $root -Recurse -Force }
        }

        It 'blocks an empty literal block description' {
            $root = New-TestRepo
            try {
                New-TestSkill -Root $root -Name 'literal-empty' -Frontmatter "name: literal-empty`ndescription: |"
                $result = Invoke-SkillsLint -Root $root
                $result.ExitCode | Should -Be 1
                $result.Output | Should -Match "'description' is missing or empty"
            }
            finally { Remove-Item -LiteralPath $root -Recurse -Force }
        }

        It 'blocks a block scalar with an explicit indentation indicator when expanded text is oversized' {
            $root = New-TestRepo
            try {
                $chunk = 'x' * 600
                $frontmatter = "name: indent-indicator`ndescription: |2$([Environment]::NewLine)  $chunk$([Environment]::NewLine)  $chunk"
                New-TestSkill -Root $root -Name 'indent-indicator' -Frontmatter $frontmatter
                $result = Invoke-SkillsLint -Root $root
                $result.ExitCode | Should -Be 1
                $result.Output | Should -Match "'description' exceeds 1024 characters \(got 1202\)"
            }
            finally { Remove-Item -LiteralPath $root -Recurse -Force }
        }

        It 'blocks a block scalar header carrying a comment when expanded text is oversized' {
            $root = New-TestRepo
            try {
                $chunk = 'x' * 600
                $frontmatter = "name: header-comment`ndescription: >- # folded, strip$([Environment]::NewLine)  $chunk$([Environment]::NewLine)  $chunk"
                New-TestSkill -Root $root -Name 'header-comment' -Frontmatter $frontmatter
                $result = Invoke-SkillsLint -Root $root
                $result.ExitCode | Should -Be 1
                $result.Output | Should -Match "'description' exceeds 1024 characters"
            }
            finally { Remove-Item -LiteralPath $root -Recurse -Force }
        }
    }

    Context 'scalar precision' {

        It 'blocks an oversized literal block whose trailing spaces push it past 1024 characters' {
            $root = New-TestRepo
            try {
                $line = ('x' * 1020) + (' ' * 10)
                $frontmatter = "name: trail-space`ndescription: |$([Environment]::NewLine)  $line"
                New-TestSkill -Root $root -Name 'trail-space' -Frontmatter $frontmatter
                $result = Invoke-SkillsLint -Root $root
                $result.ExitCode | Should -Be 1
                $result.Output | Should -Match "'description' exceeds 1024 characters \(got 1031\)"
            }
            finally { Remove-Item -LiteralPath $root -Recurse -Force }
        }

        It 'blocks a YAML-null description written as a bare comment' {
            $root = New-TestRepo
            try {
                New-TestSkill -Root $root -Name 'null-comment' -Frontmatter "name: null-comment`ndescription: # TODO"
                $result = Invoke-SkillsLint -Root $root
                $result.ExitCode | Should -Be 1
                $result.Output | Should -Match "'description' is missing or empty"
            }
            finally { Remove-Item -LiteralPath $root -Recurse -Force }
        }

        It 'accepts an unquoted description carrying an inline comment' {
            $root = New-TestRepo
            try {
                New-TestSkill -Root $root -Name 'inline-comment' -Frontmatter "name: inline-comment`ndescription: Real text # note"
                $result = Invoke-SkillsLint -Root $root
                $result.ExitCode | Should -Be 0
            }
            finally { Remove-Item -LiteralPath $root -Recurse -Force }
        }

        It 'accepts a quoted description containing a hash character' {
            $root = New-TestRepo
            try {
                $frontmatter = 'name: quoted-hash' + [Environment]::NewLine + 'description: "use issue #123 tracking"'
                New-TestSkill -Root $root -Name 'quoted-hash' -Frontmatter $frontmatter
                $result = Invoke-SkillsLint -Root $root
                $result.ExitCode | Should -Be 0
            }
            finally { Remove-Item -LiteralPath $root -Recurse -Force }
        }

        It 'blocks explicit YAML null spellings' {
            foreach ($spelling in @('null', '~')) {
                $root = New-TestRepo
                try {
                    New-TestSkill -Root $root -Name "null-$spelling" -Frontmatter "name: null-x`ndescription: $spelling"
                    $result = Invoke-SkillsLint -Root $root
                    $result.ExitCode | Should -Be 1
                    $result.Output | Should -Match "'description' is missing or empty"
                }
                finally { Remove-Item -LiteralPath $root -Recurse -Force }
            }
        }

        It 'measures trailing whitespace inside quoted descriptions' {
            $root = New-TestRepo
            try {
                $quoted = '"' + ('x' * 1020) + (' ' * 10) + '"'
                New-TestSkill -Root $root -Name 'quoted-trail' -Frontmatter "name: quoted-trail`ndescription: $quoted"
                $result = Invoke-SkillsLint -Root $root
                $result.ExitCode | Should -Be 1
                $result.Output | Should -Match "'description' exceeds 1024 characters \(got 1030\)"
            }
            finally { Remove-Item -LiteralPath $root -Recurse -Force }
        }

        It 'ignores name and description nested under another frontmatter key' {
            $root = New-TestRepo
            try {
                $frontmatter = "metadata:$([Environment]::NewLine)  name: nested-skill$([Environment]::NewLine)  description: valid text"
                New-TestSkill -Root $root -Name 'nested-skill' -Frontmatter $frontmatter
                $result = Invoke-SkillsLint -Root $root
                $result.ExitCode | Should -Be 1
                $result.Output | Should -Match "'name' is missing or empty"
                $result.Output | Should -Match "'description' is missing or empty"
            }
            finally { Remove-Item -LiteralPath $root -Recurse -Force }
        }

        It 'counts the clipped final newline when measuring literal blocks at the boundary' {
            $root = New-TestRepo
            try {
                $body = 'x' * 1024
                $frontmatter = "name: clip-boundary`ndescription: |$([Environment]::NewLine)  $body"
                New-TestSkill -Root $root -Name 'clip-boundary' -Frontmatter $frontmatter
                $result = Invoke-SkillsLint -Root $root
                $result.ExitCode | Should -Be 1
                $result.Output | Should -Match "'description' exceeds 1024 characters \(got 1025\)"
            }
            finally { Remove-Item -LiteralPath $root -Recurse -Force }
        }

        It 'accepts a strip-chomped block at exactly 1024 characters' {
            $root = New-TestRepo
            try {
                $body = 'x' * 1024
                $frontmatter = "name: strip-boundary`ndescription: |-$([Environment]::NewLine)  $body"
                New-TestSkill -Root $root -Name 'strip-boundary' -Frontmatter $frontmatter
                $result = Invoke-SkillsLint -Root $root
                $result.ExitCode | Should -Be 0
            }
            finally { Remove-Item -LiteralPath $root -Recurse -Force }
        }

        It 'checks link destinations that carry optional titles' {
            $root = New-TestRepo
            try {
                New-TestSkill -Root $root -Name 'link-titles' `
                    -Frontmatter "name: link-titles`ndescription: Something useful." `
                    -Body @'
See [missing](MISSING.md "details") and [present](titled.md "ok").
'@ `
                    -Files @('titled.md')
                $result = Invoke-SkillsLint -Root $root
                $result.ExitCode | Should -Be 1
                $result.Output | Should -Match "references 'MISSING\.md' but it does not exist"
            }
            finally { Remove-Item -LiteralPath $root -Recurse -Force }
        }
    }

    Context 'parent-relative reference escapes' {

        It 'blocks a link that resolves outside the skill folder even when the target exists' {
            $root = New-TestRepo
            try {
                Set-Content -LiteralPath (Join-Path $root 'shared.md') -Value 'shared' -Encoding utf8
                New-TestSkill -Root $root -Name 'escaper' `
                    -Frontmatter "name: escaper`ndescription: Tries to reach outside its folder." `
                    -Body 'Borrow [shared notes](../shared.md) first.'
                $result = Invoke-SkillsLint -Root $root
                $result.ExitCode | Should -Be 1
                $result.Output | Should -Match "references '\.\./shared\.md' which escapes the skill folder"
            }
            finally { Remove-Item -LiteralPath $root -Recurse -Force }
        }
    }

    Context 'staged content validation' {

        It 'validates the index version when SKILL.md has staged changes' {
            $root = New-TestRepo
            try {
                $skillDir = New-TestSkill -Root $root -Name 'staged-skill' `
                    -Frontmatter "name: wrong-name`ndescription: Something useful."
                & git init -q $root
                & git -C $root config user.email 'test@example.com'
                & git -C $root config user.name 'test'
                & git -C $root add .
                Set-Content -LiteralPath (Join-Path $skillDir 'SKILL.md') `
                    -Value "---$([Environment]::NewLine)name: staged-skill$([Environment]::NewLine)description: Something useful.$([Environment]::NewLine)---" `
                    -Encoding utf8
                $result = Invoke-SkillsLint -Root $root
                $result.ExitCode | Should -Be 1
                $result.Output | Should -Match "does not match directory 'staged-skill'"
            }
            finally { Remove-Item -LiteralPath $root -Recurse -Force }
        }

        It 'passes when the staged version is valid even if the working tree drifted' {
            $root = New-TestRepo
            try {
                $skillDir = New-TestSkill -Root $root -Name 'clean-stage' `
                    -Frontmatter "name: clean-stage`ndescription: Something useful."
                & git init -q $root
                & git -C $root config user.email 'test@example.com'
                & git -C $root config user.name 'test'
                & git -C $root add .
                Set-Content -LiteralPath (Join-Path $skillDir 'SKILL.md') `
                    -Value "---$([Environment]::NewLine)name: drifted-name`ndescription: Something useful.$([Environment]::NewLine)---" `
                    -Encoding utf8
                $result = Invoke-SkillsLint -Root $root
                $result.ExitCode | Should -Be 0
            }
            finally { Remove-Item -LiteralPath $root -Recurse -Force }
        }

        It 'blocks a staged reference whose target exists on disk but is not staged' {
            $root = New-TestRepo
            try {
                New-TestSkill -Root $root -Name 'untracked-target' `
                    -Frontmatter "name: untracked-target`ndescription: Something useful." `
                    -Body @'
Read [the guide](references/late.md) first.
'@ `
                    -Files @('references/late.md')
                & git init -q $root
                & git -C $root config user.email 'test@example.com'
                & git -C $root config user.name 'test'
                & git -C $root add (Join-Path $root 'untracked-target\SKILL.md')
                $result = Invoke-SkillsLint -Root $root
                $result.ExitCode | Should -Be 1
                $result.Output | Should -Match "references 'references/late\.md' but it does not exist"
            }
            finally { Remove-Item -LiteralPath $root -Recurse -Force }
        }

        It 'accepts a staged reference when its target is staged too' {
            $root = New-TestRepo
            try {
                New-TestSkill -Root $root -Name 'tracked-target' `
                    -Frontmatter "name: tracked-target`ndescription: Something useful." `
                    -Body @'
Read [the guide](references/on-time.md) first.
'@ `
                    -Files @('references/on-time.md')
                & git init -q $root
                & git -C $root config user.email 'test@example.com'
                & git -C $root config user.name 'test'
                & git -C $root add .
                $result = Invoke-SkillsLint -Root $root
                $result.ExitCode | Should -Be 0
            }
            finally { Remove-Item -LiteralPath $root -Recurse -Force }
        }
    }

    Context 'index-discovered skills' {

        It 'validates a staged skill whose files were deleted from the working tree' {
            $root = New-TestRepo
            try {
                $skillDir = New-TestSkill -Root $root -Name 'ghost-skill' `
                    -Frontmatter "name: wrong-name`ndescription: Something useful."
                & git init -q $root
                & git -C $root config user.email 'test@example.com'
                & git -C $root config user.name 'test'
                & git -C $root add .
                Remove-Item -LiteralPath (Join-Path $skillDir 'SKILL.md') -Force
                Remove-Item -LiteralPath $skillDir -Recurse -Force
                $result = Invoke-SkillsLint -Root $root
                $result.ExitCode | Should -Be 1
                $result.Output | Should -Match "does not match directory 'ghost-skill'"
            }
            finally { Remove-Item -LiteralPath $root -Recurse -Force }
        }

        It 'passes a valid staged skill whose files were deleted from the working tree' {
            $root = New-TestRepo
            try {
                $skillDir = New-TestSkill -Root $root -Name 'clean-ghost' `
                    -Frontmatter "name: clean-ghost`ndescription: Something useful."
                & git init -q $root
                & git -C $root config user.email 'test@example.com'
                & git -C $root config user.name 'test'
                & git -C $root add .
                Remove-Item -LiteralPath (Join-Path $skillDir 'SKILL.md') -Force
                Remove-Item -LiteralPath $skillDir -Recurse -Force
                $result = Invoke-SkillsLint -Root $root
                $result.ExitCode | Should -Be 0
            }
            finally { Remove-Item -LiteralPath $root -Recurse -Force }
        }
    }
}
