<#
.SYNOPSIS
    Stores the Slack token securely and registers the Windows scheduled task.
#>

[CmdletBinding()]
param(
    [string]$TaskName = 'GitHub Copilot License Processor',

    [string]$TaskPath = '\HemSoft\'
)

$InformationPreference = 'Continue'
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$skillRoot = Split-Path -Parent $PSScriptRoot
$processorScript = Join-Path $PSScriptRoot 'Invoke-CopilotLicenseProcessor.ps1'
$hiddenLauncher = Join-Path $PSScriptRoot 'Run-CopilotLicenseProcessorHidden.vbs'
$configPath = Join-Path $skillRoot 'config.json'
$secretDirectory = Join-Path $env:LOCALAPPDATA 'HemSoft\GitHubCopilotLicenseProcessor'
$secureTokenPath = Join-Path $secretDirectory 'slack-token.clixml'

if (-not (Test-Path -LiteralPath $secretDirectory)) {
    $null = New-Item -ItemType Directory -Path $secretDirectory -Force
}

if (-not [string]::IsNullOrWhiteSpace($env:SLACK_TOKEN)) {
    $secureToken = [Security.SecureString]::new()
    foreach ($character in $env:SLACK_TOKEN.ToCharArray()) {
        $secureToken.AppendChar($character)
    }
    $secureToken.MakeReadOnly()
    $secureToken | Export-Clixml -LiteralPath $secureTokenPath
}
elseif (-not (Test-Path -LiteralPath $secureTokenPath)) {
    throw 'SLACK_TOKEN is unavailable and no encrypted token file exists.'
}

$powerShellPath = (Get-Command pwsh -ErrorAction Stop).Source
$wscriptPath = Join-Path $env:SystemRoot 'System32\wscript.exe'
$arguments = @(
    '//B'
    '//Nologo'
    "`"$hiddenLauncher`""
    "`"$powerShellPath`""
    "`"$processorScript`""
    "`"$configPath`""
) -join ' '

$action = New-ScheduledTaskAction `
    -Execute $wscriptPath `
    -Argument $arguments `
    -WorkingDirectory $skillRoot

$trigger = New-ScheduledTaskTrigger -Daily -At '8:00 AM'
$trigger.Repetition = New-CimInstance `
    -Namespace 'Root/Microsoft/Windows/TaskScheduler' `
    -ClassName 'MSFT_TaskRepetitionPattern' `
    -ClientOnly `
    -Property @{
        Interval          = 'PT5M'
        Duration          = 'PT10H5M'
        StopAtDurationEnd = $false
    }

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -Hidden `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 4)

$userId = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$principal = New-ScheduledTaskPrincipal `
    -UserId $userId `
    -LogonType Interactive `
    -RunLevel Limited

$null = Register-ScheduledTask `
    -TaskName $TaskName `
    -TaskPath $TaskPath `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Description 'Polls Slack for GitHub Copilot license requests every five minutes during weekday business hours.' `
    -Force

$mode = (Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json).Mode
Write-Information "Registered $TaskPath$TaskName in $mode mode with a hidden launcher."
