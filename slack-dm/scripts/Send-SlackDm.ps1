[CmdletBinding()]
param(
    [string]$UserId = 'U2XMZDPJ7',
    [string]$Email,
    [string]$Project,
    [ValidateSet(
        'merged',
        'completed',
        'review',
        'blocked',
        'failed',
        'deployed',
        'tests',
        'maintenance',
        'info'
    )]
    [string]$Category = 'info',
    [string]$Task,
    [string]$Summary,
    [string[]]$Detail = @(),
    [string]$Url,
    [switch]$ConfirmSend,
    [switch]$AuthTest
)

$ErrorActionPreference = 'Stop'
$script:SlackApi = 'https://slack.com/api'
$script:ProjectEmoji = [char]::ConvertFromUtf32(0x1F4E6)
$script:CategoryEmojis = @{
    merged      = [string][char]0x2705
    completed   = [char]::ConvertFromUtf32(0x1F3AF)
    review      = [char]::ConvertFromUtf32(0x1F50D)
    blocked     = [char]::ConvertFromUtf32(0x1F6A7)
    failed      = [char]::ConvertFromUtf32(0x1F6A8)
    deployed    = [char]::ConvertFromUtf32(0x1F680)
    tests       = [char]::ConvertFromUtf32(0x1F9EA)
    maintenance = [char]::ConvertFromUtf32(0x1F6E0) + [string][char]0xFE0F
    info        = [string][char]0x2139 + [string][char]0xFE0F
}

function Disable-InheritedSslKeyLogging {
    if (Test-Path -LiteralPath Env:SSLKEYLOGFILE) {
        Remove-Item -LiteralPath Env:SSLKEYLOGFILE
    }
}

function Get-SlackToken {
    $token = [Environment]::GetEnvironmentVariable('SLACK_TOKEN')
    if ([string]::IsNullOrWhiteSpace($token)) {
        throw 'SLACK_TOKEN is not set'
    }
    if (-not $token.StartsWith('xoxb-')) {
        throw 'SLACK_TOKEN must be a bot token beginning with xoxb-'
    }
    return $token
}

function Invoke-SlackRequest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Method,
        [Parameter(Mandatory = $true)]
        [string]$Token,
        [object]$Payload
    )

    Disable-InheritedSslKeyLogging
    $headers = @{ Authorization = "Bearer $Token" }
    $parameters = @{
        Uri         = "$($script:SlackApi)/$Method"
        Headers     = $headers
        ErrorAction = 'Stop'
    }

    if ($null -eq $Payload) {
        $parameters.Method = 'Get'
    }
    else {
        $body = $Payload | ConvertTo-Json -Depth 20 -Compress
        $parameters.Method = 'Post'
        $parameters.ContentType = 'application/json; charset=utf-8'
        $parameters.Body = [Text.Encoding]::UTF8.GetBytes($body)
    }

    $result = Invoke-RestMethod @parameters
    if (-not $result.ok) {
        $errorName = if ($result.error) { $result.error } else { 'unknown_error' }
        throw "Slack API error from ${Method}: $errorName"
    }
    return $result
}

function ConvertTo-SingleLine {
    param(
        [string]$Value,
        [string]$FieldName,
        [int]$Maximum
    )

    $cleaned = (($Value -split '\s+') | Where-Object { $_ }) -join ' '
    if ([string]::IsNullOrWhiteSpace($cleaned)) {
        throw "$FieldName cannot be empty"
    }
    if ($cleaned.Length -gt $Maximum) {
        throw "$FieldName must be $Maximum characters or fewer"
    }
    return $cleaned
}

function ConvertTo-CleanSummary {
    param([string]$Value)

    $lines = @(
        $Value -split "\r?\n" |
            ForEach-Object { (($_ -split '\s+') | Where-Object { $_ }) -join ' ' } |
            Where-Object { $_ }
    )
    if ($lines.Count -eq 0) {
        throw 'summary cannot be empty'
    }
    if ($lines.Count -gt 2) {
        throw 'summary must contain no more than two non-empty lines'
    }
    $cleaned = $lines -join "`n"
    if ($cleaned.Length -gt 500) {
        throw 'summary must be 500 characters or fewer'
    }
    return $cleaned
}

function ConvertTo-CleanTask {
    param([string]$Value)

    $task = ConvertTo-SingleLine -Value $Value -FieldName 'task' -Maximum 400
    $artifactReference = '(?i)\b(?:PR|pull request|Issue)\s*#?\s*\d+\b'
    $artifactTask = '^(?:PR|Issue) #[1-9]\d* — \S(?:.*\S)? — \S(?:.*\S)?$'
    if ($task -match $artifactReference -and $task -cnotmatch $artifactTask) {
        throw "issue/PR task must use 'PR #<ID> — <exact title> — <result>' or 'Issue #<ID> — <exact title> — <result>'"
    }
    return $task
}

function ConvertTo-DetailRow {
    param([string]$Value)

    $separator = $Value.IndexOf('=')
    if ($separator -lt 1) {
        throw 'detail must use "Area=Result" format'
    }
    $area = ConvertTo-SingleLine -Value $Value.Substring(0, $separator) `
        -FieldName 'detail area' -Maximum 80
    $result = ConvertTo-SingleLine -Value $Value.Substring($separator + 1) `
        -FieldName 'detail result' -Maximum 500
    return [pscustomobject]@{
        Area   = $area
        Result = $result
    }
}

function ConvertTo-SafeUrl {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }
    $uri = $null
    if (-not [Uri]::TryCreate($Value, [UriKind]::Absolute, [ref]$uri)) {
        throw 'url must be an absolute http or https URL'
    }
    if ($uri.Scheme -notin @('http', 'https')) {
        throw 'url must be an absolute http or https URL'
    }
    if ($Value.IndexOfAny([char[]]'<>|') -ge 0) {
        throw 'url contains a character Slack cannot safely format'
    }
    return $Value
}

function ConvertTo-SlackMrkdwn {
    param([string]$Value)

    return $Value.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;')
}

function ConvertTo-SlackMessage {
    param(
        [string]$ChannelId,
        [string]$ProjectName,
        [string]$TaskName,
        [string]$SummaryText,
        [string]$CategoryName,
        [object[]]$DetailRows,
        [string]$PrimaryUrl
    )

    $emoji = $script:CategoryEmojis[$CategoryName]
    $fallbackLines = [Collections.Generic.List[string]]::new()
    $fallbackLines.Add("$emoji $TaskName")
    $fallbackLines.Add("$($script:ProjectEmoji) $ProjectName")
    $fallbackLines.Add($SummaryText)
    if ($DetailRows.Count -gt 0) {
        $detailText = ($DetailRows | ForEach-Object { "$($_.Area): $($_.Result)" }) -join '; '
        $fallbackLines.Add("Details: $detailText")
    }
    if ($PrimaryUrl) {
        $fallbackLines.Add("Link: $PrimaryUrl")
    }

    $safeTask = ConvertTo-SlackMrkdwn -Value $TaskName
    $outcome = "$emoji *$safeTask*"
    if ($PrimaryUrl) {
        $outcome += " $([char]0x00B7) <$PrimaryUrl|Open link>"
    }

    $blocks = [Collections.ArrayList]::new()
    [void]$blocks.Add([ordered]@{
        type = 'section'
        text = [ordered]@{ type = 'mrkdwn'; text = $outcome }
    })
    [void]$blocks.Add([ordered]@{
        type = 'header'
        text = [ordered]@{
            type  = 'plain_text'
            text  = "$($script:ProjectEmoji) $ProjectName"
            emoji = $true
        }
    })
    [void]$blocks.Add([ordered]@{
        type = 'section'
        text = [ordered]@{
            type = 'mrkdwn'
            text = ConvertTo-SlackMrkdwn -Value $SummaryText
        }
    })

    if ($DetailRows.Count -gt 0) {
        [void]$blocks.Add([ordered]@{
            type = 'section'
            text = [ordered]@{
                type = 'mrkdwn'
                text = "$([char]::ConvertFromUtf32(0x1F4CB)) *Details*"
            }
        })

        $rows = [Collections.ArrayList]::new()
        [void]$rows.Add(@(
            [ordered]@{ type = 'raw_text'; text = 'Area' },
            [ordered]@{ type = 'raw_text'; text = 'Result' }
        ))
        foreach ($row in $DetailRows) {
            [void]$rows.Add(@(
                [ordered]@{ type = 'raw_text'; text = $row.Area },
                [ordered]@{ type = 'raw_text'; text = $row.Result }
            ))
        }
        [void]$blocks.Add([ordered]@{
            type            = 'table'
            column_settings = @(
                [ordered]@{ is_wrapped = $true },
                [ordered]@{ is_wrapped = $true }
            )
            rows            = $rows
        })
    }

    return [ordered]@{
        channel       = $ChannelId
        text          = $fallbackLines -join "`n"
        unfurl_links  = $false
        unfurl_media  = $false
        blocks        = $blocks
    }
}

try {
    if ($AuthTest) {
        $token = Get-SlackToken
        $authResult = Invoke-SlackRequest -Method 'auth.test' -Token $token
        [ordered]@{
            ok      = $true
            team    = $authResult.team
            user    = $authResult.user
            user_id = $authResult.user_id
        } | ConvertTo-Json -Depth 5
        exit 0
    }

    if ($Email -and $PSBoundParameters.ContainsKey('UserId')) {
        throw 'use either -UserId or -Email, not both'
    }
    $missing = @()
    if ([string]::IsNullOrWhiteSpace($Project)) { $missing += '-Project' }
    if ([string]::IsNullOrWhiteSpace($Task)) { $missing += '-Task' }
    if ([string]::IsNullOrWhiteSpace($Summary)) { $missing += '-Summary' }
    if ($missing.Count -gt 0) {
        throw "required structured arguments missing: $($missing -join ', ')"
    }

    $cleanProject = ConvertTo-SingleLine -Value $Project -FieldName 'project' -Maximum 140
    $cleanTask = ConvertTo-CleanTask -Value $Task
    $cleanSummary = ConvertTo-CleanSummary -Value $Summary
    $detailRows = @($Detail | ForEach-Object { ConvertTo-DetailRow -Value $_ })
    $safeUrl = ConvertTo-SafeUrl -Value $Url

    if ($ConfirmSend) {
        $token = Get-SlackToken
        if ($Email) {
            $encodedEmail = [Uri]::EscapeDataString($Email)
            $userResult = Invoke-SlackRequest `
                -Method "users.lookupByEmail?email=$encodedEmail" `
                -Token $token
            $resolvedUserId = $userResult.user.id
        }
        else {
            $resolvedUserId = $UserId
        }

        $channelResult = Invoke-SlackRequest `
            -Method 'conversations.open' `
            -Token $token `
            -Payload @{ users = $resolvedUserId }
        $message = ConvertTo-SlackMessage `
            -ChannelId $channelResult.channel.id `
            -ProjectName $cleanProject `
            -TaskName $cleanTask `
            -SummaryText $cleanSummary `
            -CategoryName $Category `
            -DetailRows $detailRows `
            -PrimaryUrl $safeUrl
        $sendResult = Invoke-SlackRequest `
            -Method 'chat.postMessage' `
            -Token $token `
            -Payload $message
        [ordered]@{
            ok      = $true
            channel = $sendResult.channel
            ts      = $sendResult.ts
        } | ConvertTo-Json -Depth 5
        exit 0
    }

    $recipient = if ($Email) {
        "<resolved from $Email when sending>"
    }
    else {
        $UserId
    }
    $preview = ConvertTo-SlackMessage `
        -ChannelId '<DM channel resolved when sending>' `
        -ProjectName $cleanProject `
        -TaskName $cleanTask `
        -SummaryText $cleanSummary `
        -CategoryName $Category `
        -DetailRows $detailRows `
        -PrimaryUrl $safeUrl

    Write-Output 'DRY RUN: no Slack API write was performed.'
    [ordered]@{
        recipient = $recipient
        payload   = $preview
    } | ConvertTo-Json -Depth 20
}
catch {
    Write-Error "ERROR: $($_.Exception.Message)"
    exit 1
}
