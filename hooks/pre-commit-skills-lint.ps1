#!/usr/bin/env pwsh
# Managed by Install-GitHooks.ps1 — source of truth is the hooks/ folder in this repo.
# Git pre-commit hook that lints skill folders for structural defects:
#   - SKILL.md frontmatter per the agentskills.io spec: name matches the skill
#     directory, lowercase-hyphen name pattern, description of 1-1024 characters
#   - Relative files referenced from SKILL.md exist inside the skill folder
#   - Warns when two skills ship reference files with the same basename
#     (the diverged-copies defect class)

[CmdletBinding()]
param(
    # Overrides repository discovery so the test suite can lint fixture trees.
    [string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Success([string]$Message) { Write-Host $Message -ForegroundColor Green }
function Write-Fail([string]$Message) { Write-Host $Message -ForegroundColor Red }
function Write-Info([string]$Message) { Write-Host $Message -ForegroundColor Cyan }
function Write-WarnLine([string]$Message) { Write-Host $Message -ForegroundColor Yellow }

function Find-SkillDirectory {
    param([string]$Root)
    return @(Get-ChildItem -LiteralPath $Root -Directory | Where-Object {
        Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md')
    } | Sort-Object Name)
}

function Split-SkillFrontmatter {
    param([string]$Content)
    if ($Content -match '(?s)\A---\r?\n(.*?)\r?\n---(?:\r?\n|\z)') {
        return $Matches[1]
    }
    return $null
}

function Get-FrontmatterValue {
    param(
        [string]$Frontmatter,
        [string]$Field
    )
    if ($Frontmatter -notmatch ('(?m)^\s*' + [regex]::Escape($Field) + '\s*:\s*(.*)$')) {
        return $null
    }
    $value = $Matches[1].Trim()
    if ($value.Length -ge 2) {
        $first = $value.Substring(0, 1)
        $last = $value.Substring($value.Length - 1, 1)
        if (($first -eq '"' -and $last -eq '"') -or ($first -eq "'" -and $last -eq "'")) {
            $value = $value.Substring(1, $value.Length - 2).Trim()
        }
    }
    return $value
}

function Find-SkillReference {
    # Returns relative path tokens that SKILL.md genuinely references.
    # Fenced code blocks, inline code spans, URLs, absolute paths, and
    # placeholder patterns are excluded so prose examples do not count.
    param([string]$Path)

    $content = Get-Content -LiteralPath $Path -Raw
    if (-not $content) {
        return @()
    }

    $content = [regex]::Replace($content, '(?s)```.*?(```|\z)', '')
    $content = [regex]::Replace($content, '(?s)~~~.*?(~~~|\z)', '')
    $content = [regex]::Replace($content, '`[^`\r\n]*`', '')

    $tokens = @()
    foreach ($m in [regex]::Matches($content, '\[[^\]\r\n]*\]\(([^)\r\n\s]+)\)')) {
        $tokens += $m.Groups[1].Value
    }
    foreach ($m in [regex]::Matches($content, '(?<![\w./~-])([\w.-]+(?:/[\w.-]+)+\.[A-Za-z0-9]{1,6})(?![\w.-])')) {
        $tokens += $m.Groups[1].Value
    }

    $found = @()
    $seen = @{}
    foreach ($raw in $tokens) {
        $token = ($raw -split '#')[0].Trim()
        if (-not $token) { continue }
        if ($token -match '^(?:[A-Za-z][A-Za-z0-9+.\-]*:|//|/|~/)') { continue }
        if ($token -match '[\{\}<>|\*\?]') { continue }
        if ($token -notmatch '\.[A-Za-z0-9]{1,6}$') { continue }
        if (-not $seen.ContainsKey($token)) {
            $seen[$token] = $true
            $found += $token
        }
    }
    return $found
}

function Test-SkillFrontmatter {
    param(
        [string]$SkillDir,
        [System.IO.FileInfo]$SkillMd,
        [ref]$Errors
    )

    $content = Get-Content -LiteralPath $SkillMd.FullName -Raw
    $frontmatter = Split-SkillFrontmatter -Content $content

    if ($null -eq $frontmatter) {
        $Errors.Value.Add("missing YAML frontmatter block")
        return
    }

    $name = Get-FrontmatterValue -Frontmatter $frontmatter -Field 'name'
    if (-not $name) {
        $Errors.Value.Add("frontmatter 'name' is missing or empty")
    }
    else {
        if ($name -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$') {
            $Errors.Value.Add("frontmatter 'name' '$name' does not match ^[a-z0-9]+(-[a-z0-9]+)*$")
        }
        if ($name.Length -gt 64) {
            $Errors.Value.Add("frontmatter 'name' exceeds 64 characters")
        }
        $dirName = Split-Path -Leaf $SkillDir
        if ($name -ne $dirName) {
            $Errors.Value.Add("frontmatter 'name' '$name' does not match directory '$dirName'")
        }
    }

    $description = Get-FrontmatterValue -Frontmatter $frontmatter -Field 'description'
    if ($null -eq $description -or $description.Trim().Length -eq 0) {
        $Errors.Value.Add("frontmatter 'description' is missing or empty")
    }
    elseif ($description.Length -gt 1024) {
        $Errors.Value.Add("frontmatter 'description' exceeds 1024 characters (got $($description.Length))")
    }
}

function Test-SkillReference {
    param(
        [string]$SkillDir,
        [System.IO.FileInfo]$SkillMd,
        [ref]$Errors
    )

    foreach ($token in Find-SkillReference -Path $SkillMd.FullName) {
        $candidate = $token -replace '^\./', ''
        $target = Join-Path $SkillDir $candidate
        if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
            $Errors.Value.Add("SKILL.md references '$token' but it does not exist in the skill folder")
        }
    }
}

function Find-DuplicateReferenceBasename {
    param([object[]]$Skills)
    $byName = @{}
    foreach ($skill in $Skills) {
        $referencesDir = Join-Path $skill.FullName 'references'
        if (-not (Test-Path -LiteralPath $referencesDir)) { continue }
        $files = Get-ChildItem -LiteralPath $referencesDir -Recurse -File
        foreach ($file in $files) {
            if (-not $byName.ContainsKey($file.Name)) {
                $byName[$file.Name] = @()
            }
            $byName[$file.Name] += Split-Path -Leaf $skill.FullName
        }
    }
    return $byName.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 } | Sort-Object Name
}

if (-not $RepoRoot) {
    $RepoRoot = git rev-parse --show-toplevel
    if ($LASTEXITCODE -ne 0) {
        Write-Fail 'Could not determine repository root'
        exit 1
    }
    if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
        $RepoRoot = $RepoRoot -replace '/', '\\'
    }
}

if (-not (Test-Path -LiteralPath $RepoRoot -PathType Container)) {
    Write-Fail "Repository root not found: $RepoRoot"
    exit 1
}

Write-Info 'Running skills structural checks...'

$skills = @(Find-SkillDirectory -Root $RepoRoot)
if ($skills.Count -eq 0) {
    Write-Success 'No skill folders found'
    exit 0
}

$errors = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

foreach ($skill in $skills) {
    $skillDir = $skill.FullName
    $skillMd = Join-Path $skillDir 'SKILL.md'
    $skillLabel = $skill.Name

    $skillErrors = New-Object System.Collections.Generic.List[string]
    $errorRef = [ref]$skillErrors
    Test-SkillFrontmatter -SkillDir $skillDir -SkillMd (Get-Item -LiteralPath $skillMd) -Errors $errorRef
    Test-SkillReference -SkillDir $skillDir -SkillMd (Get-Item -LiteralPath $skillMd) -Errors $errorRef

    if ($skillErrors.Count -gt 0) {
        Write-Fail "Checking: $skillLabel"
        foreach ($problem in $skillErrors) {
            Write-Fail "  $problem"
            $errors.Add("${skillLabel}: $problem")
        }
    }
    else {
        Write-Info "Checking: $skillLabel"
    }
}

foreach ($duplicate in Find-DuplicateReferenceBasename -Skills $skills) {
    $message = "reference basename '$($duplicate.Name)' ships in multiple skills: $($duplicate.Value -join ', ')"
    Write-WarnLine "WARNING: $message"
    $warnings.Add($message)
}

if ($errors.Count -gt 0) {
    Write-Fail "`nCOMMIT BLOCKED: skills lint found $($errors.Count) error(s)"
    if ($warnings.Count -gt 0) {
        Write-WarnLine "and $($warnings.Count) warning(s)"
    }
    exit 1
}

Write-Success "All $($skills.Count) skills passed structural checks"

exit 0
