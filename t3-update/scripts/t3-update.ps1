<#
.SYNOPSIS
    Brings the local T3 Code install up to date with the "Waiting" patch loaded, restarting T3 only when needed.

.DESCRIPTION
    1. Reads the state: installed version, pending update, patch status, whether the running T3 predates
       the patched server.asar, and the watcher task.
    2. Applies t3-waiting-patch.ps1 (same folder).
    3. Restarts T3 when it runs stale code, when a downloaded update is waiting to install, or with -Force.
       It launches T3 when it isn't running.

    The restart runs in a one-shot scheduled task ("T3 Update Worker"), outside T3's process tree. A caller
    inside a T3 thread dies with T3, but the worker still finishes: it closes T3 gracefully (forced after
    30 s), waits for the updater's installer, patches, relaunches T3 through Explorer and writes a result file.

    Exit codes: 0 done, 2 patch rule not found in this build, 3 restart failed or timed out.

.EXAMPLE
    pwsh -NoProfile -File t3-update.ps1 -Status
.EXAMPLE
    pwsh -NoProfile -File t3-update.ps1
.EXAMPLE
    pwsh -NoProfile -File t3-update.ps1 -Force
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]
[CmdletBinding(PositionalBinding = $false)]
param(
    [switch]$Status,
    [switch]$Force,
    [switch]$NoRestart,
    [switch]$Worker,
    [string]$RunId,
    [int]$TimeoutSeconds = 600
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$PatchScript = Join-Path $PSScriptRoot 't3-waiting-patch.ps1'
$InstallDir = Join-Path $env:LOCALAPPDATA 'Programs\t3code'
$Exe = Join-Path $InstallDir 'T3 Code (Nightly).exe'
$Asar = Join-Path $InstallDir 'resources\server.asar'
$UpdaterDir = Join-Path $env:LOCALAPPDATA 't3code-updater'
$StateDir = Join-Path $env:LOCALAPPDATA 't3-waiting-patch'
$WatchTask = 'T3 Waiting Patch'
$WorkerTask = 'T3 Update Worker'
$Pwsh = (Get-Command pwsh.exe).Source

function Write-UpdateLog([string]$Message) {
    $line = '{0:yyyy-MM-dd HH:mm:ss} {1}' -f (Get-Date), $Message
    Write-Host $line
    try {
        $null = New-Item -ItemType Directory -Force -Path $StateDir
        Add-Content -Path (Join-Path $StateDir 'update-log.txt') -Value $line
    } catch {
        Write-Verbose "Log write failed: $($_.Exception.Message)"
    }
}

function Get-T3Process {
    @(Get-Process | Where-Object { $_.Path -and $_.Path.StartsWith($InstallDir + '\', [StringComparison]::OrdinalIgnoreCase) })
}

function Get-InstallerProcess {
    @(Get-Process | Where-Object {
            ($_.Path -and $_.Path.StartsWith($UpdaterDir + '\', [StringComparison]::OrdinalIgnoreCase)) -or $_.ProcessName -like 'T3-Code-*-x64'
        })
}

function Invoke-PatchScript([string[]]$Arguments) {
    $output = & $Pwsh -NoProfile -NonInteractive -File $PatchScript @Arguments 2>&1
    [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = @($output | ForEach-Object { "$_" }) }
}

function Get-T3State {
    $check = Invoke-PatchScript @('-Check', '-Json')
    if ($check.ExitCode -ne 0) { throw "t3-waiting-patch -Check failed: $($check.Output -join ' ')" }
    $patch = ($check.Output | Where-Object { $_.StartsWith('{') } | Select-Object -Last 1) | ConvertFrom-Json
    $client = $patch.targets | Where-Object name -eq 'client'

    $pending = $null
    $info = Join-Path $UpdaterDir 'pending\update-info.json'
    if (Test-Path $info) {
        $file = (Get-Content -Raw $info | ConvertFrom-Json).fileName
        if ($file -match '^T3-Code-(.+)-x64\.exe$' -and $Matches[1] -ne $patch.version -and
            (Test-Path (Join-Path $UpdaterDir "pending\$file"))) {
            $pending = $Matches[1]
        }
    }

    $processes = Get-T3Process
    $startedAt = if ($processes.Count) { ($processes | Measure-Object -Property StartTime -Minimum).Minimum } else { $null }
    $asarWrittenAt = (Get-Item -LiteralPath $Asar).LastWriteTime
    $task = Get-ScheduledTask -TaskName $WatchTask -ErrorAction SilentlyContinue

    [pscustomobject]@{
        Version       = $patch.version
        PendingUpdate = $pending
        ClientPatch   = $client.status
        PatchDetail   = $client.detail
        Running       = $processes.Count -gt 0
        StartedAt     = $startedAt
        AsarWrittenAt = $asarWrittenAt
        Stale         = ($null -ne $startedAt) -and ($startedAt -lt $asarWrittenAt)
        WatchTask     = if ($task) { "$($task.State)" } else { 'missing' }
    }
}

function Format-T3State($State) {
    $running = if (-not $State.Running) { 'not running' }
    elseif ($State.Stale) { "running since $($State.StartedAt.ToString('HH:mm:ss')), older than server.asar ($($State.AsarWrittenAt.ToString('HH:mm:ss'))): stale code" }
    else { "running since $($State.StartedAt.ToString('HH:mm:ss')), current code" }
    @(
        "Installed:      $($State.Version)"
        "Pending update: $(if ($State.PendingUpdate) { $State.PendingUpdate } else { 'none' })"
        "Waiting patch:  $($State.ClientPatch)$(if ($State.PatchDetail) { " ($($State.PatchDetail))" })"
        "T3:             $running"
        "Watcher task:   $($State.WatchTask)"
    ) -join "`n"
}

function Close-T3 {
    $processes = Get-T3Process
    if (-not $processes.Count) { return 'not running' }
    $main = $processes | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
    if ($main) {
        $null = $main.CloseMainWindow()
    } else {
        # No visible window (e.g. hidden to the tray): taskkill without /F still asks politely.
        $ids = $processes | ForEach-Object { $_.Id }
        foreach ($id in $ids) { & taskkill.exe /PID $id 2>&1 | Out-Null }
    }
    $deadline = (Get-Date).AddSeconds(30)
    while ((Get-T3Process).Count -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 500 }
    $left = Get-T3Process
    if ($left.Count) {
        $left | Stop-Process -Force
        Start-Sleep -Seconds 2
        if ((Get-T3Process).Count) { throw 'T3 processes survived a forced stop' }
        return "forced after 30 s ($($left.Count) processes)"
    }
    'closed gracefully'
}

function Wait-Installer {
    # electron-updater installs a downloaded update when the app quits; give it a moment to start.
    $deadline = (Get-Date).AddSeconds(8)
    while (-not (Get-InstallerProcess).Count -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 500 }
    if (-not (Get-InstallerProcess).Count) { return 'no installer ran' }
    $deadline = (Get-Date).AddMinutes(5)
    while ((Get-InstallerProcess).Count -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 1 }
    if ((Get-InstallerProcess).Count) { throw 'The T3 installer is still running after 5 minutes' }
    Start-Sleep -Seconds 2
    'installer finished'
}

function Open-T3 {
    Start-Process -FilePath (Join-Path $env:SystemRoot 'explorer.exe') -ArgumentList "`"$Exe`""
    $deadline = (Get-Date).AddSeconds(90)
    do {
        Start-Sleep -Seconds 1
        $window = Get-T3Process | Where-Object { $_.MainWindowHandle -ne 0 }
    } until ($window -or (Get-Date) -gt $deadline)
    if (-not $window) { throw 'T3 did not open a window within 90 s' }
    "started (pid $(@($window)[0].Id))"
}

function Get-ResultPath([string]$Id) { Join-Path $StateDir "update-result-$Id.json" }

function Invoke-Worker {
    $steps = [Collections.Generic.List[string]]::new()
    $exitCode = 0
    try {
        Start-Sleep -Seconds 3
        Write-UpdateLog "Worker $RunId started"
        $steps.Add("close: $(Close-T3)")
        $steps.Add("update: $(Wait-Installer)")
        if ((Get-T3Process).Count) { $steps.Add("close after install: $(Close-T3)") }
        $patch = Invoke-PatchScript @()
        $steps.Add("patch: $(($patch.Output | Select-Object -Last 1))")
        if ($patch.ExitCode -eq 2) { $exitCode = 2 } elseif ($patch.ExitCode -ne 0) { throw "patch failed: $($patch.Output -join ' ')" }
        $steps.Add("launch: $(Open-T3)")
    } catch {
        $steps.Add("error: $($_.Exception.Message)")
        $exitCode = 3
        if (-not (Get-T3Process).Count) {
            try { $steps.Add("recovery launch: $(Open-T3)") } catch { $steps.Add("recovery launch failed: $($_.Exception.Message)") }
        }
    }
    $state = Get-T3State
    if ($exitCode -eq 0 -and ($state.Stale -or -not $state.Running -or $state.ClientPatch -ne 'patched')) { $exitCode = 3 }
    $result = [pscustomobject]@{ runId = $RunId; exitCode = $exitCode; steps = $steps; state = (Format-T3State $state) }
    $result | ConvertTo-Json -Depth 4 | Set-Content -Path (Get-ResultPath $RunId)
    Write-UpdateLog "Worker $RunId finished with exit code $exitCode; $($steps -join '; ')"
}

function Submit-Worker {
    $id = Get-Date -Format 'yyyyMMdd-HHmmss'
    $arguments = "--headless `"$Pwsh`" -NoProfile -NonInteractive -File `"$PSCommandPath`" -Worker -RunId $id"
    $action = New-ScheduledTaskAction -Execute (Join-Path $env:SystemRoot 'System32\conhost.exe') -Argument $arguments
    $settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 15) `
        -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    $null = Register-ScheduledTask -TaskName $WorkerTask -Action $action -Settings $settings `
        -Description 'One-shot T3 restart started by the t3-update skill.' -Force
    Start-ScheduledTask -TaskName $WorkerTask
    $id
}

if ($Worker) {
    Invoke-Worker
    exit 0
}

$before = Get-T3State
Write-Host (Format-T3State $before)
if ($Status) { exit 0 }

if ($before.WatchTask -eq 'missing') {
    $null = Invoke-PatchScript @('-InstallTask')
    Write-Host 'Watcher task was missing; installed it'
} elseif ($before.WatchTask -ne 'Running') {
    Start-ScheduledTask -TaskName $WatchTask
    Write-Host 'Watcher task was not running; started it'
}

$patch = Invoke-PatchScript @()
Write-Host "Patch: $(($patch.Output | Select-Object -Last 1))"
if ($patch.ExitCode -ne 0 -and $patch.ExitCode -ne 2) { throw "t3-waiting-patch failed: $($patch.Output -join ' ')" }
$after = Get-T3State

$reasons = @()
if ($Force) { $reasons += 'forced' }
if ($after.PendingUpdate) { $reasons += "update $($after.PendingUpdate) waiting to install" }
if ($after.Stale) { $reasons += 'running T3 predates the patched server.asar' }
if (-not $after.Running) { $reasons += 'T3 is not running' }

if (-not $reasons.Count) {
    Write-Host 'T3 already runs the patched build; no restart needed.'
    exit ([int]($patch.ExitCode -eq 2) * 2)
}
if ($NoRestart) {
    Write-Host "Restart needed ($($reasons -join '; ')), skipped because of -NoRestart."
    exit ([int]($patch.ExitCode -eq 2) * 2)
}

$id = Submit-Worker
Write-Host "Restarting T3 ($($reasons -join '; ')); run $id. Running T3 agent sessions are interrupted."
Write-Host "If this runs inside a T3 thread it ends here; the worker finishes on its own. Result: $(Get-ResultPath $id)"
$resultPath = Get-ResultPath $id
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
while (-not (Test-Path $resultPath) -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 2 }
if (-not (Test-Path $resultPath)) {
    Write-Host "No result after $TimeoutSeconds s; see $(Join-Path $StateDir 'update-log.txt')"
    exit 3
}
$result = Get-Content -Raw $resultPath | ConvertFrom-Json
$result.steps | ForEach-Object { Write-Host "  $_" }
Write-Host $result.state
exit $result.exitCode
