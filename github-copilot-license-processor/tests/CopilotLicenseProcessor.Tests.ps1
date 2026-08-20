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

    It 'treats a GH Admin user-group request with required fields as a Copilot request' {
        $request = ConvertFrom-SlackLicenseRequest `
            -AdminUserGroupId 'S081GPRJ9PB' `
            -Text @'
<!subteam^S081GPRJ9PB> requesting access for relias-engineering
Username: lenient-user
Email: lenient.user@relias.com
'@

        $request.IsRequest | Should -BeTrue
        $request.Username | Should -Be 'lenient-user'
        $request.Email | Should -Be 'lenient.user@relias.com'
    }

    It 'accepts a plain GH Admin mention without fixed request wording' {
        $request = ConvertFrom-SlackLicenseRequest -Text @'
@gh admin please help with this request
Username: plain-mention-user
Email: plain.mention@relias.com
'@

        $request.IsRequest | Should -BeTrue
        $request.Username | Should -Be 'plain-mention-user'
        $request.Email | Should -Be 'plain.mention@relias.com'
    }

    It 'does not treat a different Slack user group as a Copilot request' {
        ConvertFrom-SlackLicenseRequest `
            -AdminUserGroupId 'S081GPRJ9PB' `
            -Text @'
<!subteam^S000OTHER> requesting access
Username: unrelated-user
Email: unrelated.user@relias.com
'@ |
            Should -BeNullOrEmpty
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

    It 'reports every missing required request field' {
        $request = ConvertFrom-SlackLicenseRequest -Text @'
@gh admin
Username:
Email:
'@

        $issues = @(Get-SlackLicenseRequestValidationIssue -Request $request)

        $issues | Should -Contain 'GitHub username'
        $issues | Should -Contain 'email address'
    }
}

Describe 'ConvertTo-SlackOrganizationOnboardingReply' {
    It 'reproduces the approved SSO onboarding response as Block Kit' {
        $reply = ConvertTo-SlackOrganizationOnboardingReply `
            -Username 'octocat-relias' `
            -Organization 'relias-engineering'

        $reply.Text | Should -Be 'Not a member of Relias-Engineering org. See thread for SSO instructions.'
        $reply.Blocks.Count | Should -Be 4
        $reply.Blocks[0].text.text | Should -Match 'Not a member'
        $reply.Blocks[3].text.text | Should -Match 'myapps\.microsoft\.com'
        $reply.Blocks[3].text.text | Should -Match 'octocat-relias'
        $reply.Blocks[3].text.text | Should -Match 'new message'
    }
}

Describe 'Send-SlackThreadReply' {
    BeforeEach {
        Mock -ModuleName CopilotLicenseProcessor Invoke-SlackApi {
            if ($Method -eq 'auth.test') {
                return [pscustomobject]@{ ok = $true; user_id = 'U-BOT' }
            }

            if ($Method -eq 'conversations.replies') {
                return [pscustomobject]@{ ok = $true; messages = @() }
            }

            return [pscustomobject]@{ ok = $true }
        }
    }

    It 'keeps existing plain-text replies backward compatible' {
        Send-SlackThreadReply `
            -Token 'test-token' `
            -ChannelId 'C123' `
            -ThreadTimestamp '123.456' `
            -Text 'Invite sent'

        Should -Invoke -ModuleName CopilotLicenseProcessor Invoke-SlackApi -Times 1 -ParameterFilter {
            $Method -eq 'chat.postMessage' -and -not $Body.ContainsKey('blocks')
        }
    }

    It 'includes Block Kit data when supplied' {
        $blocks = @(@{
            type = 'section'
            text = @{ type = 'mrkdwn'; text = 'Structured reply' }
        })

        Send-SlackThreadReply `
            -Token 'test-token' `
            -ChannelId 'C123' `
            -ThreadTimestamp '123.456' `
            -Text 'Fallback' `
            -Blocks $blocks

        Should -Invoke -ModuleName CopilotLicenseProcessor Invoke-SlackApi -Times 1 -ParameterFilter {
            $Method -eq 'chat.postMessage' -and $Body.blocks.Count -eq 1
        }
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
