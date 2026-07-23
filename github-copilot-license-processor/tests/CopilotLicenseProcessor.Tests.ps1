BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..\scripts\CopilotLicenseProcessor.psm1'
    Import-Module $modulePath -Force
}

Describe 'ConvertFrom-SlackLicenseRequest' {
    It 'parses the standard request format' {
        $request = ConvertFrom-SlackLicenseRequest -Text @'
Requesting copilot license
Username: octocat-relias
Email: <mailto:octocat@relias.com|octocat@relias.com>
'@

        $request.Username | Should -Be 'octocat-relias'
        $request.Email | Should -Be 'octocat@relias.com'
    }

    It 'parses flexible user name and mail labels' {
        $request = ConvertFrom-SlackLicenseRequest -Text @'
Hello @ghadmin, requesting Copilot license.
GitHub User name : @flex-user
Mail : flex.user@relias.com
'@

        $request.Username | Should -Be 'flex-user'
        $request.Email | Should -Be 'flex.user@relias.com'
    }

    It 'extracts a linked GitHub username' {
        $request = ConvertFrom-SlackLicenseRequest -Text @'
Requesting copilot license
Username: <https://github.com/linked-user|linked-user>
Email: linked@relias.com
'@

        $request.Username | Should -Be 'linked-user'
    }

    It 'returns null for unrelated Slack messages' {
        ConvertFrom-SlackLicenseRequest -Text 'Please review this pull request.' |
            Should -BeNullOrEmpty
    }

    It 'keeps a request with a missing username for manual review' {
        $request = ConvertFrom-SlackLicenseRequest -Text @'
Requesting copilot license
Email: missing.user@relias.com
'@

        $request.IsRequest | Should -BeTrue
        $request.Username | Should -BeNullOrEmpty
    }
}

Describe 'Test-ProcessorBusinessHour' {
    BeforeAll {
        $script:schedule = [pscustomobject]@{
            TimeZoneId  = 'Eastern Standard Time'
            WeekdaysOnly = $true
            StartHour   = 8
            EndHour     = 18
        }
    }

    Describe 'ConvertTo-SlackReceiptBody' {
        It 'builds an idempotent Block Kit receipt' {
            $body = ConvertTo-SlackReceiptBody `
                -ChannelId 'C123' `
                -Title 'GitHub Copilot seat added' `
                -Details ([ordered]@{
                    User             = 'octocat-relias'
                    Org              = 'relias-engineering'
                    'Total licenses' = 311
                }) `
                -ProcessedAt ([datetime]'2026-07-23T18:45:00Z') `
                -ClientMessageKey 'success:123'

            $body.channel | Should -Be 'C123'
            $body.text | Should -Match 'Total licenses: 311'
            $body.blocks[0].type | Should -Be 'header'
            $body.client_msg_id | Should -Match '^[0-9a-f-]{36}$'
        }
    }

    Describe 'Add-CopilotSeat' {
        It 'does not leave GitHub CLI waiting for standard input' {
            $moduleContent = Get-Content -LiteralPath $modulePath -Raw

            $moduleContent | Should -Not -Match '--input\s+-'
        }
    }

    Describe 'Scheduled task launcher' {
        It 'uses a windowless host' {
            $installerPath = Join-Path $PSScriptRoot '..\scripts\Install-CopilotLicenseProcessorTask.ps1'
            $installerContent = Get-Content -LiteralPath $installerPath -Raw

            $installerContent | Should -Match 'wscript\.exe'
        }
    }

    It 'allows a weekday during business hours' {
        Test-ProcessorBusinessHour `
            -Schedule $script:schedule `
            -Now ([datetime]'2026-07-23T12:00:00-04:00') |
            Should -BeTrue
    }

    It 'rejects a weekday after business hours' {
        Test-ProcessorBusinessHour `
            -Schedule $script:schedule `
            -Now ([datetime]'2026-07-23T19:00:00-04:00') |
            Should -BeFalse
    }

    It 'rejects a weekend' {
        Test-ProcessorBusinessHour `
            -Schedule $script:schedule `
            -Now ([datetime]'2026-07-25T12:00:00-04:00') |
            Should -BeFalse
    }
}
