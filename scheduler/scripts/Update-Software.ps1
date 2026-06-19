<#
.SYNOPSIS
    Updates configured local software products.
.DESCRIPTION
    Runs each product update independently, logs every product result, and
    continues through the full list even when one product fails.
.EXAMPLE
    .\Update-Software.ps1
.EXAMPLE
    .\Update-Software.ps1 -ListProducts
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string[]]$ProductName = @(),

    [string]$LogDirectory = (Join-Path -Path $PSScriptRoot -ChildPath '..\logs\software-updates'),

    [switch]$ListProducts
)

$InformationPreference = 'Continue'
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-SoftwareProductDefinition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Command,

        [string[]]$Arguments = @(),

        [string]$WorkingDirectory = 'D:\',

        [int]$TimeoutMinutes = 30,

        [bool]$Enabled = $true
    )

    [PSCustomObject]@{
        Name             = $Name
        Command          = $Command
        Arguments        = $Arguments
        WorkingDirectory = $WorkingDirectory
        TimeoutMinutes   = $TimeoutMinutes
        Enabled          = $Enabled
    }
}

function ConvertTo-CommandLineArgument {
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string]$Argument
    )

    if ($Argument -eq '') {
        return '""'
    }

    if ($Argument -notmatch '[\s"]') {
        return $Argument
    }

    $escaped = $Argument.Replace('\', '\\').Replace('"', '\"')
    return '"' + $escaped + '"'
}

function Format-CommandDisplay {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Product
    )

    $argumentDisplay = ($Product.Arguments | ForEach-Object { ConvertTo-CommandLineArgument -Argument $_ }) -join ' '

    if ([string]::IsNullOrWhiteSpace($argumentDisplay)) {
        return $Product.Command
    }

    return "$($Product.Command) $argumentDisplay"
}

function Write-SoftwareUpdateLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR', 'OUTPUT')]
        [string]$Level = 'INFO'
    )

    $line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Add-Content -LiteralPath $script:LogPath -Value $line
    Write-Information $line
}

function Write-ProcessOutput {
    [CmdletBinding()]
    param(
        [string]$Label,

        [AllowEmptyString()]
        [string]$Output
    )

    if ([string]::IsNullOrWhiteSpace($Output)) {
        return
    }

    Write-SoftwareUpdateLog -Level 'OUTPUT' -Message "${Label}:"

    foreach ($line in ($Output -split '\r?\n')) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        Write-SoftwareUpdateLog -Level 'OUTPUT' -Message "  $line"
    }
}

function Resolve-ProductSelection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$Products,

        [string[]]$RequestedNames = @()
    )

    $enabledProducts = @($Products | Where-Object { $_.Enabled })

    if ($RequestedNames.Count -eq 0) {
        return $enabledProducts
    }

    $missingProducts = foreach ($requestedName in $RequestedNames) {
        if (-not ($enabledProducts | Where-Object { $_.Name -eq $requestedName })) {
            $requestedName
        }
    }

    if ($missingProducts) {
        throw "Unknown or disabled product(s): $($missingProducts -join ', ')"
    }

    return @($enabledProducts | Where-Object { $RequestedNames -contains $_.Name })
}

function Get-ProductResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Product,

        [Parameter(Mandatory = $true)]
        [string]$Status,

        [Nullable[int]]$ExitCode,

        [Parameter(Mandatory = $true)]
        [timespan]$Duration,

        [string]$Message = ''
    )

    [PSCustomObject]@{
        Product  = $Product.Name
        Status   = $Status
        ExitCode = $ExitCode
        Duration = [math]::Round($Duration.TotalSeconds, 1)
        Message  = $Message
    }
}

function Invoke-SoftwareProduct {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Product
    )

    $startedAt = Get-Date
    $displayCommand = Format-CommandDisplay -Product $Product

    Write-SoftwareUpdateLog -Message "Starting $($Product.Name): $displayCommand"

    if (-not (Test-Path -LiteralPath $Product.Command -PathType Leaf)) {
        $message = "Command not found: $($Product.Command)"
        Write-SoftwareUpdateLog -Level 'ERROR' -Message "$($Product.Name) failed: $message"
        return Get-ProductResult -Product $Product -Status 'MissingCommand' -ExitCode $null -Duration ((Get-Date) - $startedAt) -Message $message
    }

    if (-not (Test-Path -LiteralPath $Product.WorkingDirectory -PathType Container)) {
        $message = "Working directory not found: $($Product.WorkingDirectory)"
        Write-SoftwareUpdateLog -Level 'ERROR' -Message "$($Product.Name) failed: $message"
        return Get-ProductResult -Product $Product -Status 'MissingWorkingDirectory' -ExitCode $null -Duration ((Get-Date) - $startedAt) -Message $message
    }

    $process = New-Object System.Diagnostics.Process
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $Product.Command
    $startInfo.WorkingDirectory = $Product.WorkingDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true
    $argumentListProperty = $startInfo.GetType().GetProperty('ArgumentList')
    if ($null -ne $argumentListProperty) {
        $argumentList = $argumentListProperty.GetValue($startInfo, $null)
        foreach ($argument in $Product.Arguments) {
            [void]$argumentList.Add($argument)
        }
    }
    else {
        $startInfo.Arguments = ($Product.Arguments | ForEach-Object { ConvertTo-CommandLineArgument -Argument $_ }) -join ' '
    }

    $process.StartInfo = $startInfo
    $processStarted = $false

    try {
        [void]$process.Start()
        $processStarted = $true
        $standardOutputTask = $process.StandardOutput.ReadToEndAsync()
        $standardErrorTask = $process.StandardError.ReadToEndAsync()
        $timeout = [timespan]::FromMinutes($Product.TimeoutMinutes)

        if (-not $process.WaitForExit([int]$timeout.TotalMilliseconds)) {
            $process.Kill()
            $process.WaitForExit()
            $duration = (Get-Date) - $startedAt
            $message = "Timed out after $($Product.TimeoutMinutes) minute(s)"
            Write-SoftwareUpdateLog -Level 'ERROR' -Message "$($Product.Name) failed: $message"
            return Get-ProductResult -Product $Product -Status 'TimedOut' -ExitCode $null -Duration $duration -Message $message
        }

        $process.WaitForExit()
        $standardOutput = $standardOutputTask.Result
        $standardError = $standardErrorTask.Result

        Write-ProcessOutput -Label "$($Product.Name) stdout" -Output $standardOutput
        Write-ProcessOutput -Label "$($Product.Name) stderr" -Output $standardError

        $duration = (Get-Date) - $startedAt
        if ($process.ExitCode -eq 0) {
            Write-SoftwareUpdateLog -Message "$($Product.Name) succeeded in $([math]::Round($duration.TotalSeconds, 1)) second(s)"
            return Get-ProductResult -Product $Product -Status 'Succeeded' -ExitCode $process.ExitCode -Duration $duration
        }

        $message = "Exited with code $($process.ExitCode)"
        Write-SoftwareUpdateLog -Level 'ERROR' -Message "$($Product.Name) failed: $message"
        return Get-ProductResult -Product $Product -Status 'Failed' -ExitCode $process.ExitCode -Duration $duration -Message $message
    }
    catch {
        $duration = (Get-Date) - $startedAt
        if ($processStarted -and -not $process.HasExited) {
            $process.Kill()
            $process.WaitForExit()
        }

        $message = $_.Exception.Message
        Write-SoftwareUpdateLog -Level 'ERROR' -Message "$($Product.Name) failed: $message"
        return Get-ProductResult -Product $Product -Status 'Error' -ExitCode $null -Duration $duration -Message $message
    }
    finally {
        $process.Dispose()
    }
}

$products = @(
    Get-SoftwareProductDefinition `
        -Name 'OpenAI Codex CLI' `
        -Command 'C:\Program Files\nodejs\npm.cmd' `
        -Arguments @('install', '-g', '@openai/codex@latest') `
        -WorkingDirectory 'D:\' `
        -TimeoutMinutes 30
)

if ($ListProducts) {
    $products |
        Select-Object Name, Enabled, Command, Arguments, WorkingDirectory, TimeoutMinutes |
        Format-Table -AutoSize
    return
}

$resolvedLogDirectory = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($LogDirectory)
[void](New-Item -ItemType Directory -Path $resolvedLogDirectory -Force)
$script:LogPath = Join-Path -Path $resolvedLogDirectory -ChildPath ('Update-Software-{0}.log' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
[void](New-Item -ItemType File -Path $script:LogPath -Force)

$selectedProducts = @(Resolve-ProductSelection -Products $products -RequestedNames $ProductName)

if ($selectedProducts.Count -eq 0) {
    Write-SoftwareUpdateLog -Level 'WARN' -Message 'No enabled products selected.'
    exit 0
}

Write-SoftwareUpdateLog -Message "Update run started. Log: $script:LogPath"
Write-SoftwareUpdateLog -Message "Selected products: $($selectedProducts.Name -join ', ')"

$results = foreach ($product in $selectedProducts) {
    $displayCommand = Format-CommandDisplay -Product $product

    if (-not $PSCmdlet.ShouldProcess($product.Name, $displayCommand)) {
        Write-SoftwareUpdateLog -Level 'WARN' -Message "Skipped $($product.Name) due to WhatIf."
        Get-ProductResult -Product $product -Status 'Skipped' -ExitCode $null -Duration ([timespan]::Zero) -Message 'WhatIf'
        continue
    }

    Invoke-SoftwareProduct -Product $product
}

$failedResults = @($results | Where-Object { $_.Status -in @('Failed', 'TimedOut', 'MissingCommand', 'MissingWorkingDirectory', 'Error') })

Write-SoftwareUpdateLog -Message 'Update summary:'
foreach ($result in $results) {
    $summary = '{0}: {1}; exit={2}; duration={3}s; {4}' -f $result.Product, $result.Status, $result.ExitCode, $result.Duration, $result.Message
    Write-SoftwareUpdateLog -Message $summary
}

$results | Format-Table -AutoSize
Write-Information "Log: $script:LogPath"

if ($failedResults.Count -gt 0) {
    exit 1
}

exit 0
