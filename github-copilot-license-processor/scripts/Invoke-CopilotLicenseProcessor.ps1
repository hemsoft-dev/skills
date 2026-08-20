<#
.SYNOPSIS
    Polls Slack and processes queued GitHub Copilot license requests.

.PARAMETER ConfigPath
    Path to the processor configuration.

.PARAMETER IgnoreBusinessHours
    Runs outside the configured weekday business-hours window.
#>

[CmdletBinding()]
param(
    [string]$ConfigPath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'config.json'),

    [switch]$IgnoreBusinessHours,

    [switch]$Live,

    [switch]$ConfirmLive
)

$InformationPreference = 'Continue'
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$skillRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path $PSScriptRoot 'CopilotLicenseProcessor.psm1'
$statePath = Join-Path $skillRoot 'state\processor-state.json'
$logDirectory = Join-Path $skillRoot 'logs'
$secureTokenPath = Join-Path $env:LOCALAPPDATA 'HemSoft\GitHubCopilotLicenseProcessor\slack-token.clixml'

Import-Module $modulePath -Force

if ($Live -and -not $ConfirmLive) {
    throw 'One-shot live processing requires -ConfirmLive.'
}

$mutex = [Threading.Mutex]::new($false, 'Local\HemSoftGitHubCopilotLicenseProcessor')
$hasLock = $false

try {
    $hasLock = $mutex.WaitOne(0)
    if (-not $hasLock) {
        Write-ProcessorLog -LogDirectory $logDirectory -Message 'Another processor instance is already running.'
        exit 0
    }

    $config = Get-ProcessorConfig -Path $ConfigPath
    if (-not $IgnoreBusinessHours -and
        -not (Test-ProcessorBusinessHour -Schedule $config.Schedule)) {
        exit 0
    }

    $token = Get-SlackToken -SecureTokenPath $secureTokenPath
    $state = Get-ProcessorState -Path $statePath
    $now = Get-Date

    $oldest = if ($state.LastScannedTs) {
        [string]$state.LastScannedTs
    }
    else {
        [DateTimeOffset]::new($now.AddHours(-[int]$config.InitialLookbackHours)).ToUnixTimeSeconds().ToString()
    }

    $messages = @(Get-SlackChannelMessage `
        -Token $token `
        -ChannelId $config.SlackChannelId `
        -Oldest $oldest)

    $pending = [Collections.Generic.List[object]]::new()
    foreach ($item in @($state.Pending)) {
        $pending.Add($item)
    }

    $completed = [Collections.Generic.List[string]]::new()
    foreach ($timestamp in @($state.Completed)) {
        $completed.Add([string]$timestamp)
    }

    foreach ($message in $messages) {
        if ([decimal]$message.ts -gt [decimal]$oldest) {
            $state.LastScannedTs = [string]$message.ts
        }

        $adminUserGroupId = if ($config.PSObject.Properties['AdminUserGroupId']) {
            [string]$config.AdminUserGroupId
        }
        else {
            ''
        }
        $request = ConvertFrom-SlackLicenseRequest `
            -Text ([string]$message.text) `
            -AdminUserGroupId $adminUserGroupId
        if (-not $request) {
            continue
        }

        $pendingTimestamps = @($pending | ForEach-Object { [string]$_.Ts })
        $known = $completed.Contains([string]$message.ts) -or
            $pendingTimestamps -contains [string]$message.ts
        if ($known) {
            continue
        }

        $pending.Add([pscustomobject]@{
            Ts          = [string]$message.ts
            UserId      = [string]$message.user
            Text        = [string]$message.text
            Username    = $request.Username
            Email       = $request.Email
            FirstSeenAt = $now.ToUniversalTime().ToString('o')
            Attempts    = 0
            LastError   = $null
        })
    }

    $state.Pending = @($pending)
    $state.Completed = @($completed | Select-Object -Last 1000)
    $state.LastRunAt = $now.ToUniversalTime().ToString('o')
    Set-ProcessorState -Path $statePath -State $state

    $isDryRun = -not $Live -and $config.Mode -ne 'Live'
    $effectiveMode = if ($isDryRun) { 'DryRun' } else { 'Live' }
    Write-ProcessorLog `
        -LogDirectory $logDirectory `
        -Message "Mode=$effectiveMode; new messages=$($messages.Count); pending requests=$($pending.Count)."

    $remaining = [Collections.Generic.List[object]]::new()

    foreach ($request in @($pending)) {
        $alreadyHandled = Test-SlackRequestHandled `
            -Token $token `
            -ChannelId $config.SlackChannelId `
            -Timestamp $request.Ts `
            -SuccessReaction $config.SuccessReaction
        if ($alreadyHandled) {
            $completed.Add($request.Ts)
            Write-ProcessorLog `
                -LogDirectory $logDirectory `
                -Message "Skipped request $($request.Ts) because Slack already shows it as handled."
            continue
        }

        $validationIssues = @(Get-SlackLicenseRequestValidationIssue -Request $request)
        if ($validationIssues.Count -gt 0) {
            $missingFields = $validationIssues -join ', '
            if ($isDryRun) {
                Write-ProcessorLog `
                    -LogDirectory $logDirectory `
                    -Level Warning `
                    -Message "Dry-run: request $($request.Ts) needs correction; missing $missingFields."
                $remaining.Add($request)
                continue
            }

            try {
                Add-SlackReaction `
                    -Token $token `
                    -ChannelId $config.SlackChannelId `
                    -Timestamp $request.Ts `
                    -Name $config.ProcessingReaction
                $null = Send-SlackReceipt `
                    -Token $token `
                    -ChannelId $config.ReceiptChannelId `
                    -Title 'GitHub Copilot seat request rejected' `
                    -Details ([ordered]@{
                        User   = if ($request.Username) { $request.Username } else { '(username not parsed)' }
                        Reason = "The request is missing required information: $missingFields."
                    }) `
                    -ProcessedAt (Get-Date) `
                    -ClientMessageKey "rejected:$($request.Ts)"
                Remove-SlackReaction `
                    -Token $token `
                    -ChannelId $config.SlackChannelId `
                    -Timestamp $request.Ts `
                    -Name $config.ProcessingReaction
                Add-SlackReaction `
                    -Token $token `
                    -ChannelId $config.SlackChannelId `
                    -Timestamp $request.Ts `
                    -Name $config.FailureReaction
                Send-SlackThreadReply `
                    -Token $token `
                    -ChannelId $config.SlackChannelId `
                    -ThreadTimestamp $request.Ts `
                    -Text "I could not process this request because it is missing: $missingFields. Please post a new top-level message tagging GH Admin with `Username: your-github-login` and `Email: your-email-address`. Do not reply in this thread."
                $completed.Add($request.Ts)
            }
            catch {
                $request.Attempts = [int]$request.Attempts + 1
                $request.LastError = $_.Exception.Message
                $remaining.Add($request)
                Write-ProcessorLog `
                    -LogDirectory $logDirectory `
                    -Level Error `
                    -Message "Incomplete request $($request.Ts) failed and remains pending: $($_.Exception.Message)"
            }
            continue
        }

        $username = [string]$request.Username
        try {
            $processingStage = 'organization membership lookup'
            Write-ProcessorLog `
                -LogDirectory $logDirectory `
                -Message "Processing request for $username ($($request.Ts)); checking organization membership."
            $isMember = Test-GitHubOrgMember `
                -Organization $config.Organization `
                -Username $username
            Write-ProcessorLog `
                -LogDirectory $logDirectory `
                -Message "Organization membership check completed for $username`: member=$isMember."

            if ($isDryRun) {
                $seatStatus = if ($isMember) {
                    Test-CopilotSeat -Organization $config.Organization -Username $username
                }
                else {
                    $false
                }

                Write-ProcessorLog `
                    -LogDirectory $logDirectory `
                    -Message "Dry-run: $username; org member=$isMember; Copilot seat=$seatStatus; request=$($request.Ts)."
                $remaining.Add($request)
                continue
            }

            Add-SlackReaction `
                -Token $token `
                -ChannelId $config.SlackChannelId `
                -Timestamp $request.Ts `
                -Name $config.ProcessingReaction
            Write-ProcessorLog `
                -LogDirectory $logDirectory `
                -Message "Added processing reaction for $username; checking existing Copilot seat."

            if (-not $isMember) {
                $onboardingReply = ConvertTo-SlackOrganizationOnboardingReply `
                    -Username $username `
                    -Organization $config.Organization
                $processingStage = 'rejection receipt'
                $null = Send-SlackReceipt `
                    -Token $token `
                    -ChannelId $config.ReceiptChannelId `
                    -Title 'GitHub Copilot seat request rejected' `
                    -Details ([ordered]@{
                        User   = $username
                        Reason = "Not a member of $($config.Organization) organization"
                    }) `
                    -ProcessedAt (Get-Date) `
                    -ClientMessageKey "rejected:$($request.Ts)"
                $processingStage = 'request rejection response'
                Remove-SlackReaction `
                    -Token $token `
                    -ChannelId $config.SlackChannelId `
                    -Timestamp $request.Ts `
                    -Name $config.ProcessingReaction
                Add-SlackReaction `
                    -Token $token `
                    -ChannelId $config.SlackChannelId `
                    -Timestamp $request.Ts `
                    -Name $config.FailureReaction
                Send-SlackThreadReply `
                    -Token $token `
                    -ChannelId $config.SlackChannelId `
                    -ThreadTimestamp $request.Ts `
                    -Text $onboardingReply.Text `
                    -Blocks $onboardingReply.Blocks
                $completed.Add($request.Ts)
                continue
            }

            $processingStage = 'Copilot seat lookup'
            $alreadyAssigned = Test-CopilotSeat `
                -Organization $config.Organization `
                -Username $username
            Write-ProcessorLog `
                -LogDirectory $logDirectory `
                -Message "Copilot seat check completed for $username`: assigned=$alreadyAssigned."

            if (-not $alreadyAssigned) {
                $processingStage = 'Copilot seat assignment'
                Write-ProcessorLog `
                    -LogDirectory $logDirectory `
                    -Message "Assigning Copilot seat to $username."
                $null = Add-CopilotSeat `
                    -Organization $config.Organization `
                    -Username $username
                Write-ProcessorLog `
                    -LogDirectory $logDirectory `
                    -Message "Copilot seat assignment completed for $username."
            }

            $processingStage = 'Copilot seat count lookup'
            $totalSeats = Get-CopilotSeatCount -Organization $config.Organization
            $receiptTitle = if ($alreadyAssigned) {
                'GitHub Copilot seat already assigned'
            }
            else {
                'GitHub Copilot seat added'
            }
            $receiptResult = if ($alreadyAssigned) { 'Already assigned' } else { 'Added' }
            $processingStage = 'success receipt'
            $null = Send-SlackReceipt `
                -Token $token `
                -ChannelId $config.ReceiptChannelId `
                -Title $receiptTitle `
                -Details ([ordered]@{
                    User             = $username
                    Org              = $config.Organization
                    Result           = $receiptResult
                    'Total licenses' = $totalSeats
                }) `
                -ProcessedAt (Get-Date) `
                -ClientMessageKey "success:$($request.Ts)"
            Write-ProcessorLog `
                -LogDirectory $logDirectory `
                -Message "Posted automation receipt for $username; total Copilot licenses=$totalSeats."

            $processingStage = 'request completion response'
            Write-ProcessorLog `
                -LogDirectory $logDirectory `
                -Message "Updating Slack completion reactions for $username."
            Remove-SlackReaction `
                -Token $token `
                -ChannelId $config.SlackChannelId `
                -Timestamp $request.Ts `
                -Name $config.ProcessingReaction
            Add-SlackReaction `
                -Token $token `
                -ChannelId $config.SlackChannelId `
                -Timestamp $request.Ts `
                -Name $config.SuccessReaction
            Send-SlackThreadReply `
                -Token $token `
                -ChannelId $config.SlackChannelId `
                -ThreadTimestamp $request.Ts `
                -Text $config.SuccessReply
            Write-ProcessorLog `
                -LogDirectory $logDirectory `
                -Message "Posted Slack completion reply for $username."

            $completed.Add($request.Ts)
            Write-ProcessorLog `
                -LogDirectory $logDirectory `
                -Message "Completed Copilot request for $username ($($request.Ts))."
        }
        catch {
            $failureMessage = $_.Exception.Message
            $request.Attempts = [int]$request.Attempts + 1
            $request.LastError = $failureMessage
            $remaining.Add($request)
            if ($request.Attempts -eq 1) {
                try {
                    $null = Send-SlackReceipt `
                        -Token $token `
                        -ChannelId $config.ReceiptChannelId `
                        -Title 'GitHub Copilot seat request failed' `
                        -Details ([ordered]@{
                            User   = $username
                            Stage  = $processingStage
                            Reason = $failureMessage
                        }) `
                        -ProcessedAt (Get-Date) `
                        -ClientMessageKey "failure:$($request.Ts):$($request.Attempts)"
                }
                catch {
                    Write-ProcessorLog `
                        -LogDirectory $logDirectory `
                        -Level Error `
                        -Message "Failed to post automation failure receipt for $username`: $($_.Exception.Message)"
                }
            }
            Write-ProcessorLog `
                -LogDirectory $logDirectory `
                -Level Error `
                -Message "Request for $username failed and remains pending: $failureMessage"
        }
    }

    $state.Pending = @($remaining)
    $state.Completed = @($completed | Select-Object -Last 1000)
    $state.LastRunAt = (Get-Date).ToUniversalTime().ToString('o')
    Set-ProcessorState -Path $statePath -State $state
}
finally {
    if ($hasLock) {
        $mutex.ReleaseMutex()
    }

    $mutex.Dispose()
}
