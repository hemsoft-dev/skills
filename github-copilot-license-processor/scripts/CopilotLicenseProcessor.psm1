Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-SlackPlainText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Text
    )

    $plainText = $Text -replace '<mailto:([^|>]+)\|[^>]+>', '$1'
    $plainText = $plainText -replace '<https?://github\.com/([^|/>]+)\|[^>]+>', '$1'
    $plainText = $plainText -replace '<https?://[^|>]+\|([^>]+)>', '$1'
    return $plainText
}

function ConvertFrom-SlackLicenseRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Text,

        [string]$AdminUserGroupId
    )

    $plainText = ConvertTo-SlackPlainText -Text $Text
    $hasLegacyRequestPhrase = $plainText -match '(?i)requesting\s+copilot\s+license'
    $hasPlainAdminMention = $plainText -match '(?i)(?<![\w])@gh(?:[\s-]*admin)(?![\w])'
    $hasConfiguredAdminMention = $false
    if (-not [string]::IsNullOrWhiteSpace($AdminUserGroupId)) {
        $escapedGroupId = [regex]::Escape($AdminUserGroupId)
        $hasConfiguredAdminMention = $Text -match "<!subteam\^$escapedGroupId(?:\|[^>]*)?>"
    }

    if (-not ($hasLegacyRequestPhrase -or $hasPlainAdminMention -or $hasConfiguredAdminMention)) {
        return $null
    }

    $username = $null
    $email = $null

    foreach ($line in ($plainText -split '\r?\n')) {
        if (-not $username -and
            $line -match '(?i)^\s*(?:(?:github\s+)?user\s+name|(?:github\s+)?username)(?:\s*:\s*|\s+)(?<value>.+?)\s*$') {
            $username = $Matches.value.Trim().TrimStart('@')
            if ($username -match '^https?://github\.com/(?<login>[^/?#]+)') {
                $username = $Matches.login
            }
        }

        if (-not $email -and
            $line -match '(?i)^\s*(?:email(?:\s+address)?|mail)(?:\s*:\s*|\s+)(?<value>.+?)\s*$') {
            $candidate = $Matches.value.Trim()
            if ($candidate -match '(?i)(?<address>[a-z0-9.!#$%&''*+/=?^_`{|}~-]+@[a-z0-9.-]+\.[a-z]{2,})') {
                $email = $Matches.address
            }
        }
    }

    [pscustomobject]@{
        IsRequest = $true
        Username  = $username
        Email     = $email
    }
}

function Get-SlackLicenseRequestValidationIssue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Request
    )

    if ([string]::IsNullOrWhiteSpace([string]$Request.Username)) {
        'GitHub username'
    }

    if ([string]::IsNullOrWhiteSpace([string]$Request.Email)) {
        'email address'
    }
}

function ConvertTo-SlackOrganizationOnboardingReply {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Username,

        [Parameter(Mandatory)]
        [string]$Organization
    )

    $displayOrganization = if ($Organization -ieq 'relias-engineering') {
        'Relias-Engineering'
    }
    else {
        $Organization
    }

    $instructions = @"
:one: *Sign in through SSO*
If the GitHub tile is not available in <https://myapps.microsoft.com|myapps>, request access through ITHC.

:two: *Link your GitHub account*
On your first SSO sign-in, log in with the intended GitHub account: ``$Username``.

:three: *Request your license again*
Once you are a member, post a new message in this channel tagging GH Admin with your Username and Email. Do not reply in this thread.
"@

    [pscustomobject]@{
        Text   = "Not a member of $displayOrganization org. See thread for SSO instructions."
        Blocks = @(
            @{
                type = 'section'
                text = @{
                    type = 'mrkdwn'
                    text = ":no_entry_sign: *Not a member of the $displayOrganization org yet*"
                }
            },
            @{
                type = 'divider'
            },
            @{
                type = 'section'
                text = @{
                    type = 'mrkdwn'
                    text = "You'll need to join the *$displayOrganization* GitHub org before we can assign a Copilot license. Here's how:"
                }
            },
            @{
                type = 'section'
                text = @{
                    type = 'mrkdwn'
                    text = $instructions.Trim()
                }
            }
        )
    }
}

function Test-ProcessorBusinessHour {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Schedule,

        [datetime]$Now = (Get-Date)
    )

    $timeZone = [TimeZoneInfo]::FindSystemTimeZoneById($Schedule.TimeZoneId)
    $easternNow = [TimeZoneInfo]::ConvertTime($Now, $timeZone)

    if ($Schedule.WeekdaysOnly -and
        $easternNow.DayOfWeek -in @([DayOfWeek]::Saturday, [DayOfWeek]::Sunday)) {
        return $false
    }

    return $easternNow.Hour -ge $Schedule.StartHour -and
        $easternNow.Hour -lt $Schedule.EndHour
}

function Get-ProcessorConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Configuration file not found: $Path"
    }

    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Get-ProcessorState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (Test-Path -LiteralPath $Path) {
        return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    }

    return [pscustomobject]@{
        Version       = 1
        LastScannedTs = $null
        LastRunAt     = $null
        Pending       = @()
        Completed     = @()
    }
}

function Set-ProcessorState {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [psobject]$State
    )

    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory)) {
        $null = New-Item -ItemType Directory -Path $directory -Force
    }

    if ($PSCmdlet.ShouldProcess($Path, 'Write processor state')) {
        $temporaryPath = "$Path.tmp"
        $State | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $temporaryPath -Encoding utf8
        Move-Item -LiteralPath $temporaryPath -Destination $Path -Force
    }
}

function Get-SlackToken {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SecureTokenPath
    )

    if (-not [string]::IsNullOrWhiteSpace($env:SLACK_TOKEN)) {
        return $env:SLACK_TOKEN
    }

    if (-not (Test-Path -LiteralPath $SecureTokenPath)) {
        throw "Slack token is unavailable. Run Install-CopilotLicenseProcessorTask.ps1 first."
    }

    $secureToken = Import-Clixml -LiteralPath $SecureTokenPath
    if ($secureToken -isnot [Security.SecureString]) {
        throw "Slack token file is invalid: $SecureTokenPath"
    }

    return [Net.NetworkCredential]::new('', $secureToken).Password
}

function Invoke-SlackApi {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Method,

        [Parameter(Mandatory)]
        [string]$Token,

        [ValidateSet('Get', 'Post')]
        [string]$HttpMethod = 'Post',

        [hashtable]$Body = @{}
    )

    $headers = @{
        Authorization = "Bearer $Token"
    }

    if ($HttpMethod -eq 'Get') {
        $query = [System.Web.HttpUtility]::ParseQueryString('')
        foreach ($key in $Body.Keys) {
            $query[$key] = [string]$Body[$key]
        }

        $uri = "https://slack.com/api/$Method"
        if ($query.Count -gt 0) {
            $uri = "$uri`?$($query.ToString())"
        }

        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
    }
    else {
        $headers['Content-Type'] = 'application/json; charset=utf-8'
        $jsonBody = $Body | ConvertTo-Json -Depth 8 -Compress
        $response = Invoke-RestMethod `
            -Uri "https://slack.com/api/$Method" `
            -Headers $headers `
            -Method Post `
            -Body $jsonBody
    }

    if (-not $response.ok) {
        throw "Slack API $Method failed: $($response.error)"
    }

    return $response
}

function Get-SlackChannelMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Token,

        [Parameter(Mandatory)]
        [string]$ChannelId,

        [Parameter(Mandatory)]
        [string]$Oldest
    )

    $messages = [Collections.Generic.List[object]]::new()
    $cursor = ''

    do {
        $body = @{
            channel   = $ChannelId
            oldest    = $Oldest
            inclusive = 'false'
            limit     = '200'
        }
        if ($cursor) {
            $body.cursor = $cursor
        }

        $response = Invoke-SlackApi `
            -Method 'conversations.history' `
            -Token $Token `
            -HttpMethod Get `
            -Body $body

        foreach ($message in @($response.messages)) {
            $messages.Add($message)
        }

        $metadataProperty = $response.PSObject.Properties['response_metadata']
        $nextCursorProperty = if ($metadataProperty) {
            $metadataProperty.Value.PSObject.Properties['next_cursor']
        }
        else {
            $null
        }
        $cursor = if ($nextCursorProperty) {
            [string]$nextCursorProperty.Value
        }
        else {
            ''
        }
    } while ($cursor)

    return @($messages | Sort-Object { [decimal]$_.ts })
}

function Test-GitHubOrgMember {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Organization,

        [Parameter(Mandatory)]
        [string]$Username
    )

    $output = & gh api "/orgs/$Organization/members/$Username" --silent 2>&1
    if ($LASTEXITCODE -eq 0) {
        return $true
    }

    $message = $output | Out-String
    if ($message -match '(?i)404|not found') {
        return $false
    }

    throw "GitHub membership lookup failed for $Username`: $($message.Trim())"
}

function Test-CopilotSeat {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Organization,

        [Parameter(Mandatory)]
        [string]$Username
    )

    $page = 1
    do {
        $json = & gh api "/orgs/$Organization/copilot/billing/seats?per_page=100&page=$page" 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Copilot seat lookup failed: $(($json | Out-String).Trim())"
        }

        $response = ($json | Out-String) | ConvertFrom-Json
        $seats = @($response.seats)
        foreach ($seat in $seats) {
            if ($seat.assignee.login -eq $Username) {
                return $true
            }
        }

        $page++
    } while ($seats.Count -eq 100)

    return $false
}

function Get-CopilotSeatCount {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Organization
    )

    $json = & gh api "/orgs/$Organization/copilot/billing/seats?per_page=1&page=1" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Copilot seat count lookup failed: $(($json | Out-String).Trim())"
    }

    $response = ($json | Out-String) | ConvertFrom-Json
    if (-not $response.PSObject.Properties['total_seats']) {
        throw 'Copilot seat count response did not include total_seats.'
    }

    return [int]$response.total_seats
}

function Add-CopilotSeat {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Organization,

        [Parameter(Mandatory)]
        [string]$Username
    )

    $payload = @{ selected_usernames = @($Username) } | ConvertTo-Json -Compress
    $payloadPath = [IO.Path]::GetTempFileName()
    try {
        Set-Content -LiteralPath $payloadPath -Value $payload -Encoding utf8 -NoNewline
        $output = & gh api `
            "/orgs/$Organization/copilot/billing/selected_users" `
            --method POST `
            --input $payloadPath 2>&1

        if ($LASTEXITCODE -ne 0) {
            throw "Copilot seat assignment failed: $(($output | Out-String).Trim())"
        }

        return ($output | Out-String) | ConvertFrom-Json
    }
    finally {
        Remove-Item -LiteralPath $payloadPath -Force -ErrorAction SilentlyContinue
    }
}

function ConvertTo-SlackReceiptBody {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ChannelId,

        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [Collections.IDictionary]$Details,

        [Parameter(Mandatory)]
        [datetime]$ProcessedAt,

        [Parameter(Mandatory)]
        [string]$ClientMessageKey
    )

    $processedText = $ProcessedAt.ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss 'UTC'")
    $fallbackLines = [Collections.Generic.List[string]]::new()
    $mrkdwnLines = [Collections.Generic.List[string]]::new()
    $fallbackLines.Add("$Title`:")

    foreach ($entry in $Details.GetEnumerator()) {
        $key = [string]$entry.Key
        $value = ([string]$entry.Value -replace '\s+', ' ').Trim()
        if ($value.Length -gt 800) {
            $value = $value.Substring(0, 797) + '...'
        }

        $fallbackLines.Add("- $key`: $value")
        $escapedKey = $key.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;')
        $escapedValue = $value.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;')
        $mrkdwnLines.Add("*$escapedKey*`n$escapedValue")
    }

    $fallbackLines.Add("- Processed: $processedText")
    $fallbackLines.Add('- Automated by: GitHub Copilot License Processor')

    $hash = [Security.Cryptography.SHA256]::HashData(
        [Text.Encoding]::UTF8.GetBytes($ClientMessageKey)
    )
    $guidBytes = [byte[]]$hash[0..15]

    return @{
        channel       = $ChannelId
        client_msg_id = ([Guid]::new($guidBytes)).ToString()
        text          = $fallbackLines -join "`n"
        blocks        = @(
            @{
                type = 'header'
                text = @{
                    type  = 'plain_text'
                    text  = $Title
                    emoji = $true
                }
            }
            @{
                type   = 'section'
                fields = @($mrkdwnLines | ForEach-Object {
                    @{
                        type = 'mrkdwn'
                        text = $_
                    }
                })
            }
            @{
                type     = 'context'
                elements = @(
                    @{
                        type = 'mrkdwn'
                        text = "Processed $processedText | Automated by GitHub Copilot License Processor"
                    }
                )
            }
        )
    }
}

function Send-SlackReceipt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Token,

        [Parameter(Mandatory)]
        [string]$ChannelId,

        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [Collections.IDictionary]$Details,

        [Parameter(Mandatory)]
        [datetime]$ProcessedAt,

        [Parameter(Mandatory)]
        [string]$ClientMessageKey
    )

    $body = ConvertTo-SlackReceiptBody `
        -ChannelId $ChannelId `
        -Title $Title `
        -Details $Details `
        -ProcessedAt $ProcessedAt `
        -ClientMessageKey $ClientMessageKey

    return Invoke-SlackApi -Method 'chat.postMessage' -Token $Token -Body $body
}

function Add-SlackReaction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Token,

        [Parameter(Mandatory)]
        [string]$ChannelId,

        [Parameter(Mandatory)]
        [string]$Timestamp,

        [Parameter(Mandatory)]
        [string]$Name
    )

    try {
        $null = Invoke-SlackApi -Method 'reactions.add' -Token $Token -Body @{
            channel   = $ChannelId
            timestamp = $Timestamp
            name      = $Name
        }
    }
    catch {
        if ($_.Exception.Message -notmatch 'already_reacted') {
            throw
        }
    }
}

function Test-SlackRequestHandled {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Token,

        [Parameter(Mandatory)]
        [string]$ChannelId,

        [Parameter(Mandatory)]
        [string]$Timestamp,

        [Parameter(Mandatory)]
        [string]$SuccessReaction
    )

    $replies = Invoke-SlackApi -Method 'conversations.replies' -Token $Token -HttpMethod Get -Body @{
        channel = $ChannelId
        ts      = $Timestamp
        limit   = '100'
    }

    $rootMessage = @($replies.messages) | Select-Object -First 1
    $reactionProperty = if ($rootMessage) {
        $rootMessage.PSObject.Properties['reactions']
    }
    else {
        $null
    }
    $reactions = if ($reactionProperty) {
        @($reactionProperty.Value)
    }
    else {
        @()
    }
    foreach ($reaction in $reactions) {
        if ($reaction.name -eq $SuccessReaction) {
            return $true
        }
    }

    foreach ($reply in @($replies.messages | Select-Object -Skip 1)) {
        if ([string]$reply.text -match '(?i)^\s*invite sent\.?\s*$') {
            return $true
        }
    }

    return $false
}

function Remove-SlackReaction {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Token,

        [Parameter(Mandatory)]
        [string]$ChannelId,

        [Parameter(Mandatory)]
        [string]$Timestamp,

        [Parameter(Mandatory)]
        [string]$Name
    )

    if ($PSCmdlet.ShouldProcess("$ChannelId/$Timestamp", "Remove Slack reaction $Name")) {
        try {
            $null = Invoke-SlackApi -Method 'reactions.remove' -Token $Token -Body @{
                channel   = $ChannelId
                timestamp = $Timestamp
                name      = $Name
            }
        }
        catch {
            if ($_.Exception.Message -notmatch 'no_reaction') {
                throw
            }
        }
    }
}

function Send-SlackThreadReply {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Token,

        [Parameter(Mandatory)]
        [string]$ChannelId,

        [Parameter(Mandatory)]
        [string]$ThreadTimestamp,

        [Parameter(Mandatory)]
        [string]$Text,

        [object[]]$Blocks
    )

    $auth = Invoke-SlackApi -Method 'auth.test' -Token $Token -HttpMethod Get
    $replies = Invoke-SlackApi -Method 'conversations.replies' -Token $Token -HttpMethod Get -Body @{
        channel = $ChannelId
        ts      = $ThreadTimestamp
        limit   = '100'
    }

    $duplicate = @($replies.messages) | Where-Object {
        $_.user -eq $auth.user_id -and $_.text -eq $Text
    }
    if ($duplicate) {
        return
    }

    $body = @{
        channel   = $ChannelId
        thread_ts = $ThreadTimestamp
        text      = $Text
    }
    if ($null -ne $Blocks -and $Blocks.Count -gt 0) {
        $body.blocks = $Blocks
    }

    $null = Invoke-SlackApi -Method 'chat.postMessage' -Token $Token -Body $body
}

function Write-ProcessorLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$LogDirectory,

        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )

    if (-not (Test-Path -LiteralPath $LogDirectory)) {
        $null = New-Item -ItemType Directory -Path $LogDirectory -Force
    }

    $line = '{0:u} [{1}] {2}' -f (Get-Date), $Level.ToUpperInvariant(), $Message
    Add-Content -LiteralPath (Join-Path $LogDirectory "$(Get-Date -Format 'yyyy-MM-dd').log") -Value $line
    Write-Information $line
}

Export-ModuleMember -Function @(
    'Add-CopilotSeat',
    'Add-SlackReaction',
    'ConvertFrom-SlackLicenseRequest',
    'ConvertTo-SlackOrganizationOnboardingReply',
    'ConvertTo-SlackReceiptBody',
    'Get-CopilotSeatCount',
    'Get-ProcessorConfig',
    'Get-ProcessorState',
    'Get-SlackChannelMessage',
    'Get-SlackLicenseRequestValidationIssue',
    'Get-SlackToken',
    'Remove-SlackReaction',
    'Send-SlackReceipt',
    'Send-SlackThreadReply',
    'Set-ProcessorState',
    'Test-CopilotSeat',
    'Test-GitHubOrgMember',
    'Test-ProcessorBusinessHour',
    'Test-SlackRequestHandled',
    'Write-ProcessorLog'
)
