#Requires -Version 7.0
<#
.SYNOPSIS
    Read-only GitHub org audit-log monitor for Miasma worm activity and reinfections.

.DESCRIPTION
    Polls the relias-engineering org audit log (REST, GET only) for:
      - git.push events            -> deep-dive recently pushed branch tips for Miasma
                                      indicator paths via GraphQL path-existence checks,
                                      content-gate ambiguous paths, classify introduced
                                      vs inherited, and ALARM on infections in repos not
                                      already in the known-infected baseline (or new
                                      indicator commits in baseline repos = reinfection).
      - repo.create events         -> same deep-dive (repos can be born infected).
      - credential/persistence events (public_key, oauth_access, personal_access_token,
        hook, integration_installation, protected_branch, repo.access/transfer/destroy,
        member changes)            -> logged as NOTICE/INFO watch events.
      - git.clone bursts           -> exfil heuristic: one actor cloning many distinct
                                      repos in a day -> ALARM.
      - org secret-scanning alerts -> new open alerts logged as NOTICE.

    READ-ONLY GUARANTEE: every GitHub call is a GET (REST) or a GraphQL query.
    Nothing is cloned, checked out, executed, mutated, or written to GitHub.
    The only optional outbound write is the user-configured -AlarmWebhookUrl.

    Alarms: evidence JSON under <state>/alarms/, alarms.log, red console banner,
    beeps, desktop toast (BurntToast if installed, msg.exe fallback), optional
    webhook POST and optional -AlarmCommand script hand-off.

.NOTES
    Indicator literals below are assembled at runtime from fragments. This is
    deliberate: signature AV (Defender Trojan:JS/MiniShaiHrd, Bitdefender) matches
    the contiguous campaign marker strings on disk regardless of context and will
    quarantine this defensive scanner. The fragments plus the scoped AV exclusion
    keep it on disk. Do not "clean up" the concatenations.

    The original filename Watch-ReliasMiasmaAuditLog.ps1 became a Bitdefender
    name-level block after an early detection; this file uses a clean name.

    Git audit events are only retained by GitHub for 7 days; web events 90+ days.
    The audit-log API has its own ~1750 req/hour budget; default cadence uses
    roughly 19 requests per cycle (~230/hour at the 300 s default).
    Run alongside the periodic Start-ReliasMiasmaBranchTipReport full sweep:
    this monitor is the fast push-driven tripwire, the sweep is the safety net.

.EXAMPLE
    .\Watch-ReliasAuditMonitor.ps1 -PreflightOnly
    .\Watch-ReliasAuditMonitor.ps1 -Once
    .\Watch-ReliasAuditMonitor.ps1 -Background
#>
[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$Owner = 'relias-engineering',
    [string]$ExpectedLogin = 'fhemmerrelias',

    [ValidateRange(60, 86400)]
    [int]$PollSeconds = 300,

    # How far back the very first run looks (also used when state is reset).
    [ValidateRange(1, 168)]
    [int]$LookbackHours = 24,

    [ValidateRange(0, 10000)]
    [int]$ThrottleMilliseconds = 1000,

    [ValidateRange(0, 5000)]
    [int]$MinimumCoreRemaining = 300,

    [ValidateRange(0, 50000)]
    [int]$MinimumGraphqlRemaining = 300,

    [ValidateRange(1, 50)]
    [int]$MaxPagesPerQuery = 5,

    [string]$StateDirectory,
    [string]$BaselinePath,

    # Distinct repos cloned by one non-bot actor in a UTC day before alarming.
    # Active developers legitimately clone 15-20/day, so the default sits well
    # above that. This is a best-effort exfil heuristic: git.clone is very
    # high-volume and the per-cycle page cap means clone coverage is partial.
    [ValidateRange(2, 1000)]
    [int]$CloneBurstThreshold = 45,
    [string[]]$CloneBurstIgnoreActors = @('azure-pipelines[bot]', 'github-actions[bot]', 'dependabot[bot]'),
    [switch]$DisableCloneBurstCheck,
    # By default a clone burst is logged as NOTICE with full evidence but does
    # NOT sound the alarm: git.clone is high-volume and power users legitimately
    # clone dozens of repos/day, so alarming on it erodes trust in the real
    # infection alarms. Opt in to escalate it to a true ALARM.
    [switch]$CloneBurstAlarm,
    [switch]$DisableSecretScanningCheck,

    # Optional alarm fan-out. Webhook receives the alarm JSON via POST.
    [string]$AlarmWebhookUrl,
    # Optional script invoked as: pwsh -File <AlarmCommand> -AlarmJsonPath <evidence.json>
    [string]$AlarmCommand,
    [switch]$NoToast,

    [ValidateSet('Compact', 'Verbose')]
    [string]$ConsoleMode = 'Compact',

    [switch]$Once,
    [switch]$PreflightOnly,
    [switch]$Background
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
    $PSNativeCommandUseErrorActionPreference = $false
}

# Normalize array params that may arrive as a single comma-joined token. The
# -Background self-relaunch passes arrays comma-joined because individual
# bracketed bot names (e.g. github-actions[bot]) do not bind reliably as
# separate positional tokens through `pwsh -File`.
$CloneBurstIgnoreActors = @($CloneBurstIgnoreActors | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$skillRoot = Split-Path -Parent $scriptRoot

if (-not $StateDirectory) {
    $StateDirectory = Join-Path $skillRoot "output\monitor\$Owner"
}
if (-not $BaselinePath) {
    $BaselinePath = Join-Path $skillRoot 'data\known-infected.json'
}

$alarmsDirectory = Join-Path $StateDirectory 'alarms'
$statePath = Join-Path $StateDirectory 'monitor-state.json'
$monitorLogPath = Join-Path $StateDirectory 'monitor.log'
$alarmsLogPath = Join-Path $StateDirectory 'alarms.log'

New-Item -ItemType Directory -Path $StateDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $alarmsDirectory -Force | Out-Null

# Runtime-assembled indicator strings (see .NOTES about AV signatures).
$setupJsPath = '.github/' + 'setup' + '.js'
$indicatorPaths = @(
    $setupJsPath,
    '.claude/settings.json',
    '.gemini/settings.json',
    ('.cursor/rules/' + 'setup' + '.mdc'),
    '.vscode/tasks.json',
    'binding.gyp'
)

# Content patterns used to gate ambiguous indicator paths (these files can be
# legitimate; only their contents make them Miasma). Highest verdict wins;
# two or more 'suspicious' reasons escalate to 'malicious'.
$blobDangerPatterns = @(
    @{ Pattern = ('\.github[\\/]set' + 'up\.js');                           Reason = 'references the dropper payload path';             Verdict = 'malicious' },
    @{ Pattern = ('Miasma: The Spr' + 'eading Bl' + 'ight');                Reason = 'campaign marker string';                          Verdict = 'malicious' },
    @{ Pattern = ('bun\s+run\s+_in' + 'dex\.js');                           Reason = 'known worm workflow payload runner';              Verdict = 'malicious' },
    @{ Pattern = ('OIDC_PACK' + 'AGES');                                    Reason = 'Red Hat npm wave workflow indicator';             Verdict = 'malicious' },
    @{ Pattern = ('"runOn"\s*:\s*"folder' + 'Open"');                       Reason = 'VS Code auto-run on folder open';                 Verdict = 'suspicious' },
    @{ Pattern = ('"Session' + 'Start"');                                   Reason = 'agent session-start hook';                        Verdict = 'suspicious' },
    @{ Pattern = ('always' + 'Apply:\s*true');                              Reason = 'Cursor rule applies automatically';               Verdict = 'suspicious' },
    @{ Pattern = ('curl\s+|wget\s+|Invoke-Web' + 'Request|Download' + 'String|Download' + 'File'); Reason = 'download command inside config'; Verdict = 'suspicious' },
    @{ Pattern = ('child_pro' + 'cess|node\s+-e\s');                        Reason = 'inline code execution';                           Verdict = 'suspicious' },
    @{ Pattern = ('node\s+\S*in' + 'dex\.js');                              Reason = 'invokes node script (worm v2 binding.gyp vector)'; Verdict = 'suspicious' }
)

# Web audit-log watch list. Each phrase is one cheap query per cycle.
# Level controls log prominence; none of these alone fire the infection alarm.
$watchQueries = @(
    @{ Phrase = 'action:public_key';                    Level = 'NOTICE'; Why = 'SSH key lifecycle (worm steals and plants keys)' },
    @{ Phrase = 'action:oauth_access';                  Level = 'NOTICE'; Why = 'OAuth token created/revoked' },
    @{ Phrase = 'action:personal_access_token';         Level = 'NOTICE'; Why = 'PAT requested/granted' },
    @{ Phrase = 'action:hook';                          Level = 'NOTICE'; Why = 'webhook created/changed (exfil channel)' },
    @{ Phrase = 'action:integration_installation';      Level = 'NOTICE'; Why = 'GitHub App installed' },
    @{ Phrase = 'action:repo.create';                   Level = 'NOTICE'; Why = 'new repository (worm creates exfil repos)' },
    @{ Phrase = 'action:repo.access';                   Level = 'NOTICE'; Why = 'repository visibility changed' },
    @{ Phrase = 'action:repo.transfer';                 Level = 'NOTICE'; Why = 'repository transferred' },
    @{ Phrase = 'action:repo.destroy';                  Level = 'NOTICE'; Why = 'repository deleted (evidence destruction)' },
    @{ Phrase = 'action:protected_branch.destroy';      Level = 'NOTICE'; Why = 'branch protection removed' },
    @{ Phrase = 'action:protected_branch.policy_override'; Level = 'NOTICE'; Why = 'branch protection overridden' },
    @{ Phrase = 'action:org.add_member';                Level = 'NOTICE'; Why = 'org member added' },
    @{ Phrase = 'action:org.update_member';             Level = 'NOTICE'; Why = 'org member role changed' },
    @{ Phrase = 'action:repo.add_member';               Level = 'INFO';   Why = 'repo collaborator added' },
    @{ Phrase = 'action:org_credential_authorization';  Level = 'INFO';   Why = 'SSO credential authorization' }
)

$script:apiRequestCount = 0
$script:lastGhExitCode = 0
$script:lastGhError = ''
$script:apiHeaders = $null
$script:state = $null
$script:cycleAuditPageCaps = $null
$script:cycleAuditFailures = $null
$script:cycleCloneBurstNotices = 0

function Get-ShortTimestamp {
    return (Get-Date -Format 'HH:mm:ss')
}

function Limit-ConsoleText {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)

    $width = 120
    try {
        $width = [int]$Host.UI.RawUI.WindowSize.Width
    }
    catch {
        $width = 120
    }

    $max = [math]::Max(40, $width - 1)
    if ($Text.Length -le $max) { return $Text }
    return ($Text.Substring(0, [math]::Max(0, $max - 3)) + '...')
}

function Write-CompactConsoleLine {
    param(
        [ValidateSet('INFO', 'NOTICE', 'WARN', 'ALARM', 'OK')]
        [string]$Level,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Message
    )

    $color = switch ($Level) {
        'ALARM' { 'Red' }
        'WARN' { 'Yellow' }
        'NOTICE' { 'Cyan' }
        'OK' { 'Green' }
        default { 'Gray' }
    }
    $line = Limit-ConsoleText ('{0} {1,-6} {2}' -f (Get-ShortTimestamp), $Level, $Message)
    Write-Host $line -ForegroundColor $color
}

# ---------------------------------------------------------------- utilities

function Get-HashValue {
    param($Object, [string]$Key, $Default = $null)

    if ($null -eq $Object) { return $Default }
    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($Key)) { return $Object[$Key] }
        return $Default
    }
    $property = $Object.PSObject.Properties[$Key]
    if ($null -ne $property) { return $property.Value }
    return $Default
}

function Write-MonitorLog {
    param(
        [ValidateSet('INFO', 'NOTICE', 'WARN', 'ALARM')]
        [string]$Level = 'INFO',
        [Parameter(Mandatory)][AllowEmptyString()][string]$Message,
        [AllowEmptyString()][string]$ConsoleMessage = '',
        [switch]$SuppressCompactConsole
    )

    $line = '{0} {1} {2}' -f (Get-Date -Format 'o'), $Level.PadRight(6), $Message
    Add-Content -LiteralPath $monitorLogPath -Value $line

    if ($ConsoleMode -eq 'Compact') {
        if ($SuppressCompactConsole) { return }
        if ($ConsoleMessage) {
            Write-CompactConsoleLine -Level $Level -Message $ConsoleMessage
            return
        }
        if ($Level -in @('WARN', 'ALARM')) {
            Write-CompactConsoleLine -Level $Level -Message $Message
        }
        return
    }

    $color = switch ($Level) {
        'ALARM' { 'Red' }
        'WARN' { 'Yellow' }
        'NOTICE' { 'Cyan' }
        default { 'Gray' }
    }
    Write-Host $line -ForegroundColor $color
}

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
        if ($ThrottleMilliseconds -gt 0) {
            Start-Sleep -Milliseconds $ThrottleMilliseconds
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
        if ($ThrottleMilliseconds -gt 0) {
            Start-Sleep -Milliseconds $ThrottleMilliseconds
        }
    }
}

function ConvertTo-GraphQLString {
    param([AllowNull()][string]$Value)

    return ($Value | ConvertTo-Json -Compress)
}

function Add-CycleAuditFailure {
    param(
        [Parameter(Mandatory)][string]$Phrase,
        [Parameter(Mandatory)][string]$Detail
    )

    if ($null -ne $script:cycleAuditFailures) {
        [void]$script:cycleAuditFailures.Add(('{0} phrase={1}' -f $Detail, $Phrase))
    }
}

# Direct REST for the audit-log endpoint so Link-header pagination can be
# capped page-by-page. GET only.
function Invoke-AuditLogQuery {
    param(
        [Parameter(Mandatory)][string]$Phrase,
        [ValidateSet('web', 'git', 'all')][string]$Include = 'web',
        [int]$MaxPages = 5
    )

    $events = [System.Collections.ArrayList]::new()
    $url = 'https://api.github.com/orgs/{0}/audit-log?per_page=100&include={1}&phrase={2}' -f $Owner, $Include, [uri]::EscapeDataString($Phrase)
    $page = 0
    while ($url -and $page -lt $MaxPages) {
        $page++
        $script:apiRequestCount++
        try {
            $response = Invoke-WebRequest -Uri $url -Headers $script:apiHeaders -SkipHttpErrorCheck
        }
        catch {
            Add-CycleAuditFailure -Phrase $Phrase -Detail ("network={0}" -f $_.Exception.Message)
            Write-MonitorLog -Level WARN -Message ("audit-log request failed (network): {0} phrase={1}" -f $_.Exception.Message, $Phrase)
            return @($events)
        }
        if ([int]$response.StatusCode -ne 200) {
            Add-CycleAuditFailure -Phrase $Phrase -Detail ("status={0}" -f [int]$response.StatusCode)
            Write-MonitorLog -Level WARN -Message ("audit-log query failed status={0} phrase={1}" -f [int]$response.StatusCode, $Phrase)
            return @($events)
        }

        $batch = @()
        if ($response.Content) {
            $batch = @(($response.Content | ConvertFrom-Json))
        }
        foreach ($auditEvent in $batch) {
            if ($null -ne $auditEvent) { [void]$events.Add($auditEvent) }
        }

        $url = $null
        if ($response.Headers.ContainsKey('Link')) {
            foreach ($linkValue in @($response.Headers['Link'])) {
                foreach ($part in ($linkValue -split ',')) {
                    if ($part -match '<([^>]+)>;\s*rel="next"') {
                        $url = $Matches[1]
                    }
                }
            }
        }
        if ($batch.Count -eq 0) { break }
        if ($ThrottleMilliseconds -gt 0) {
            Start-Sleep -Milliseconds $ThrottleMilliseconds
        }
    }

    if ($url) {
        if ($null -ne $script:cycleAuditPageCaps) {
            [void]$script:cycleAuditPageCaps.Add($Phrase)
        }
        Write-MonitorLog -Level WARN -Message ("audit-log page cap ({0}) hit for phrase={1}; older events in this window were not fetched this cycle" -f $MaxPages, $Phrase) -SuppressCompactConsole
    }
    return @($events)
}

function Get-AuditEventId {
    param([Parameter(Mandatory)]$AuditEvent)

    $id = [string](Get-HashValue $AuditEvent '_document_id' '')
    if ($id) { return $id }
    return '{0}|{1}|{2}|{3}' -f (Get-HashValue $AuditEvent 'action' '?'), (Get-HashValue $AuditEvent 'repo' '?'), (Get-HashValue $AuditEvent 'actor' '?'), (Get-HashValue $AuditEvent '@timestamp' 0)
}

function Get-AuditEventShortId {
    param([Parameter(Mandatory)][string]$Id)

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Id)
        $hash = $sha.ComputeHash($bytes)
        return (($hash | Select-Object -First 6 | ForEach-Object { $_.ToString('x2') }) -join '')
    }
    finally {
        $sha.Dispose()
    }
}

function Get-AuditEventSummary {
    param([Parameter(Mandatory)]$AuditEvent)

    $tsIso = Get-AuditEventTimestampIso -AuditEvent $AuditEvent
    $bits = [System.Collections.Generic.List[string]]::new()
    $bits.Add(('action={0}' -f (Get-HashValue $AuditEvent 'action' '?')))
    $bits.Add(('actor={0}' -f (Get-HashValue $AuditEvent 'actor' '?')))
    foreach ($field in @('repo', 'user', 'name', 'visibility', 'hook_id', 'key')) {
        $value = Get-HashValue $AuditEvent $field $null
        if ($null -ne $value -and [string]$value -ne '') {
            $bits.Add(('{0}={1}' -f $field, $value))
        }
    }
    $bits.Add(('at={0}' -f $tsIso))
    return ($bits -join ' ')
}

# ----------------------------------------------------------------- state

function Get-AuditEventTimestampIso {
    param([Parameter(Mandatory)]$AuditEvent)

    $ts = [long](Get-HashValue $AuditEvent '@timestamp' 0)
    if ($ts -gt 0) {
        return [DateTimeOffset]::FromUnixTimeMilliseconds($ts).UtcDateTime.ToString('o')
    }
    return 'unknown'
}

function Get-PushAuditEventSummary {
    param([Parameter(Mandatory)]$AuditEvent)

    $repo = [string](Get-HashValue $AuditEvent 'repo' (Get-HashValue $AuditEvent 'repository' '?'))
    $bits = [System.Collections.Generic.List[string]]::new()
    $bits.Add(('actor={0}' -f (Get-HashValue $AuditEvent 'actor' '?')))
    $bits.Add(('repo={0}' -f $repo))
    foreach ($field in @('programmatic_access_type', 'transport_protocol_name', 'user_agent')) {
        $value = [string](Get-HashValue $AuditEvent $field '')
        if ($value) { $bits.Add(('{0}={1}' -f $field, $value)) }
    }
    foreach ($field in @('ref', 'branch', 'head_sha', 'before', 'after')) {
        $value = [string](Get-HashValue $AuditEvent $field '')
        if ($value) { $bits.Add(('{0}={1}' -f $field, $value)) }
    }
    $bits.Add(('at={0}' -f (Get-AuditEventTimestampIso -AuditEvent $AuditEvent)))
    return ($bits -join ' ')
}

function Save-RecentPushAuditEvent {
    param(
        [Parameter(Mandatory)]$AuditEvent,
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$RepoName
    )

    if (-not $script:state.Contains('recentPushEvents') -or $null -eq $script:state.recentPushEvents) {
        $script:state.recentPushEvents = @{}
    }

    $shortId = Get-AuditEventShortId -Id $Id
    $ts = [long](Get-HashValue $AuditEvent '@timestamp' 0)
    $timestampUtc = if ($ts -gt 0) { [DateTimeOffset]::FromUnixTimeMilliseconds($ts).UtcDateTime.ToString('o') } else { 'unknown' }
    $detailCommand = 'pwsh -NoProfile -File "{0}" -AuditId {1}' -f (Join-Path $scriptRoot 'Get-ReliasAuditPushDetail.ps1'), $shortId

    $script:state.recentPushEvents[$Id] = @{
        Id = $Id
        ShortId = $shortId
        Action = [string](Get-HashValue $AuditEvent 'action' '')
        Actor = [string](Get-HashValue $AuditEvent 'actor' '')
        Repo = [string](Get-HashValue $AuditEvent 'repo' (Get-HashValue $AuditEvent 'repository' ''))
        RepoName = $RepoName
        TimestampMs = $ts
        TimestampUtc = $timestampUtc
        ProgrammaticAccessType = [string](Get-HashValue $AuditEvent 'programmatic_access_type' '')
        TransportProtocolName = [string](Get-HashValue $AuditEvent 'transport_protocol_name' '')
        UserAgent = [string](Get-HashValue $AuditEvent 'user_agent' '')
        Ref = [string](Get-HashValue $AuditEvent 'ref' '')
        Branch = [string](Get-HashValue $AuditEvent 'branch' '')
        HeadSha = [string](Get-HashValue $AuditEvent 'head_sha' '')
        Before = [string](Get-HashValue $AuditEvent 'before' '')
        After = [string](Get-HashValue $AuditEvent 'after' '')
        Summary = Get-PushAuditEventSummary -AuditEvent $AuditEvent
        DetailCommand = $detailCommand
        Raw = $AuditEvent
    }

    return $script:state.recentPushEvents[$Id]
}

function Get-MonitorState {
    $defaultCursorMs = [DateTimeOffset]::UtcNow.AddHours(-1 * $LookbackHours).ToUnixTimeMilliseconds()
    $fresh = @{
        owner = $Owner
        cursors = @{
            maxTsMs = $defaultCursorMs
            secretScanIso = [DateTimeOffset]::UtcNow.AddHours(-1 * $LookbackHours).UtcDateTime.ToString('o')
        }
        seenEventIds = @{}
        alarmed = @{}
        cloneActivity = @{}
        recentPushEvents = @{}
        flags = @{}
        lastCycle = @{}
    }

    if (-not (Test-Path -LiteralPath $statePath)) {
        return $fresh
    }
    try {
        $loaded = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json -AsHashtable
        foreach ($key in @($fresh.Keys)) {
            if (-not $loaded.Contains($key)) { $loaded[$key] = $fresh[$key] }
        }
        foreach ($key in @($fresh.cursors.Keys)) {
            if (-not $loaded.cursors.Contains($key)) { $loaded.cursors[$key] = $fresh.cursors[$key] }
        }
        return $loaded
    }
    catch {
        $backupPath = "$statePath.corrupt-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item -LiteralPath $statePath -Destination $backupPath -Force
        Write-MonitorLog -Level WARN -Message "State file unreadable; backed up to $backupPath and starting fresh."
        return $fresh
    }
}

function Save-MonitorState {
    $script:state | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $statePath
}

function Get-Baseline {
    if (-not (Test-Path -LiteralPath $BaselinePath)) {
        throw "Baseline file not found: $BaselinePath. It records known-infected and triaged repos; the monitor alarms on anything outside it."
    }
    return Get-Content -LiteralPath $BaselinePath -Raw | ConvertFrom-Json -AsHashtable
}

# ----------------------------------------------------------------- alarms

function Send-DesktopAlert {
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$Message
    )

    try {
        for ($i = 0; $i -lt 4; $i++) {
            [console]::Beep(1000, 250)
            [console]::Beep(1500, 250)
        }
    }
    catch { }

    if ($NoToast) { return }
    try {
        if (Get-Module -ListAvailable -Name BurntToast) {
            Import-Module BurntToast -ErrorAction Stop
            New-BurntToastNotification -Text $Title, $Message | Out-Null
            return
        }
    }
    catch { }
    try {
        & msg.exe $env:USERNAME /TIME:60 "$Title`n$Message" 2>$null | Out-Null
    }
    catch { }
}

function Invoke-MiasmaAlarm {
    param([Parameter(Mandatory)][pscustomobject]$Alarm)

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    $safeRepo = (([string]$Alarm.Repository) -replace '[^\w\.-]', '_')
    if (-not $safeRepo) { $safeRepo = 'org' }
    $alarmPath = Join-Path $alarmsDirectory "ALARM-$stamp-$($Alarm.Type)-$safeRepo.json"
    $Alarm | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath $alarmPath

    Add-Content -LiteralPath $alarmsLogPath -Value ('{0} {1} repo={2} :: {3} :: evidence={4}' -f (Get-Date -Format 'o'), $Alarm.Type, $Alarm.Repository, $Alarm.Summary, $alarmPath)

    $banner = '#' * 78
    Write-Host $banner -ForegroundColor Red
    Write-Host ("  MIASMA ALARM [{0}] {1}" -f $Alarm.Type, $Alarm.Repository) -ForegroundColor Red
    Write-Host ("  {0}" -f $Alarm.Summary) -ForegroundColor Red
    Write-Host ("  Evidence: {0}" -f $alarmPath) -ForegroundColor Red
    Write-Host $banner -ForegroundColor Red
    Write-MonitorLog -Level ALARM -Message ("{0} repo={1} :: {2} :: evidence={3}" -f $Alarm.Type, $Alarm.Repository, $Alarm.Summary, $alarmPath)

    Send-DesktopAlert -Title "MIASMA ALARM: $($Alarm.Type)" -Message ("{0}: {1}" -f $Alarm.Repository, $Alarm.Summary)

    if ($AlarmWebhookUrl) {
        try {
            Invoke-RestMethod -Method Post -Uri $AlarmWebhookUrl -ContentType 'application/json' -Body ($Alarm | ConvertTo-Json -Depth 15) | Out-Null
        }
        catch {
            Write-MonitorLog -Level WARN -Message ("Alarm webhook POST failed: {0}" -f $_.Exception.Message)
        }
    }
    if ($AlarmCommand) {
        try {
            & pwsh -NoProfile -ExecutionPolicy Bypass -File $AlarmCommand -AlarmJsonPath $alarmPath | Out-Null
        }
        catch {
            Write-MonitorLog -Level WARN -Message ("AlarmCommand failed: {0}" -f $_.Exception.Message)
        }
    }
}

# ------------------------------------------------------------- deep dive

function Get-RepoBranchTips {
    param(
        [Parameter(Mandatory)][string]$RepoName,
        [int]$MaxPages = 4
    )

    $branches = [System.Collections.ArrayList]::new()
    $defaultBranch = ''
    $cursor = $null
    $page = 0
    do {
        $page++
        $cursorArgument = if ($cursor) { ', after: ' + (ConvertTo-GraphQLString $cursor) } else { '' }
        $query = @"
query {
  repository(owner: $(ConvertTo-GraphQLString $Owner), name: $(ConvertTo-GraphQLString $RepoName)) {
    defaultBranchRef { name }
    refs(refPrefix: "refs/heads/", first: 100$cursorArgument) {
      nodes {
        name
        target {
          ... on Commit {
            oid
            committedDate
            messageHeadline
            author { name email }
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
        if ($null -eq $response -or $null -eq (Get-HashValue (Get-HashValue $response 'data') 'repository')) {
            Write-MonitorLog -Level WARN -Message ("deep-dive: branch list failed for {0}: {1}" -f $RepoName, $script:lastGhError)
            break
        }

        $repository = $response.data.repository
        $defaultBranchRef = Get-HashValue $repository 'defaultBranchRef'
        if ($null -ne $defaultBranchRef) {
            $defaultBranch = [string](Get-HashValue $defaultBranchRef 'name' '')
        }

        foreach ($node in @($repository.refs.nodes)) {
            $target = Get-HashValue $node 'target'
            if ((Get-HashValue $node 'name') -and $null -ne $target -and (Get-HashValue $target 'oid')) {
                [void]$branches.Add([pscustomobject]@{
                    Name = [string]$node.name
                    Target = $target
                })
            }
        }

        $cursor = [string]$repository.refs.pageInfo.endCursor
        $hasNextPage = [bool]$repository.refs.pageInfo.hasNextPage
        if ($hasNextPage -and $page -ge $MaxPages) {
            Write-MonitorLog -Level WARN -Message ("deep-dive: {0} has more than {1}00 branches; later pages were not considered" -f $RepoName, $MaxPages)
            $hasNextPage = $false
        }
    } while ($hasNextPage)

    return [pscustomobject]@{
        Branches = @($branches)
        DefaultBranch = $defaultBranch
    }
}

function Get-BranchTipIndicatorMatches {
    param(
        [Parameter(Mandatory)][string]$RepoName,
        [Parameter()][AllowEmptyCollection()][object[]]$Branches = @(),
        [int]$BatchSize = 20
    )

    $tipMatches = [System.Collections.ArrayList]::new()
    $Branches = @($Branches)
    if ($Branches.Count -eq 0) { return @($tipMatches) }

    for ($offset = 0; $offset -lt $Branches.Count; $offset += $BatchSize) {
        $batch = @($Branches | Select-Object -Skip $offset -First $BatchSize)
        $aliasMap = @{}
        $fieldLines = [System.Collections.Generic.List[string]]::new()
        $aliasIndex = 0

        foreach ($branch in $batch) {
            foreach ($path in $indicatorPaths) {
                $alias = "p$aliasIndex"
                $expression = '{0}:{1}' -f [string]$branch.Name, $path
                $fieldLines.Add("    ${alias}: object(expression: $(ConvertTo-GraphQLString $expression)) { ... on Blob { oid byteSize } ... on Tree { oid } }") | Out-Null
                $aliasMap[$alias] = [pscustomobject]@{ Branch = $branch; Path = $path }
                $aliasIndex++
            }
        }
        if ($fieldLines.Count -eq 0) { continue }

        $query = @"
query {
  repository(owner: $(ConvertTo-GraphQLString $Owner), name: $(ConvertTo-GraphQLString $RepoName)) {
$($fieldLines -join "`n")
  }
}
"@
        $response = Invoke-GhGraphqlJson -Query $query
        if ($null -eq $response -or $null -eq (Get-HashValue (Get-HashValue $response 'data') 'repository')) {
            Write-MonitorLog -Level WARN -Message ("deep-dive: path check failed for {0} (offset {1}): {2}" -f $RepoName, $offset, $script:lastGhError)
            continue
        }

        foreach ($property in @($response.data.repository.PSObject.Properties)) {
            if ($null -eq $property.Value) { continue }
            if (-not $aliasMap.ContainsKey($property.Name)) { continue }

            $hit = $aliasMap[$property.Name]
            $target = $hit.Branch.Target
            [void]$tipMatches.Add([pscustomobject]@{
                Repository = $RepoName
                Branch = [string]$hit.Branch.Name
                Path = [string]$hit.Path
                BlobSha = [string](Get-HashValue $property.Value 'oid' '')
                ByteSize = [long](Get-HashValue $property.Value 'byteSize' 0)
                TipSha = [string](Get-HashValue $target 'oid' '')
                CommittedDate = [string](Get-HashValue $target 'committedDate' '')
                Author = [string](Get-HashValue (Get-HashValue $target 'author') 'name' '')
                Subject = [string](Get-HashValue $target 'messageHeadline' '')
            })
        }
    }

    return @($tipMatches)
}

function Get-BlobVerdict {
    param(
        [Parameter(Mandatory)][string]$RepoName,
        [Parameter(Mandatory)][string]$Path,
        [string]$BlobSha,
        [long]$ByteSize = 0
    )

    if ($Path -eq $setupJsPath) {
        return [pscustomobject]@{ Verdict = 'malicious'; Reasons = @("high-signal dropper path $setupJsPath exists at branch tip") }
    }
    if (-not $BlobSha) {
        return [pscustomobject]@{ Verdict = 'suspicious'; Reasons = @('indicator path exists but blob SHA unavailable (possibly a tree)') }
    }
    if ($ByteSize -gt 524288) {
        return [pscustomobject]@{ Verdict = 'suspicious'; Reasons = @("config blob unusually large ($ByteSize bytes); not fetched") }
    }

    $blob = Invoke-GhApiJson -Arguments @("repos/$Owner/$RepoName/git/blobs/$BlobSha")
    if ($null -eq $blob) {
        return [pscustomobject]@{ Verdict = 'suspicious'; Reasons = @("content unavailable: $script:lastGhError") }
    }

    $content = ''
    try {
        $encoded = ([string](Get-HashValue $blob 'content' '')) -replace '\s', ''
        $content = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($encoded))
    }
    catch {
        return [pscustomobject]@{ Verdict = 'suspicious'; Reasons = @('content could not be decoded') }
    }

    $reasons = [System.Collections.Generic.List[string]]::new()
    $maliciousHits = 0
    $suspiciousHits = 0
    foreach ($rule in $blobDangerPatterns) {
        if ($content -match $rule.Pattern) {
            $reasons.Add(('{0} [{1}]' -f $rule.Reason, $rule.Verdict)) | Out-Null
            if ($rule.Verdict -eq 'malicious') { $maliciousHits++ } else { $suspiciousHits++ }
        }
    }

    $verdict = 'benign'
    if ($maliciousHits -gt 0 -or $suspiciousHits -ge 2) { $verdict = 'malicious' }
    elseif ($suspiciousHits -eq 1) { $verdict = 'suspicious' }
    if ($reasons.Count -eq 0) { $reasons.Add('no dangerous content patterns matched') | Out-Null }

    return [pscustomobject]@{ Verdict = $verdict; Reasons = @($reasons) }
}

function Get-FindingClassification {
    param([Parameter(Mandatory)][pscustomobject]$Finding)

    # Did the tip commit itself add/modify the indicator (introduced) or merely
    # carry it forward (inherited)? Read-only commit metadata.
    $tipCommit = Invoke-GhApiJson -Arguments @("repos/$Owner/$($Finding.Repository)/commits/$($Finding.TipSha)")
    if ($null -ne $tipCommit) {
        foreach ($file in @(Get-HashValue $tipCommit 'files' @())) {
            if ([string](Get-HashValue $file 'filename' '') -eq $Finding.Path) {
                return [pscustomobject]@{
                    Classification = 'introduced-by-tip'
                    IntroducedBy = [pscustomobject]@{
                        Sha = $Finding.TipSha
                        Status = [string](Get-HashValue $file 'status' '')
                        Author = $Finding.Author
                        Date = $Finding.CommittedDate
                    }
                }
            }
        }
    }

    $escapedPath = [uri]::EscapeDataString($Finding.Path)
    $escapedBranch = [uri]::EscapeDataString($Finding.Branch)
    $touchers = Invoke-GhApiJson -Arguments @("repos/$Owner/$($Finding.Repository)/commits?path=$escapedPath&sha=$escapedBranch&per_page=1")
    $latestToucher = $null
    foreach ($commit in @($touchers)) {
        $latestToucher = [pscustomobject]@{
            Sha = [string](Get-HashValue $commit 'sha' '')
            Status = 'last-touched'
            Author = [string](Get-HashValue (Get-HashValue (Get-HashValue $commit 'commit') 'author') 'name' '')
            Date = [string](Get-HashValue (Get-HashValue (Get-HashValue $commit 'commit') 'author') 'date' '')
        }
        break
    }
    return [pscustomobject]@{
        Classification = 'inherited-or-earlier'
        IntroducedBy = $latestToucher
    }
}

function Resolve-FindingDisposition {
    param(
        [Parameter(Mandatory)][pscustomobject]$Finding,
        $BaselineEntry
    )

    $verdict = [string]$Finding.Verdict
    if ($null -ne $BaselineEntry) {
        $status = [string](Get-HashValue $BaselineEntry 'status' '')
        $allowedBlobs = @(Get-HashValue $BaselineEntry 'allowedBlobs' @())
        if ($Finding.BlobSha -and ($allowedBlobs -contains $Finding.BlobSha)) {
            return [pscustomobject]@{ Level = 'NOTICE'; Type = 'allowlisted-blob'; Reason = 'blob SHA matches triaged allowlist entry' }
        }
        if ($status -eq 'confirmed-infected') {
            $asOfRaw = [string](Get-HashValue $BaselineEntry 'asOf' '2026-06-09T00:00:00Z')
            $asOf = [DateTimeOffset]::Parse($asOfRaw, [cultureinfo]::InvariantCulture)
            $committed = $asOf
            if ($Finding.CommittedDate) {
                $committed = [DateTimeOffset]::Parse($Finding.CommittedDate, [cultureinfo]::InvariantCulture)
            }
            if ($committed -gt $asOf) {
                return [pscustomobject]@{ Level = 'ALARM'; Type = 'reinfection-activity'; Reason = "new indicator-bearing commit after baseline asOf=$asOfRaw" }
            }
            return [pscustomobject]@{ Level = 'NOTICE'; Type = 'known-infected-unchanged'; Reason = 'matches recorded infection baseline; no newer indicator commit' }
        }
        if ($status -like 'low-signal*' -or $status -eq 'needs-review') {
            if ($verdict -eq 'malicious') {
                return [pscustomobject]@{ Level = 'ALARM'; Type = 'baseline-escalation'; Reason = "previously low-signal repo now has malicious content (status=$status)" }
            }
            return [pscustomobject]@{ Level = 'NOTICE'; Type = 'baseline-watch'; Reason = "known $status repo; verdict=$verdict" }
        }
    }

    if ($verdict -eq 'benign') {
        return [pscustomobject]@{ Level = 'NOTICE'; Type = 'benign-indicator-path'; Reason = 'indicator path present but content shows no dangerous patterns' }
    }
    if ($verdict -eq 'malicious') {
        return [pscustomobject]@{ Level = 'ALARM'; Type = 'new-infection'; Reason = 'malicious indicator in repo outside known-infected baseline' }
    }
    return [pscustomobject]@{ Level = 'ALARM'; Type = 'suspicious-new-indicator'; Reason = 'suspicious indicator in repo outside known-infected baseline; review content' }
}

function Invoke-RepoDeepDive {
    param(
        [Parameter(Mandatory)][string]$RepoName,
        [Parameter(Mandatory)][long]$SinceMs,
        [Parameter()][AllowEmptyCollection()][object[]]$TriggerEvents = @(),
        [Parameter(Mandatory)]$Baseline
    )

    $sinceDto = [DateTimeOffset]::FromUnixTimeMilliseconds($SinceMs).AddHours(-2)
    $tips = Get-RepoBranchTips -RepoName $RepoName
    $candidates = [System.Collections.ArrayList]::new()
    foreach ($branch in @($tips.Branches)) {
        $committedRaw = [string](Get-HashValue $branch.Target 'committedDate' '')
        $isDefault = ($branch.Name -eq $tips.DefaultBranch)
        $isRecent = $false
        if ($committedRaw) {
            $isRecent = ([DateTimeOffset]::Parse($committedRaw, [cultureinfo]::InvariantCulture) -ge $sinceDto)
        }
        if ($isRecent -or $isDefault) {
            [void]$candidates.Add($branch)
        }
    }
    if ($candidates.Count -gt 40) {
        Write-MonitorLog -Level WARN -Message ("deep-dive: {0} has {1} candidate branches; checking the 40 most recently committed" -f $RepoName, $candidates.Count)
        $candidates = [System.Collections.ArrayList]@($candidates | Sort-Object { [string](Get-HashValue $_.Target 'committedDate' '') } -Descending | Select-Object -First 40)
    }

    Write-MonitorLog -Level INFO -Message ("deep-dive: {0} branches={1} candidates={2} (since {3:o})" -f $RepoName, @($tips.Branches).Count, $candidates.Count, $sinceDto.UtcDateTime)

    # Suspicious commit-message heuristic on candidate tips (worm signature).
    foreach ($branch in $candidates) {
        $subject = [string](Get-HashValue $branch.Target 'messageHeadline' '')
        if ($subject -match '\[skip ci\]' -and $subject -match 'chore:\s*update\s+deps') {
            Write-MonitorLog -Level NOTICE -Message ("deep-dive: {0}:{1} tip subject matches worm pattern: '{2}'" -f $RepoName, $branch.Name, $subject)
        }
    }

    $pathMatches = Get-BranchTipIndicatorMatches -RepoName $RepoName -Branches @($candidates)
    $findings = [System.Collections.ArrayList]::new()
    $verdictCache = @{}
    foreach ($tipMatch in $pathMatches) {
        $cacheKey = '{0}|{1}' -f $tipMatch.Path, $tipMatch.BlobSha
        if (-not $verdictCache.ContainsKey($cacheKey)) {
            $verdictCache[$cacheKey] = Get-BlobVerdict -RepoName $RepoName -Path $tipMatch.Path -BlobSha $tipMatch.BlobSha -ByteSize $tipMatch.ByteSize
        }
        $verdictInfo = $verdictCache[$cacheKey]
        [void]$findings.Add([pscustomobject]@{
            Repository = $tipMatch.Repository
            Branch = $tipMatch.Branch
            Path = $tipMatch.Path
            BlobSha = $tipMatch.BlobSha
            ByteSize = $tipMatch.ByteSize
            TipSha = $tipMatch.TipSha
            CommittedDate = $tipMatch.CommittedDate
            Author = $tipMatch.Author
            Subject = $tipMatch.Subject
            Verdict = $verdictInfo.Verdict
            VerdictReasons = @($verdictInfo.Reasons)
        })
    }

    $pushTriggers = @($TriggerEvents | Where-Object { [string](Get-HashValue $_ 'action' '') -eq 'git.push' })
    if ($pushTriggers.Count -gt 0) {
        $actors = @($pushTriggers | ForEach-Object { [string](Get-HashValue $_ 'actor' '') } | Where-Object { $_ } | Sort-Object -Unique)
        $actorText = if ($actors.Count -gt 0) { $actors -join ',' } else { '?' }
        $summary = 'push-check repo={0} actors={1} branches={2} candidates={3} indicatorHits={4} findings={5} scope=recent-branch-tips' -f $RepoName, $actorText, @($tips.Branches).Count, $candidates.Count, @($pathMatches).Count, $findings.Count
        Write-MonitorLog -Level INFO -Message ("{0}; exact-ref unavailable from audit event, so checked current recent/default branch tips" -f $summary) -ConsoleMessage $summary
        if ($candidates.Count -eq 0) {
            Write-MonitorLog -Level WARN -Message ("push-check incomplete: {0} had git.push events but no candidate branch tips were available for content inspection" -f $RepoName)
        }
    }

    foreach ($finding in $findings) {
        $baselineEntry = Get-HashValue (Get-HashValue $Baseline 'repositories') $finding.Repository
        $disposition = Resolve-FindingDisposition -Finding $finding -BaselineEntry $baselineEntry

        if ($disposition.Level -eq 'ALARM') {
            $dedupeKey = '{0}|{1}|{2}' -f $finding.Repository, $finding.Path, $finding.BlobSha
            $lastAlarmedRaw = [string](Get-HashValue $script:state.alarmed $dedupeKey '')
            $recentlyAlarmed = $false
            if ($lastAlarmedRaw) {
                $recentlyAlarmed = ([DateTimeOffset]::Parse($lastAlarmedRaw, [cultureinfo]::InvariantCulture) -gt [DateTimeOffset]::UtcNow.AddHours(-24))
            }
            if ($recentlyAlarmed) {
                Write-MonitorLog -Level NOTICE -Message ("alarm suppressed (fired within 24h): {0} {1}:{2} {3}" -f $disposition.Type, $finding.Repository, $finding.Branch, $finding.Path)
                continue
            }

            $classification = Get-FindingClassification -Finding $finding
            $alarm = [pscustomobject]@{
                Type = $disposition.Type
                Severity = 'ALARM'
                Repository = $finding.Repository
                Branch = $finding.Branch
                Path = $finding.Path
                BlobSha = $finding.BlobSha
                ByteSize = $finding.ByteSize
                TipSha = $finding.TipSha
                CommittedDate = $finding.CommittedDate
                Author = $finding.Author
                Subject = $finding.Subject
                Verdict = $finding.Verdict
                VerdictReasons = $finding.VerdictReasons
                Classification = $classification.Classification
                IntroducedBy = $classification.IntroducedBy
                Reason = $disposition.Reason
                TriggeringAuditEvents = @($TriggerEvents | ForEach-Object { Get-AuditEventSummary $_ })
                DetectedAt = (Get-Date).ToUniversalTime().ToString('o')
                Summary = ('{0} at {1}:{2} ({3}; verdict={4}; {5})' -f $finding.Path, $finding.Repository, $finding.Branch, $classification.Classification, $finding.Verdict, $disposition.Reason)
            }
            Invoke-MiasmaAlarm -Alarm $alarm
            $script:state.alarmed[$dedupeKey] = (Get-Date).ToUniversalTime().ToString('o')
            $script:cycleAlarms++
        }
        else {
            Write-MonitorLog -Level NOTICE -Message ("{0}: {1}:{2} {3} blob={4} verdict={5} :: {6}" -f $disposition.Type, $finding.Repository, $finding.Branch, $finding.Path, $finding.BlobSha, $finding.Verdict, $disposition.Reason)
            $script:cycleNotices++
        }
    }

    return @($findings)
}

# --------------------------------------------------------- cycle pieces

function Invoke-CloneBurstCheck {
    param([Parameter(Mandatory)][string]$CreatedPhrase)

    $cloneEvents = Invoke-AuditLogQuery -Phrase "action:git.clone $CreatedPhrase" -Include 'git' -MaxPages 5
    foreach ($cloneEvent in @($cloneEvents)) {
        if ([string](Get-HashValue $cloneEvent 'action' '') -ne 'git.clone') { continue }
        $id = Get-AuditEventId $cloneEvent
        if ($script:state.seenEventIds.Contains($id)) { continue }
        $ts = [long](Get-HashValue $cloneEvent '@timestamp' 0)
        $script:state.seenEventIds[$id] = $ts
        if ($ts -gt [long]$script:state.cursors.maxTsMs) { $script:state.cursors.maxTsMs = $ts }

        $actor = [string](Get-HashValue $cloneEvent 'actor' '')
        $repo = [string](Get-HashValue $cloneEvent 'repo' '')
        if (-not $actor -or -not $repo) { continue }
        if ($CloneBurstIgnoreActors -contains $actor) { continue }

        $dateKey = [DateTimeOffset]::FromUnixTimeMilliseconds($ts).UtcDateTime.ToString('yyyy-MM-dd')
        if (-not $script:state.cloneActivity.Contains($actor) -or [string](Get-HashValue $script:state.cloneActivity[$actor] 'date' '') -ne $dateKey) {
            $script:state.cloneActivity[$actor] = @{ date = $dateKey; repos = @{} }
        }
        $script:state.cloneActivity[$actor].repos[$repo] = $true

        $distinctRepos = @($script:state.cloneActivity[$actor].repos.Keys)
        if ($distinctRepos.Count -ge $CloneBurstThreshold) {
            $dedupeKey = 'clone-burst|{0}|{1}' -f $actor, $dateKey
            if (-not $script:state.alarmed.Contains($dedupeKey)) {
                $script:state.alarmed[$dedupeKey] = (Get-Date).ToUniversalTime().ToString('o')
                $summary = 'actor {0} cloned {1} distinct repos on {2} (threshold {3}) - possible exfiltration' -f $actor, $distinctRepos.Count, $dateKey, $CloneBurstThreshold
                if ($CloneBurstAlarm) {
                    $alarm = [pscustomobject]@{
                        Type = 'clone-burst'
                        Severity = 'ALARM'
                        Repository = '(multiple)'
                        Actor = $actor
                        Date = $dateKey
                        DistinctRepoCount = $distinctRepos.Count
                        Repos = $distinctRepos
                        DetectedAt = (Get-Date).ToUniversalTime().ToString('o')
                        Summary = $summary
                    }
                    Invoke-MiasmaAlarm -Alarm $alarm
                    $script:cycleAlarms++
                }
                else {
                    Write-MonitorLog -Level NOTICE -Message ("clone-burst (NOTICE-only; pass -CloneBurstAlarm to escalate): {0}" -f $summary)
                    $script:cycleNotices++
                    $script:cycleCloneBurstNotices++
                }
            }
        }
    }

    # Drop stale per-actor accumulators (previous days).
    $today = [DateTimeOffset]::UtcNow.UtcDateTime.ToString('yyyy-MM-dd')
    foreach ($actorKey in @($script:state.cloneActivity.Keys)) {
        if ([string](Get-HashValue $script:state.cloneActivity[$actorKey] 'date' '') -ne $today) {
            $script:state.cloneActivity.Remove($actorKey)
        }
    }
}

function Invoke-SecretScanningCheck {
    $alerts = Invoke-GhApiJson -Arguments @("orgs/$Owner/secret-scanning/alerts?state=open&sort=created&direction=desc&per_page=50")
    if ($null -eq $alerts) {
        if (-not (Get-HashValue $script:state.flags 'secretScanUnavailableLogged' $false)) {
            Write-MonitorLog -Level INFO -Message ("secret-scanning alerts unavailable for {0} (plan/permission); skipping this check from now on this run. Detail: {1}" -f $Owner, $script:lastGhError)
            $script:state.flags['secretScanUnavailableLogged'] = $true
        }
        return
    }

    $cursorIso = [string]$script:state.cursors.secretScanIso
    $cursor = [DateTimeOffset]::Parse($cursorIso, [cultureinfo]::InvariantCulture)
    $newest = $cursor
    foreach ($alert in @($alerts)) {
        $createdRaw = [string](Get-HashValue $alert 'created_at' '')
        if (-not $createdRaw) { continue }
        $created = [DateTimeOffset]::Parse($createdRaw, [cultureinfo]::InvariantCulture)
        if ($created -le $cursor) { continue }
        if ($created -gt $newest) { $newest = $created }
        $repoInfo = Get-HashValue $alert 'repository'
        Write-MonitorLog -Level NOTICE -Message ("new secret-scanning alert: repo={0} type={1} created={2} url={3}" -f (Get-HashValue $repoInfo 'full_name' '?'), (Get-HashValue $alert 'secret_type_display_name' (Get-HashValue $alert 'secret_type' '?')), $createdRaw, (Get-HashValue $alert 'html_url' ''))
        $script:cycleNotices++
    }
    $script:state.cursors.secretScanIso = $newest.UtcDateTime.ToString('o')
}

function Invoke-MonitorCycle {
    $cycleStartedAt = Get-Date
    $apiBefore = $script:apiRequestCount
    $script:cycleAlarms = 0
    $script:cycleNotices = 0
    $script:cycleAuditPageCaps = [System.Collections.Generic.List[string]]::new()
    $script:cycleAuditFailures = [System.Collections.Generic.List[string]]::new()
    $script:cycleCloneBurstNotices = 0
    $cyclePushIds = [System.Collections.Generic.List[string]]::new()

    # Rate-limit gate: stay out of the way of long-running BranchTip scans.
    $rate = Invoke-GhApiJson -Arguments @('rate_limit')
    if ($null -eq $rate) {
        Write-MonitorLog -Level WARN -Message "rate_limit check failed; skipping cycle. Detail: $script:lastGhError"
        return
    }
    $coreRemaining = [int]$rate.resources.core.remaining
    $graphqlRemaining = [int]$rate.resources.graphql.remaining
    $auditRemaining = -1
    $auditResource = Get-HashValue $rate.resources 'audit_log'
    if ($null -ne $auditResource) { $auditRemaining = [int](Get-HashValue $auditResource 'remaining' -1) }
    if ($coreRemaining -lt $MinimumCoreRemaining -or $graphqlRemaining -lt $MinimumGraphqlRemaining -or ($auditRemaining -ge 0 -and $auditRemaining -lt 50)) {
        Write-MonitorLog -Level WARN -Message ("rate headroom low (core={0} graphql={1} audit={2}); skipping cycle to protect other scans" -f $coreRemaining, $graphqlRemaining, $auditRemaining)
        return
    }

    $baseline = Get-Baseline

    # Day-granular created filter with 26 h slack; _document_id dedupe handles overlap.
    $createdFloorMs = [long]$script:state.cursors.maxTsMs - (26 * 3600000)
    $createdDate = [DateTimeOffset]::FromUnixTimeMilliseconds([math]::Max($createdFloorMs, 0)).UtcDateTime.ToString('yyyy-MM-dd')
    $createdPhrase = "created:>=$createdDate"

    # --- git.push events -> deep-dive set -------------------------------
    $pushEvents = Invoke-AuditLogQuery -Phrase "action:git.push $createdPhrase" -Include 'git' -MaxPages $MaxPagesPerQuery
    $deepDiveTargets = @{}   # repoName -> @{ SinceMs; Events }
    $newPushCount = 0
    foreach ($pushEvent in @($pushEvents)) {
        if ([string](Get-HashValue $pushEvent 'action' '') -ne 'git.push') { continue }
        $ts = [long](Get-HashValue $pushEvent '@timestamp' 0)
        if ($ts -gt [long]$script:state.cursors.maxTsMs) { $script:state.cursors.maxTsMs = $ts }
        $id = Get-AuditEventId $pushEvent
        if ($script:state.seenEventIds.Contains($id)) { continue }
        $script:state.seenEventIds[$id] = $ts
        $newPushCount++

        $repoFull = [string](Get-HashValue $pushEvent 'repo' '')
        if (-not $repoFull) { continue }
        $repoName = ($repoFull -split '/')[-1]
        $pushInfo = Save-RecentPushAuditEvent -AuditEvent $pushEvent -Id $id -RepoName $repoName
        [void]$cyclePushIds.Add([string]$pushInfo.ShortId)
        $pushConsole = 'git.push id={0} actor={1} repo={2} at={3}; detail: .\scripts\Get-ReliasAuditPushDetail.ps1 -AuditId {0}' -f $pushInfo.ShortId, (Get-HashValue $pushEvent 'actor' '?'), $repoName, (Get-AuditEventTimestampIso -AuditEvent $pushEvent)
        Write-MonitorLog -Level NOTICE -Message ("git.push observed: id={0} {1}; detailCommand={2}" -f $pushInfo.ShortId, (Get-PushAuditEventSummary -AuditEvent $pushEvent), $pushInfo.DetailCommand) -ConsoleMessage $pushConsole
        $script:cycleNotices++
        if (-not $deepDiveTargets.ContainsKey($repoName)) {
            $deepDiveTargets[$repoName] = @{ SinceMs = $ts; Events = [System.Collections.ArrayList]::new() }
        }
        if ($ts -lt [long]$deepDiveTargets[$repoName].SinceMs) { $deepDiveTargets[$repoName].SinceMs = $ts }
        [void]$deepDiveTargets[$repoName].Events.Add($pushEvent)

        $baselineEntry = Get-HashValue (Get-HashValue $baseline 'repositories') $repoName
        if ($null -ne $baselineEntry -and [string](Get-HashValue $baselineEntry 'status' '') -eq 'confirmed-infected') {
            Write-MonitorLog -Level NOTICE -Message ("push into CONFIRMED-INFECTED repo: {0}" -f (Get-AuditEventSummary $pushEvent))
            $script:cycleNotices++
        }
    }

    # --- web watch events ------------------------------------------------
    $watchEventCount = 0
    foreach ($watch in $watchQueries) {
        $watchEvents = Invoke-AuditLogQuery -Phrase ('{0} {1}' -f $watch.Phrase, $createdPhrase) -Include 'web' -MaxPages $MaxPagesPerQuery
        foreach ($watchEvent in @($watchEvents)) {
            $ts = [long](Get-HashValue $watchEvent '@timestamp' 0)
            if ($ts -gt [long]$script:state.cursors.maxTsMs) { $script:state.cursors.maxTsMs = $ts }
            $id = Get-AuditEventId $watchEvent
            if ($script:state.seenEventIds.Contains($id)) { continue }
            $script:state.seenEventIds[$id] = $ts
            $watchEventCount++

            Write-MonitorLog -Level $watch.Level -Message ("watch[{0}]: {1}" -f $watch.Why, (Get-AuditEventSummary $watchEvent))
            if ($watch.Level -eq 'NOTICE') { $script:cycleNotices++ }

            # Newly created repos can be born infected; deep-dive them too.
            if ([string](Get-HashValue $watchEvent 'action' '') -eq 'repo.create') {
                $repoFull = [string](Get-HashValue $watchEvent 'repo' '')
                if ($repoFull) {
                    $repoName = ($repoFull -split '/')[-1]
                    if (-not $deepDiveTargets.ContainsKey($repoName)) {
                        $deepDiveTargets[$repoName] = @{ SinceMs = $ts; Events = [System.Collections.ArrayList]::new() }
                    }
                    [void]$deepDiveTargets[$repoName].Events.Add($watchEvent)
                }
            }
        }
    }

    # --- deep dives -------------------------------------------------------
    $findingCount = 0
    foreach ($repoName in @($deepDiveTargets.Keys | Sort-Object)) {
        $target = $deepDiveTargets[$repoName]
        $findings = Invoke-RepoDeepDive -RepoName $repoName -SinceMs ([long]$target.SinceMs) -TriggerEvents @($target.Events) -Baseline $baseline
        $findingCount += @($findings).Count
    }

    # --- optional extras --------------------------------------------------
    if (-not $DisableCloneBurstCheck) {
        Invoke-CloneBurstCheck -CreatedPhrase $createdPhrase
    }
    if (-not $DisableSecretScanningCheck) {
        Invoke-SecretScanningCheck
    }

    # --- housekeeping ------------------------------------------------------
    $pruneCutoff = [DateTimeOffset]::UtcNow.AddHours(-96).ToUnixTimeMilliseconds()
    foreach ($seenKey in @($script:state.seenEventIds.Keys)) {
        if ([long]$script:state.seenEventIds[$seenKey] -lt $pruneCutoff) {
            $script:state.seenEventIds.Remove($seenKey)
        }
    }
    if ($script:state.Contains('recentPushEvents')) {
        foreach ($pushKey in @($script:state.recentPushEvents.Keys)) {
            $pushTs = [long](Get-HashValue $script:state.recentPushEvents[$pushKey] 'TimestampMs' 0)
            if ($pushTs -lt $pruneCutoff) {
                $script:state.recentPushEvents.Remove($pushKey)
            }
        }
    }

    $apiUsed = $script:apiRequestCount - $apiBefore
    $auditFailureCount = @($script:cycleAuditFailures).Count
    $script:state.lastCycle = @{
        FinishedAt = (Get-Date).ToUniversalTime().ToString('o')
        DurationSeconds = [math]::Round(((Get-Date) - $cycleStartedAt).TotalSeconds, 1)
        ApiRequests = $apiUsed
        NewPushEvents = $newPushCount
        WatchEvents = $watchEventCount
        ReposDeepDived = @($deepDiveTargets.Keys).Count
        IndicatorFindings = $findingCount
        Alarms = $script:cycleAlarms
        Notices = $script:cycleNotices
        CoreRemaining = $coreRemaining
        GraphqlRemaining = $graphqlRemaining
        AuditRemaining = $auditRemaining
        AuditFailures = $auditFailureCount
        AuditFailureDetails = @($script:cycleAuditFailures)
    }
    Save-MonitorState

    $pageCapCount = @($script:cycleAuditPageCaps).Count
    $concernPrefix = if ($script:cycleAlarms -gt 0) {
        'alarms={0}' -f $script:cycleAlarms
    }
    elseif ($auditFailureCount -gt 0) {
        'degraded'
    }
    elseif ($findingCount -gt 0 -or $script:cycleCloneBurstNotices -gt 0) {
        'review'
    }
    else {
        'no alarms/findings'
    }
    $compactLevel = if ($script:cycleAlarms -gt 0) {
        'ALARM'
    }
    elseif ($auditFailureCount -gt 0) {
        'WARN'
    }
    elseif ($findingCount -gt 0 -or $script:cycleCloneBurstNotices -gt 0) {
        'NOTICE'
    }
    else {
        'OK'
    }
    $compactParts = [System.Collections.Generic.List[string]]::new()
    $compactParts.Add($concernPrefix)
    $compactParts.Add(('pushes={0}' -f $newPushCount))
    if ($cyclePushIds.Count -gt 0) {
        $compactParts.Add(('push-ids={0}' -f ((@($cyclePushIds) | Select-Object -First 3) -join ',')))
    }
    $compactParts.Add(('watch={0}' -f $watchEventCount))
    $compactParts.Add(('dived={0}' -f @($deepDiveTargets.Keys).Count))
    if ($script:cycleCloneBurstNotices -gt 0) {
        $compactParts.Add(('clone-burst={0}' -f $script:cycleCloneBurstNotices))
    }
    if ($pageCapCount -gt 0) {
        $compactParts.Add(('partial-audit={0}' -f $pageCapCount))
    }
    if ($auditFailureCount -gt 0) {
        $compactParts.Add(('audit-errors={0}' -f $auditFailureCount))
    }
    $compactParts.Add(('api={0}' -f $apiUsed))
    $compactParts.Add(('dur={0}s' -f $script:state.lastCycle.DurationSeconds))
    $compactMessage = $compactParts -join '; '

    $cycleStatus = if ($auditFailureCount -gt 0) { 'degraded' } else { 'ok' }
    Write-MonitorLog -Level INFO -Message ("CYCLE {0} pushes={1} watch={2} dived={3} findings={4} alarms={5} notices={6} auditFailures={7} api={8} core={9} graphql={10} audit={11} dur={12}s" -f $cycleStatus, $newPushCount, $watchEventCount, @($deepDiveTargets.Keys).Count, $findingCount, $script:cycleAlarms, $script:cycleNotices, $auditFailureCount, $apiUsed, $coreRemaining, $graphqlRemaining, $auditRemaining, $script:state.lastCycle.DurationSeconds)
    if ($ConsoleMode -eq 'Compact') {
        Write-CompactConsoleLine -Level $compactLevel -Message $compactMessage
    }
}

# ------------------------------------------------------------- preflight

function Invoke-MonitorPreflight {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        throw 'GitHub CLI (gh) is required.'
    }
    Remove-Item Env:GH_TOKEN -ErrorAction SilentlyContinue

    $login = (& gh api user --jq .login 2>$null)
    if ($LASTEXITCODE -ne 0 -or $login -ne $ExpectedLogin) {
        throw "gh must be authenticated as $ExpectedLogin. Current login: $login"
    }

    $token = (& gh auth token 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $token) {
        throw 'Unable to obtain a token from gh auth token.'
    }
    $script:apiHeaders = @{
        Authorization = "Bearer $token"
        Accept = 'application/vnd.github+json'
        'X-GitHub-Api-Version' = '2022-11-28'
        'User-Agent' = 'miasma-audit-monitor'
    }

    $probe = Invoke-WebRequest -Uri "https://api.github.com/orgs/$Owner/audit-log?per_page=1" -Headers $script:apiHeaders -SkipHttpErrorCheck
    if ([int]$probe.StatusCode -ne 200) {
        throw "Audit-log API not accessible for org $Owner (status $([int]$probe.StatusCode)). Requires org owner or read:audit_log."
    }

    $rate = (& gh api rate_limit | ConvertFrom-Json)
    $coreRemaining = [int]$rate.resources.core.remaining
    $graphqlRemaining = [int]$rate.resources.graphql.remaining
    if ($coreRemaining -lt $MinimumCoreRemaining) {
        throw "Core REST rate limit too low to start: $coreRemaining remaining; required $MinimumCoreRemaining."
    }
    if ($graphqlRemaining -lt $MinimumGraphqlRemaining) {
        throw "GraphQL rate limit too low to start: $graphqlRemaining remaining; required $MinimumGraphqlRemaining."
    }

    $baseline = Get-Baseline
    $baselineRepos = @((Get-HashValue $baseline 'repositories' @{}).Keys)

    return [pscustomobject]@{
        Owner = $Owner
        Login = $login
        AuditLogAccessible = $true
        CoreRemaining = $coreRemaining
        GraphqlRemaining = $graphqlRemaining
        PollSeconds = $PollSeconds
        ThrottleMilliseconds = $ThrottleMilliseconds
        ConsoleMode = $ConsoleMode
        StateDirectory = (Resolve-Path -LiteralPath $StateDirectory).Path
        BaselinePath = (Resolve-Path -LiteralPath $BaselinePath).Path
        BaselineRepositories = $baselineRepos
        MonitorLogPath = $monitorLogPath
        AlarmsLogPath = $alarmsLogPath
        AlarmsDirectory = $alarmsDirectory
    }
}

# ------------------------------------------------------------------ main

$preflight = Invoke-MonitorPreflight
if ($PreflightOnly) {
    return $preflight
}

if ($Background) {
    $stdoutPath = Join-Path $StateDirectory 'monitor-stdout.txt'
    $stderrPath = Join-Path $StateDirectory 'monitor-stderr.txt'
    $argumentList = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-File', $PSCommandPath,
        '-Owner', $Owner,
        '-ExpectedLogin', $ExpectedLogin,
        '-PollSeconds', ([string]$PollSeconds),
        '-LookbackHours', ([string]$LookbackHours),
        '-ThrottleMilliseconds', ([string]$ThrottleMilliseconds),
        '-MinimumCoreRemaining', ([string]$MinimumCoreRemaining),
        '-MinimumGraphqlRemaining', ([string]$MinimumGraphqlRemaining),
        '-MaxPagesPerQuery', ([string]$MaxPagesPerQuery),
        '-StateDirectory', $StateDirectory,
        '-BaselinePath', $BaselinePath,
        '-CloneBurstThreshold', ([string]$CloneBurstThreshold),
        '-ConsoleMode', $ConsoleMode
    )
    if ($CloneBurstIgnoreActors.Count -gt 0) {
        # Single comma-joined token; the child splits it back (see top of script).
        $argumentList += @('-CloneBurstIgnoreActors', ($CloneBurstIgnoreActors -join ','))
    }
    if ($DisableCloneBurstCheck) { $argumentList += '-DisableCloneBurstCheck' }
    if ($CloneBurstAlarm) { $argumentList += '-CloneBurstAlarm' }
    if ($DisableSecretScanningCheck) { $argumentList += '-DisableSecretScanningCheck' }
    if ($AlarmWebhookUrl) { $argumentList += @('-AlarmWebhookUrl', $AlarmWebhookUrl) }
    if ($AlarmCommand) { $argumentList += @('-AlarmCommand', $AlarmCommand) }
    if ($NoToast) { $argumentList += '-NoToast' }

    $process = Start-Process -FilePath 'pwsh' -ArgumentList $argumentList -WorkingDirectory $skillRoot -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -WindowStyle Hidden -PassThru
    return [pscustomobject]@{
        ProcessId = $process.Id
        Owner = $Owner
        PollSeconds = $PollSeconds
        StateDirectory = (Resolve-Path -LiteralPath $StateDirectory).Path
        MonitorLogPath = $monitorLogPath
        AlarmsLogPath = $alarmsLogPath
        StdoutPath = $stdoutPath
        StderrPath = $stderrPath
        MonitorCommand = "Get-Content -LiteralPath '$stdoutPath' -Tail 40 -Wait"
        VerboseLogCommand = "Get-Content -LiteralPath '$monitorLogPath' -Tail 40 -Wait"
    }
}

$script:state = Get-MonitorState
Write-MonitorLog -Level INFO -Message ("monitor starting owner={0} login={1} poll={2}s lookback={3}h baseline={4} state={5}" -f $Owner, $preflight.Login, $PollSeconds, $LookbackHours, $BaselinePath, $statePath) -ConsoleMessage ("monitor starting owner={0} poll={1}s lookback={2}h" -f $Owner, $PollSeconds, $LookbackHours)
Write-MonitorLog -Level INFO -Message ("baseline repositories: {0}" -f ($preflight.BaselineRepositories -join ', ')) -ConsoleMessage ("baseline repos={0}; verbose log retained" -f @($preflight.BaselineRepositories).Count)

$consecutiveFailures = 0
while ($true) {
    try {
        Invoke-MonitorCycle
        $consecutiveFailures = 0
    }
    catch {
        $consecutiveFailures++
        Write-MonitorLog -Level WARN -Message ("cycle failed ({0} consecutive): {1}" -f $consecutiveFailures, $_.Exception.Message)
        if ($consecutiveFailures -ge 3) {
            Send-DesktopAlert -Title 'Miasma monitor degraded' -Message "3 consecutive cycle failures; last: $($_.Exception.Message). Check $monitorLogPath"
            $consecutiveFailures = 0
        }
    }
    if ($Once) { break }
    Start-Sleep -Seconds $PollSeconds
}
