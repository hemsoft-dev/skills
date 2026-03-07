#!/usr/bin/env pwsh
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Managed by copilot-hooks skill

function Write-Info([string]$Message) {
    [Console]::Error.WriteLine("[agent-session-hook] $Message")
}

function Get-OptionalPropertyValue($InputObject, [string]$PropertyName, [string]$DefaultValue = 'unknown') {
    if ($null -eq $InputObject) {
        return $DefaultValue
    }

    $property = $InputObject.PSObject.Properties[$PropertyName]
    if ($null -eq $property) {
        return $DefaultValue
    }

    $value = $property.Value
    if ($null -eq $value) {
        return $DefaultValue
    }

    $text = "$value"
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $DefaultValue
    }

    return $text
}

function Get-OptionalPropertyValues($InputObject, [string[]]$PropertyNames, [string]$DefaultValue = 'unknown') {
    foreach ($propertyName in $PropertyNames) {
        $value = Get-OptionalPropertyValue -InputObject $InputObject -PropertyName $propertyName -DefaultValue $DefaultValue
        if ($value -ne $DefaultValue) {
            return $value
        }
    }

    return $DefaultValue
}

function Get-HookInput {
    try {
        $raw = [Console]::In.ReadToEnd()
        if ([string]::IsNullOrWhiteSpace($raw)) {
            return $null
        }

        return ($raw | ConvertFrom-Json)
    }
    catch {
        Write-Info "Unable to parse hook stdin payload: $($_.Exception.Message)"
        return $null
    }
}

function Write-HookRuntimeLog($HookInput) {
    $tempPath = if ($env:TEMP) { $env:TEMP } else { [IO.Path]::GetTempPath() }
    $logPath = Join-Path $tempPath 'copilot-stop-hook.log'

    $eventName = Get-OptionalPropertyValues -InputObject $HookInput -PropertyNames @('hookEventName', 'hook_event_name')
    $sessionId = Get-OptionalPropertyValues -InputObject $HookInput -PropertyNames @('sessionId', 'session_id')
    $active = Get-OptionalPropertyValue -InputObject $HookInput -PropertyName 'stop_hook_active'
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | event=$eventName | session=$sessionId | stop_hook_active=$active"

    Add-Content -Path $logPath -Value $line
}

function Get-StatusPorcelain {
    return (git status --porcelain)
}

function Invoke-GitAdd {
    $addOutput = @(& git add -A 2>&1)
    if ($LASTEXITCODE -ne 0) {
        $details = ($addOutput -join [Environment]::NewLine)
        throw "git add failed during session-stop staging.$([Environment]::NewLine)$details"
    }

    $filtered = @(
        $addOutput |
            ForEach-Object { "$($_)" } |
            Where-Object { $_ -and ($_ -notmatch 'will be replaced by') }
    )

    foreach ($line in $filtered) {
        Write-Info "git add: $line"
    }
}

function Get-StagedFiles {
    return @(
        git diff --cached --name-only |
            ForEach-Object { "$($_)".Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
}

function Get-StagedShortStat {
    return ((git diff --cached --shortstat | Out-String).Trim())
}

function Get-BranchState {
    $branch = ((git rev-parse --abbrev-ref HEAD) | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($branch) -or $branch -eq 'HEAD') {
        return 'detached HEAD'
    }

    return $branch
}

function Get-RemoteNames {
    return @(
        git remote |
            ForEach-Object { "$($_)".Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
}

function Get-PreferredRemoteName {
    $remoteNames = @(Get-RemoteNames)
    if ($remoteNames -contains 'origin') {
        return 'origin'
    }

    if ($remoteNames.Count -eq 1) {
        return $remoteNames[0]
    }

    return ''
}

function Get-BranchSyncState([string]$BranchName) {
    $upstreamRef = ((git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null) | Out-String).Trim()
    $hasUpstream = ($LASTEXITCODE -eq 0) -and (-not [string]::IsNullOrWhiteSpace($upstreamRef))
    $aheadCount = 0
    $behindCount = 0
    $remoteName = ''

    if ($hasUpstream) {
        if ($upstreamRef -match '^([^/]+)/') {
            $remoteName = $Matches[1]
        }

        $counts = ((git rev-list --left-right --count "$upstreamRef...HEAD") | Out-String).Trim()
        if ($LASTEXITCODE -eq 0 -and $counts -match '^\s*(\d+)\s+(\d+)\s*$') {
            $behindCount = [int]$Matches[1]
            $aheadCount = [int]$Matches[2]
        }
    }

    if ([string]::IsNullOrWhiteSpace($remoteName)) {
        $remoteName = Get-PreferredRemoteName
    }

    return [pscustomobject]@{
        BranchName = $BranchName
        HasUpstream = $hasUpstream
        UpstreamRef = $upstreamRef
        RemoteName = $remoteName
        AheadCount = $aheadCount
        BehindCount = $behindCount
    }
}

function Get-CommandSummary([string[]]$Lines, [string]$Fallback) {
    $messages = @(
        $Lines |
            ForEach-Object { "$($_)".Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )

    if ($messages.Count -eq 0) {
        return $Fallback
    }

    $meaningfulMessages = @(
        $messages |
            Where-Object {
                $_ -notmatch '^(To |Everything up-to-date$|branch .* -> FETCH_HEAD$)' -and
                $_ -notmatch '^warning:'
            }
    )

    if ($meaningfulMessages.Count -eq 0) {
        $meaningfulMessages = $messages
    }

    return ($meaningfulMessages -join ' | ')
}

function Invoke-GitPush([string]$BranchName, [string]$RemoteName, [bool]$SetUpstream) {
    if ([string]::IsNullOrWhiteSpace($RemoteName)) {
        return [pscustomobject]@{
            Success = $false
            Summary = 'No git remote is configured for push.'
            Target = $BranchName
        }
    }

    $pushArgs = New-Object System.Collections.Generic.List[string]
    $pushArgs.Add('push')
    if ($SetUpstream) {
        $pushArgs.Add('--set-upstream')
    }
    $pushArgs.Add($RemoteName)
    $pushArgs.Add($BranchName)

    $pushOutput = @(& git @pushArgs 2>&1)
    $pushSucceeded = $LASTEXITCODE -eq 0
    foreach ($line in @($pushOutput | ForEach-Object { "$($_)" })) {
        if (-not [string]::IsNullOrWhiteSpace($line)) {
            Write-Info "git push: $line"
        }
    }

    $target = "$RemoteName/$BranchName"
    return [pscustomobject]@{
        Success = $pushSucceeded
        Summary = (Get-CommandSummary -Lines $pushOutput -Fallback 'git push did not return output.')
        Target = $target
    }
}

function New-StagedFileReport([string[]]$Files) {
    $fileList = @($Files)
    if ($fileList.Count -eq 0) {
        return '- None'
    }

    $preview = New-Object System.Collections.Generic.List[string]
    $previewCount = [Math]::Min($fileList.Count, 15)
    for ($index = 0; $index -lt $previewCount; $index++) {
        $preview.Add("- $($fileList[$index])")
    }

    if ($fileList.Count -gt $previewCount) {
        $preview.Add("- ... (+$($fileList.Count - $previewCount) more)")
    }

    return ($preview -join [Environment]::NewLine)
}

function Get-NormalizedPaths([string[]]$Files) {
    return @($Files | ForEach-Object { "$($_)".Replace('\', '/') })
}

function Get-ChangeAreas([string[]]$Files) {
    $areas = New-Object System.Collections.Generic.List[string]
    foreach ($file in (Get-NormalizedPaths -Files $Files)) {
        $area = if ($file -match '^\.github/hooks/' -or $file -match '^copilot-hooks/') {
            'copilot-hooks'
        }
        elseif ($file -match '^diary/') {
            'diary'
        }
        elseif ($file -match '^([^/]+)/') {
            $Matches[1]
        }
        else {
            'workspace'
        }

        if (-not $areas.Contains($area)) {
            $areas.Add($area)
        }
    }

    return @($areas)
}

function Get-CommitType([string[]]$Files) {
    $normalizedFiles = Get-NormalizedPaths -Files $Files
    if (@($normalizedFiles | Where-Object { $_ -match '^\.github/hooks/' -or $_ -match '^copilot-hooks/' }).Count -gt 0) {
        return 'fix'
    }

    if (@($normalizedFiles | Where-Object { $_ -match '/scripts/' -or $_ -match '/config/' }).Count -gt 0) {
        return 'feat'
    }

    if (@($normalizedFiles | Where-Object { $_ -notmatch '\.md$|\.txt$|\.json$' }).Count -eq 0) {
        return 'docs'
    }

    return 'chore'
}

function Get-CommitScope([string[]]$Files) {
    $areas = @(Get-ChangeAreas -Files $Files)
    if ($areas.Count -eq 1) {
        return $areas[0]
    }

    return 'skills'
}

function Get-CommitSubject([string[]]$Files) {
    $normalizedFiles = Get-NormalizedPaths -Files $Files
    $areas = @(Get-ChangeAreas -Files $Files)

    if ($areas.Count -eq 1 -and $areas[0] -eq 'copilot-hooks') {
        return 'stabilize stop hook automation'
    }

    if ($areas.Count -eq 1 -and $areas[0] -eq 'diary') {
        if (@($normalizedFiles | Where-Object { $_ -eq 'diary/scripts/050-daily-numbers.ps1' }).Count -gt 0) {
            return 'track repo count delta details'
        }

        $entryFiles = @($normalizedFiles | Where-Object { $_ -match '^diary/entries/(\d{4}-\d{2}-\d{2})\.md$' })
        if ($entryFiles.Count -eq 1 -and @($normalizedFiles | Where-Object { $_ -match '^diary/scripts/' -or $_ -match '^diary/config/' }).Count -eq 0) {
            $null = $entryFiles[0] -match '^diary/entries/(\d{4}-\d{2}-\d{2})\.md$'
            return "update $($Matches[1]) entry"
        }

        return 'update diary automation'
    }

    if ($areas -contains 'copilot-hooks' -and $areas -contains 'diary') {
        return 'update hook and diary automation'
    }

    return 'update workspace automation'
}

function New-CommitBody([string[]]$Files, [string]$ShortStat) {
    $areas = @(Get-ChangeAreas -Files $Files)
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('Automated session-stop commit.')
    $lines.Add('')
    $lines.Add('Staged summary:')
    $lines.Add($ShortStat)
    $lines.Add('')
    $lines.Add('Areas:')
    foreach ($area in $areas) {
        $lines.Add("- $area")
    }
    $lines.Add('')
    $lines.Add('Files:')
    foreach ($line in (New-StagedFileReport -Files $Files).Split([Environment]::NewLine)) {
        $lines.Add($line)
    }

    return ($lines -join [Environment]::NewLine)
}

function Invoke-GitCommit([string]$Subject, [string]$Body) {
    $commitOutput = @(& git commit -m $Subject -m $Body 2>&1)
    if ($LASTEXITCODE -ne 0) {
        $details = ($commitOutput -join [Environment]::NewLine)
        throw "git commit failed during session-stop automation.$([Environment]::NewLine)$details"
    }

    foreach ($line in @($commitOutput | ForEach-Object { "$($_)" })) {
        if (-not [string]::IsNullOrWhiteSpace($line)) {
            Write-Info "git commit: $line"
        }
    }
}

$repoRoot = (git rev-parse --show-toplevel).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($repoRoot)) {
    throw 'Not inside a Git repository.'
}

$hookInput = Get-HookInput
Write-HookRuntimeLog -HookInput $hookInput

Write-Info "Running in $repoRoot"

$branchState = Get-BranchState
$syncState = if ($branchState -ne 'detached HEAD') { Get-BranchSyncState -BranchName $branchState } else { $null }

$status = Get-StatusPorcelain
if (-not $status) {
    Write-Info 'Working tree is clean.'

    if ($null -ne $syncState -and $syncState.HasUpstream -and $syncState.AheadCount -gt 0) {
        Write-Info "Detected $($syncState.AheadCount) unpushed commit(s) on '$branchState'. Attempting push."
        $pushResult = Invoke-GitPush -BranchName $branchState -RemoteName $syncState.RemoteName -SetUpstream:$false
        if ($pushResult.Success) {
            @{ continue = $true; systemMessage = "Pushed $($syncState.AheadCount) unpushed commit(s) from '$branchState'." } | ConvertTo-Json -Compress
            exit 0
        }

        @{ continue = $true; systemMessage = "Working tree was clean, but push of $($syncState.AheadCount) local commit(s) from '$branchState' failed: $($pushResult.Summary)" } | ConvertTo-Json -Compress
        exit 0
    }

    if ($branchState -eq 'detached HEAD') {
        @{ continue = $true; systemMessage = 'Working tree is clean. Stop hook skipped push because the repository is in detached HEAD.' } | ConvertTo-Json -Compress
        exit 0
    }

    @{ continue = $true; systemMessage = 'Working tree is clean; nothing to commit or push.' } | ConvertTo-Json -Compress
    exit 0
}

Write-Info 'Detected uncommitted changes at session stop. Staging them for an auto-commit and push.'
Invoke-GitAdd

$stagedFiles = @(Get-StagedFiles)
if (-not $stagedFiles) {
    Write-Info 'No staged changes remain after git add.'
    @{ continue = $true; systemMessage = 'No staged changes remained after auto-staging; nothing to commit or push.' } | ConvertTo-Json -Compress
    exit 0
}

$subject = "$(Get-CommitType -Files $stagedFiles)($(Get-CommitScope -Files $stagedFiles)): $(Get-CommitSubject -Files $stagedFiles)"
$shortStat = Get-StagedShortStat
if ([string]::IsNullOrWhiteSpace($shortStat)) {
    $shortStat = 'No diff stat available.'
}

if ($branchState -eq 'detached HEAD') {
    $output = @{
        hookSpecificOutput = @{
            hookEventName = 'Stop'
            decision = 'block'
            reason = 'The repository is in detached HEAD. Check out or create a branch before ending the session so the stop hook can create a local commit safely.'
        }
    }
    $output | ConvertTo-Json -Depth 5 -Compress
    exit 0
}

try {
    $body = New-CommitBody -Files $stagedFiles -ShortStat $shortStat
    Invoke-GitCommit -Subject $subject -Body $body

    $commitHash = ((git rev-parse --short HEAD) | Out-String).Trim()
    $syncState = Get-BranchSyncState -BranchName $branchState

    if ($syncState.HasUpstream -and $syncState.BehindCount -gt 0) {
        $output = @{
            continue = $true
            systemMessage = "Auto-committed staged session changes as '$subject' ($commitHash), but push was skipped because '$branchState' is behind '$($syncState.UpstreamRef)' by $($syncState.BehindCount) commit(s)."
        }
    }
    else {
        $pushResult = Invoke-GitPush -BranchName $branchState -RemoteName $syncState.RemoteName -SetUpstream:(-not $syncState.HasUpstream)
        if ($pushResult.Success) {
            $output = @{
                continue = $true
                systemMessage = "Auto-committed staged session changes as '$subject' ($commitHash) and pushed '$branchState'."
            }
        }
        else {
            $output = @{
                continue = $true
                systemMessage = "Auto-committed staged session changes as '$subject' ($commitHash), but push to '$($pushResult.Target)' failed: $($pushResult.Summary)"
            }
        }
    }
}
catch {
    $output = @{
        hookSpecificOutput = @{
            hookEventName = 'Stop'
            decision = 'block'
            reason = "$($_.Exception.Message)$([Environment]::NewLine)$([Environment]::NewLine)Inspect the staged diff and fix the commit failure before ending the session."
        }
    }
}

$output | ConvertTo-Json -Depth 5 -Compress
exit 0
