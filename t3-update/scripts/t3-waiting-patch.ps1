<#
.SYNOPSIS
    Keeps T3 Code threads that wait on a background shell command visibly "Waiting" in the sidebar.

.DESCRIPTION
    Upstream T3 Code treats a still-running background shell command (pending work of kind "command") as
    "the agent is done" (pingdotgg/t3code#14910; #18966 closed wontfix). A thread waiting on CI or a long
    test run then looks finished. This script flips that one rule in the installed nightly's server.asar.

    The patch rewrites bytes in place, with the same length (`return!1` -> `return!0`), so nothing is
    unpacked or repacked. It then refreshes the asar header's SHA-256 integrity entries for the patched
    file. It never stops or starts T3; the change shows after T3's next restart. Every nightly update
    replaces server.asar, so -Watch re-applies the patch whenever the file changes.

    Patched by default (client): sidebar pill and Working section, composer "Waiting on" title and desktop
    completion alerts. -IncludeServer also patches the local backend (auto-settle and mobile push); that
    part takes effect only when the backend restarts with T3.

    Usually driven by t3-update.ps1 next to it (the t3-update skill), which also restarts T3.

.EXAMPLE
    pwsh -NoProfile -File t3-waiting-patch.ps1 -Check
.EXAMPLE
    pwsh -NoProfile -File t3-waiting-patch.ps1
.EXAMPLE
    pwsh -NoProfile -File t3-waiting-patch.ps1 -InstallTask
.EXAMPLE
    pwsh -NoProfile -File t3-waiting-patch.ps1 -Restore
#>
# The analyzer can't see parameters used inside functions.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]
[CmdletBinding(PositionalBinding = $false)]
param(
    [switch]$Check,
    [switch]$Json,
    [switch]$Restore,
    [switch]$Watch,
    [switch]$InstallTask,
    [switch]$UninstallTask,
    [switch]$IncludeServer,
    [int]$IntervalSeconds = 30,
    [string]$Asar = (Join-Path $env:LOCALAPPDATA 'Programs\t3code\resources\server.asar'),
    [string]$StateDir = (Join-Path $env:LOCALAPPDATA 't3-waiting-patch')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$TaskName = 'T3 Waiting Patch'
$Latin1 = [Text.Encoding]::Latin1

# Each target names the whole switch, so an unrelated `case "command"` can never match.
$Targets = @(
    [pscustomobject]@{
        Name     = 'client'
        Dir      = 'apps/server/dist/client/assets'
        Ext      = '.js'
        Original = 'case`command`:return!1;case`subagent`:case`monitor`:case`background_task`:return!0'
        Patched  = 'case`command`:return!0;case`subagent`:case`monitor`:case`background_task`:return!0'
    }
    [pscustomobject]@{
        Name     = 'server'
        Dir      = 'apps/server/dist'
        Ext      = '.mjs'
        Original = "case `"command`": return false;`n`t`tcase `"subagent`":`n`t`tcase `"monitor`":`n`t`tcase `"background_task`": return true;"
        Patched  = "case `"command`": return true; `n`t`tcase `"subagent`":`n`t`tcase `"monitor`":`n`t`tcase `"background_task`": return true;"
    }
)

function Write-PatchLog([string]$Message) {
    $line = '{0:yyyy-MM-dd HH:mm:ss} {1}' -f (Get-Date), $Message
    Write-Host $line
    try {
        $null = New-Item -ItemType Directory -Force -Path $StateDir
        $log = Join-Path $StateDir 'log.txt'
        Add-Content -Path $log -Value $line
        $lines = Get-Content -Path $log
        if ($lines.Count -gt 1000) { Set-Content -Path $log -Value ($lines | Select-Object -Last 500) }
    } catch {
        Write-Verbose "Log write failed: $($_.Exception.Message)"
    }
}

# The watcher task and t3-update.ps1 can both patch; one named mutex keeps them from writing at once.
function Invoke-Locked([scriptblock]$Action) {
    $mutex = [Threading.Mutex]::new($false, 'Global\t3-waiting-patch')
    $held = $false
    try {
        try { $held = $mutex.WaitOne([TimeSpan]::FromMinutes(5)) } catch [Threading.AbandonedMutexException] { $held = $true }
        if (-not $held) { throw 'Another t3-waiting-patch run is still busy after 5 minutes' }
        & $Action
    } finally {
        if ($held) { $mutex.ReleaseMutex() }
        $mutex.Dispose()
    }
}

function Open-AsarStream([string]$Path, [IO.FileAccess]$Access) {
    # T3 keeps server.asar open while it runs; share everything so neither side blocks the other.
    [IO.File]::Open($Path, [IO.FileMode]::Open, $Access, [IO.FileShare]'ReadWrite, Delete')
}

function Read-ByteRange([IO.FileStream]$Stream, [long]$Offset, [int]$Count) {
    $buffer = [byte[]]::new($Count)
    $null = $Stream.Seek($Offset, [IO.SeekOrigin]::Begin)
    $read = 0
    while ($read -lt $Count) {
        $n = $Stream.Read($buffer, $read, $Count - $read)
        if ($n -le 0) { throw "Unexpected end of file at $($Offset + $read)" }
        $read += $n
    }
    $buffer
}

function Write-ByteRange([IO.FileStream]$Stream, [long]$Offset, [byte[]]$Bytes) {
    $null = $Stream.Seek($Offset, [IO.SeekOrigin]::Begin)
    $Stream.Write($Bytes, 0, $Bytes.Length)
}

function Read-AsarHeader([IO.FileStream]$Stream) {
    $prefix = Read-ByteRange $Stream 0 16
    $sizePickle = [BitConverter]::ToUInt32($prefix, 0)
    $headerPickleSize = [BitConverter]::ToUInt32($prefix, 4)
    $jsonLength = [BitConverter]::ToInt32($prefix, 12)
    if ($sizePickle -ne 4 -or $jsonLength -le 0 -or $jsonLength -gt $headerPickleSize) {
        throw 'Not an asar archive (unexpected header layout)'
    }
    $jsonBytes = Read-ByteRange $Stream 16 $jsonLength
    $json = [Text.Encoding]::UTF8.GetString($jsonBytes)
    # System.Text.Json, not ConvertFrom-Json: PowerShell rejects keys that differ only by case,
    # which node_modules folders can contain.
    $options = [Text.Json.JsonDocumentOptions]@{ MaxDepth = 1024 }
    [pscustomobject]@{
        Json     = $json
        Bytes    = $jsonBytes
        Root     = [Text.Json.JsonDocument]::Parse($json, $options).RootElement
        DataBase = 8L + $headerPickleSize
    }
}

function Get-Child([Text.Json.JsonElement]$Element, [string]$Name) {
    $child = [Text.Json.JsonElement]::new()
    if ($Element.ValueKind -eq 'Object' -and $Element.TryGetProperty($Name, [ref]$child)) { return $child }
    $null
}

# A directory node keeps its JsonElement; a file node becomes an object with its offset, size and integrity.
function Get-AsarNode($Header, [string]$Path) {
    $node = $Header.Root
    foreach ($part in $Path.Split('/')) {
        $files = Get-Child $node 'files'
        if ($null -eq $files) { return $null }
        $node = Get-Child $files $part
        if ($null -eq $node) { return $null }
    }
    $node
}

function Get-DirEntry([Text.Json.JsonElement]$Dir) {
    $files = Get-Child $Dir 'files'
    if ($null -eq $files) { return }
    foreach ($property in $files.EnumerateObject()) {
        $element = $property.Value
        if ($null -ne (Get-Child $element 'files')) { continue }
        $unpacked = Get-Child $element 'unpacked'
        $offset = Get-Child $element 'offset'
        if ($null -eq $offset -or ($null -ne $unpacked -and $unpacked.ValueKind -eq 'True')) { continue }
        $integrity = Get-Child $element 'integrity'
        [pscustomobject]@{
            Name      = $property.Name
            Offset    = [long]$offset.GetString()
            Size      = (Get-Child $element 'size').GetInt32()
            Integrity = if ($null -eq $integrity) { $null } else {
                [pscustomobject]@{
                    BlockSize = (Get-Child $integrity 'blockSize').GetInt32()
                    Hash      = (Get-Child $integrity 'hash').GetString()
                    Blocks    = @((Get-Child $integrity 'blocks').EnumerateArray() | ForEach-Object { $_.GetString() })
                }
            }
        }
    }
}

function Get-Sha256Hex([byte[]]$Bytes, [int]$Offset = 0, [int]$Count = -1) {
    if ($Count -lt 0) { $Count = $Bytes.Length - $Offset }
    $sha = [Security.Cryptography.SHA256]::Create()
    try { [Convert]::ToHexString($sha.ComputeHash($Bytes, $Offset, $Count)).ToLowerInvariant() } finally { $sha.Dispose() }
}

function Get-IntegrityDigest([byte[]]$Content, [int]$BlockSize) {
    $blocks = [Collections.Generic.List[string]]::new()
    if ($Content.Length -eq 0) { $blocks.Add((Get-Sha256Hex $Content)) }
    for ($i = 0; $i -lt $Content.Length; $i += $BlockSize) {
        $blocks.Add((Get-Sha256Hex $Content $i ([Math]::Min($BlockSize, $Content.Length - $i))))
    }
    [pscustomobject]@{ Hash = (Get-Sha256Hex $Content); Blocks = $blocks.ToArray() }
}

function Get-T3Version([IO.FileStream]$Stream, $Header) {
    $node = Get-DirEntry $Header.Root | Where-Object Name -eq 'package.json'
    if ($null -eq $node) { return 'unknown' }
    $bytes = Read-ByteRange $Stream ($Header.DataBase + $node.Offset) $node.Size
    ([Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json).version
}

function Measure-Occurrence([string]$Text, [string]$Needle) {
    $count = 0
    $index = $Text.IndexOf($Needle, [StringComparison]::Ordinal)
    while ($index -ge 0) {
        $count++
        $index = $Text.IndexOf($Needle, $index + 1, [StringComparison]::Ordinal)
    }
    $count
}

# Finds where one target's rule lives. Status: unpatched, patched, or missing (T3 changed the code).
function Find-Target([IO.FileStream]$Stream, $Header, $Target) {
    $dir = Get-AsarNode $Header $Target.Dir
    $result = [pscustomobject]@{ Target = $Target; Status = 'missing'; Path = $null; Node = $null; Content = $null; Index = -1; Detail = '' }
    if ($null -eq $dir) { $result.Detail = "folder $($Target.Dir) not found"; return $result }
    $hits = @()
    foreach ($node in (Get-DirEntry $dir)) {
        if (-not $node.Name.EndsWith($Target.Ext)) { continue }
        $content = Read-ByteRange $Stream ($Header.DataBase + $node.Offset) $node.Size
        $text = $Latin1.GetString($content)
        $original = Measure-Occurrence $text $Target.Original
        $patched = Measure-Occurrence $text $Target.Patched
        if ($original + $patched -gt 0) {
            $hits += [pscustomobject]@{ Name = $node.Name; Node = $node; Content = $content; Text = $text; Original = $original; Patched = $patched }
        }
    }
    $totalOriginal = ($hits | Measure-Object -Property Original -Sum).Sum
    $totalPatched = ($hits | Measure-Object -Property Patched -Sum).Sum
    if ($hits.Count -eq 1 -and $totalOriginal + $totalPatched -eq 1) {
        $hit = $hits[0]
        $result.Path = "$($Target.Dir)/$($hit.Name)"
        $result.Node = $hit.Node
        $result.Content = $hit.Content
        if ($totalOriginal -eq 1) {
            $result.Status = 'unpatched'
            $result.Index = $hit.Text.IndexOf($Target.Original, [StringComparison]::Ordinal)
        } else {
            $result.Status = 'patched'
        }
    } elseif ($hits.Count -gt 0) {
        $result.Detail = "rule found $($totalOriginal + $totalPatched) times in $($hits.Count) files; expected exactly once"
    } else {
        $result.Detail = 'rule not found; this T3 build changed the code, so the patch needs updating'
    }
    $result
}

function Get-AsarStamp([string]$Path) {
    $item = Get-Item -LiteralPath $Path
    '{0}|{1}' -f $item.Length, $item.LastWriteTimeUtc.Ticks
}

function Get-State {
    $path = Join-Path $StateDir 'state.json'
    if (Test-Path $path) { Get-Content -Raw $path | ConvertFrom-Json -AsHashtable } else { @{} }
}

function Save-State($State) {
    $null = New-Item -ItemType Directory -Force -Path $StateDir
    $State | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $StateDir 'state.json')
}

function Get-SelectedTarget {
    if ($IncludeServer) { $Targets } else { $Targets | Where-Object Name -eq 'client' }
}

function Invoke-Check {
    $stream = Open-AsarStream $Asar ([IO.FileAccess]::Read)
    try {
        $header = Read-AsarHeader $stream
        $version = Get-T3Version $stream $header
        $found = @($Targets | ForEach-Object { Find-Target $stream $header $_ })
    } finally { $stream.Dispose() }
    if ($Json) {
        [pscustomobject]@{
            version = $version
            asar    = $Asar
            targets = @($found | ForEach-Object { [pscustomobject]@{ name = $_.Target.Name; status = $_.Status; path = $_.Path; detail = $_.Detail } })
        } | ConvertTo-Json -Depth 4 -Compress
        return
    }
    Write-Host "T3 Code $version"
    Write-Host "asar: $Asar"
    foreach ($f in $found) {
        $where = if ($f.Path) { " ($($f.Path))" } else { '' }
        Write-Host ("{0,-7} {1}{2} {3}" -f $f.Target.Name, $f.Status, $where, $f.Detail)
    }
}

function Get-PatchPlan([IO.FileAccess]$Access) {
    $stream = Open-AsarStream $Asar $Access
    try {
        $header = Read-AsarHeader $stream
        $version = Get-T3Version $stream $header
        $found = @(Get-SelectedTarget | ForEach-Object { Find-Target $stream $header $_ })
        [pscustomobject]@{ Stream = $stream; Header = $header; Version = $version; Found = $found }
    } catch {
        $stream.Dispose()
        throw
    }
}

function Invoke-Patch { Invoke-Locked { Invoke-PatchUnlocked } }

function Invoke-PatchUnlocked {
    $plan = Get-PatchPlan ([IO.FileAccess]::Read)
    $plan.Stream.Dispose()
    $version = $plan.Version
    $missing = @($plan.Found | Where-Object Status -eq 'missing')
    foreach ($m in $missing) { Write-PatchLog "T3 $version, $($m.Target.Name): $($m.Detail)" }
    if (@($plan.Found | Where-Object Status -eq 'unpatched').Count -eq 0) {
        if ($missing.Count -eq 0) {
            Write-PatchLog "T3 $version already patched ($(($plan.Found.Target.Name) -join ', '))"
            $state = Get-State
            if ($state.ContainsKey('version') -and $state.version -eq $version) {
                $state.stamp = Get-AsarStamp $Asar
                Save-State $state
            }
        }
        return ($missing.Count -eq 0)
    }

    # One full copy of the unpatched archive per T3 version, as a last-resort fallback. Taken before
    # opening for write, because a copy can't share the file with a writer.
    $null = New-Item -ItemType Directory -Force -Path $StateDir
    $backup = Join-Path $StateDir "server.asar.$version.orig"
    if (-not (Test-Path $backup) -and @($plan.Found | Where-Object Status -eq 'patched').Count -eq 0) {
        Get-ChildItem -Path $StateDir -Filter 'server.asar.*.orig' | Remove-Item -Force
        Copy-Item -LiteralPath $Asar -Destination "$backup.partial" -Force
        Move-Item -LiteralPath "$backup.partial" -Destination $backup -Force
    }

    $plan = Get-PatchPlan ([IO.FileAccess]::ReadWrite)
    $stream = $plan.Stream
    $header = $plan.Header
    try {
        if ($plan.Version -ne $version) { throw 'server.asar changed while patching; try again' }
        $todo = @($plan.Found | Where-Object Status -eq 'unpatched')
        $state = Get-State
        $writes = [Collections.Generic.List[object]]::new()
        if ($state.ContainsKey('version') -and $state.version -eq $version -and $state.ContainsKey('writes')) {
            foreach ($w in $state.writes) { $writes.Add($w) }
        }

        $headerJson = $header.Json
        foreach ($f in $todo) {
            $t = $f.Target
            $patchedBytes = $Latin1.GetBytes($t.Patched)
            $originalBytes = $Latin1.GetBytes($t.Original)
            if ($patchedBytes.Length -ne $originalBytes.Length) { throw "Internal error: $($t.Name) patch changes the length" }
            $newContent = [byte[]]$f.Content.Clone()
            [Array]::Copy($patchedBytes, 0, $newContent, $f.Index, $patchedBytes.Length)

            # Same-length hex digests keep the header's size, so the integrity entries can be swapped in place.
            # A digest shared with another file would be ambiguous; then the old entry stays (Electron only
            # checks it when the exe's EnableEmbeddedAsarIntegrityValidation fuse is on, which T3 leaves off).
            $node = $f.Node
            if ($null -ne $node.Integrity) {
                $old = $node.Integrity
                $new = Get-IntegrityDigest $newContent $old.BlockSize
                $oldDigests = @($old.Hash) + @($old.Blocks)
                $newDigests = @($new.Hash) + @($new.Blocks)
                $expected = @{}
                foreach ($d in $oldDigests) { $expected[$d] = 1 + $(if ($expected.ContainsKey($d)) { $expected[$d] } else { 0 }) }
                $unique = $oldDigests.Count -eq $newDigests.Count
                foreach ($d in $expected.Keys) { if ((Measure-Occurrence $headerJson "`"$d`"") -ne $expected[$d]) { $unique = $false } }
                if ($unique) {
                    for ($i = 0; $i -lt $oldDigests.Count; $i++) {
                        $headerJson = $headerJson.Replace("`"$($oldDigests[$i])`"", "`"$($newDigests[$i])`"")
                    }
                } else {
                    Write-PatchLog "$($t.Name): integrity digest not unique in the header; left unchanged"
                }
            }

            $at = $header.DataBase + $node.Offset + $f.Index
            $writes.Add(@{ offset = $at; original = [Convert]::ToBase64String($originalBytes); patched = [Convert]::ToBase64String($patchedBytes) })
            Write-ByteRange $stream $at $patchedBytes
            Write-PatchLog "T3 $version, $($t.Name): patched $($f.Path) at byte $at"
        }

        $newHeaderBytes = [Text.Encoding]::UTF8.GetBytes($headerJson)
        if ($newHeaderBytes.Length -ne $header.Bytes.Length) { throw 'Internal error: header size changed' }
        # Record each changed run of header bytes (the digests), so -Restore can put them back.
        $i = 0
        while ($i -lt $newHeaderBytes.Length) {
            if ($newHeaderBytes[$i] -eq $header.Bytes[$i]) { $i++; continue }
            $start = $i
            while ($i -lt $newHeaderBytes.Length -and $newHeaderBytes[$i] -ne $header.Bytes[$i]) { $i++ }
            $count = $i - $start
            $writes.Add(@{
                offset   = 16L + $start
                original = [Convert]::ToBase64String($header.Bytes, $start, $count)
                patched  = [Convert]::ToBase64String($newHeaderBytes, $start, $count)
            })
            Write-ByteRange $stream (16L + $start) ([byte[]]$newHeaderBytes[$start..($i - 1)])
        }
        $stream.Flush()
        $stream.Dispose()

        Save-State @{ version = $version; asar = $Asar; stamp = (Get-AsarStamp $Asar); writes = @($writes); patchedAt = (Get-Date).ToString('o') }
        Write-PatchLog "T3 $version patched; restart T3 to load it"
        return ($missing.Count -eq 0)
    } finally { $stream.Dispose() }
}

function Invoke-Restore { Invoke-Locked { Invoke-RestoreUnlocked } }

function Invoke-RestoreUnlocked {
    $state = Get-State
    if (-not $state.ContainsKey('writes') -or $state.writes.Count -eq 0) { Write-PatchLog 'Nothing to restore'; return }
    $stream = Open-AsarStream $Asar ([IO.FileAccess]::ReadWrite)
    try {
        $header = Read-AsarHeader $stream
        $version = Get-T3Version $stream $header
        if ($version -ne $state.version) { throw "Installed T3 is $version, but the record is for $($state.version); nothing restored" }
        foreach ($w in $state.writes) {
            $patched = [Convert]::FromBase64String($w.patched)
            $current = Read-ByteRange $stream ([long]$w.offset) $patched.Length
            if ([Convert]::ToBase64String($current) -ne $w.patched) { throw "Bytes at $($w.offset) are not the patched ones; nothing restored" }
        }
        foreach ($w in $state.writes) { Write-ByteRange $stream ([long]$w.offset) ([Convert]::FromBase64String($w.original)) }
        $stream.Flush()
    } finally { $stream.Dispose() }
    Remove-Item -LiteralPath (Join-Path $StateDir 'state.json') -Force
    Write-PatchLog "T3 $($state.version) restored to the original; restart T3 to load it"
}

function Invoke-Watch {
    Write-PatchLog "Watching $Asar every $IntervalSeconds s"
    $lastStamp = $null
    while ($true) {
        try {
            if (Test-Path -LiteralPath $Asar) {
                $stamp = Get-AsarStamp $Asar
                $state = Get-State
                $known = $state.ContainsKey('stamp') -and $state.stamp -eq $stamp
                if ($stamp -ne $lastStamp -and -not $known) {
                    # Let an installer finish writing before reading the new archive.
                    Start-Sleep -Seconds 5
                    if ((Get-AsarStamp $Asar) -eq $stamp) {
                        $null = Invoke-Patch
                        $lastStamp = Get-AsarStamp $Asar
                    }
                } else {
                    $lastStamp = $stamp
                }
            }
        } catch {
            Write-PatchLog "Watch error: $($_.Exception.Message)"
        }
        Start-Sleep -Seconds $IntervalSeconds
    }
}

# Stop-ScheduledTask ends the task's conhost but not the pwsh under it, so end watcher processes by command line.
function Clear-OrphanWatcher {
    Get-CimInstance Win32_Process -Filter "Name = 'pwsh.exe'" |
        Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -like '*-File*t3-waiting-patch.ps1*-Watch*' } |
        ForEach-Object {
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
            Write-PatchLog "Stopped watcher process $($_.ProcessId)"
        }
}

function Install-WatchTask {
    $pwsh = (Get-Command pwsh.exe).Source
    $arguments = "--headless `"$pwsh`" -NoProfile -NonInteractive -File `"$PSCommandPath`" -Watch"
    if ($IncludeServer) { $arguments += ' -IncludeServer' }
    $action = New-ScheduledTaskAction -Execute (Join-Path $env:SystemRoot 'System32\conhost.exe') -Argument $arguments
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User ([Security.Principal.WindowsIdentity]::GetCurrent().Name)
    # A running watcher would make Start-ScheduledTask a no-op (IgnoreNew), leaving the old script in charge.
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) { Stop-ScheduledTask -TaskName $TaskName }
    Clear-OrphanWatcher
    $settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero) `
        -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    $null = Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings `
        -Description 'Re-applies t3-waiting-patch.ps1 after T3 Code updates.' -Force
    Start-ScheduledTask -TaskName $TaskName
    Write-PatchLog "Installed and started scheduled task '$TaskName'"
}

function Uninstall-WatchTask {
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        Clear-OrphanWatcher
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-PatchLog "Removed scheduled task '$TaskName'"
    } else {
        Write-PatchLog "Scheduled task '$TaskName' not found"
    }
}

if ($InstallTask) { Install-WatchTask }
elseif ($UninstallTask) { Uninstall-WatchTask }
elseif ($Check) { Invoke-Check }
elseif ($Restore) { Invoke-Restore }
elseif ($Watch) { Invoke-Watch }
elseif (-not (Invoke-Patch)) { exit 2 }
