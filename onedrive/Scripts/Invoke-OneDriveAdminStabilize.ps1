[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string[]]$ServiceNames = @('atkexComSvc', 'MTKBTSVC'),
    [int]$LogWindowMinutes = 15,
    [switch]$ResetOneDrive
)

$InformationPreference = 'Continue'
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-OneDriveExePath {
    $candidates = @(
        "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe",
        "C:\Program Files\Microsoft OneDrive\OneDrive.exe"
    )

    foreach ($path in $candidates) {
        if (Test-Path $path) {
            return $path
        }
    }

    throw 'OneDrive executable not found.'
}

function Get-OdlMarkerCounts {
    param(
        [int]$Minutes
    )

    $since = (Get-Date).AddMinutes(-$Minutes)
    $logDir = Join-Path $env:LOCALAPPDATA 'Microsoft\OneDrive\logs\Personal'
    $logs = Get-ChildItem $logDir -Filter '*.odl' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -gt $since }

    $markers = @('UnexpectedFailure', 'PostponedChanges', 'LC_CREATE_FILE', 'LC_CHANGE_FILE', 'Error', 'AccessDenied', 'Timeout')
    $result = [ordered]@{
        WindowMinutes = $Minutes
        LogFilesFound = ($logs | Measure-Object).Count
    }

    foreach ($marker in $markers) {
        $count = 0
        if ($logs) {
            $count = (Select-String -Path $logs.FullName -Pattern $marker -SimpleMatch -ErrorAction SilentlyContinue | Measure-Object).Count
        }
        $result[$marker] = $count
    }

    return [PSCustomObject]$result
}

function Show-TopHandles {
    Get-Process |
        Sort-Object Handles -Descending |
        Select-Object -First 12 Name, Id, Handles, @{N = 'MemMB'; E = { [math]::Round($_.WorkingSet64 / 1MB, 1) }}
}

if (-not (Test-IsAdmin)) {
    Write-Information "`e[31m❌ This script must run in an elevated PowerShell session (Run as Administrator).`e[0m"
    Write-Information "`e[33m   Right-click PowerShell -> Run as administrator, then run this script again.`e[0m"
    exit 1
}

Write-Information "`e[36m=== OneDrive Admin Stabilization ===`e[0m"
Write-Information "`e[90mTime: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`e[0m"

$beforeMarkers = Get-OdlMarkerCounts -Minutes $LogWindowMinutes
Write-Information "`e[33m`nODL markers before changes (last $LogWindowMinutes min):`e[0m"
$beforeMarkers | Format-List | Out-String | Write-Information

Write-Information "`e[33mTop handle processes before changes:`e[0m"
Show-TopHandles | Format-Table -AutoSize | Out-String | Write-Information

Write-Information "`e[33m`nService remediation:`e[0m"
foreach ($serviceName in $ServiceNames) {
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if (-not $service) {
        Write-Information "`e[90m- ${serviceName}: not found (skipped)`e[0m"
        continue
    }

    if ($PSCmdlet.ShouldProcess($serviceName, 'Restart service')) {
        try {
            if ($service.Status -eq 'Running') {
                Restart-Service -Name $serviceName -Force -ErrorAction Stop
                Write-Information "`e[32m- ${serviceName}: restarted`e[0m"
            }
            else {
                Start-Service -Name $serviceName -ErrorAction Stop
                Write-Information "`e[32m- ${serviceName}: started`e[0m"
            }
        }
        catch {
            Write-Information "`e[31m- ${serviceName}: failed -> $($_.Exception.Message)`e[0m"
        }
    }
}

$oneDriveExe = Get-OneDriveExePath

if ($ResetOneDrive) {
    Write-Information "`e[33m`nOneDrive reset sequence:`e[0m"
    if ($PSCmdlet.ShouldProcess('OneDrive', 'Reset and restart')) {
        Stop-Process -Name OneDrive -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        & $oneDriveExe /reset
        Start-Sleep -Seconds 5
        Write-Information "`e[32m- OneDrive reset issued (admin context)`e[0m"
        Write-Information "`e[33m- Start OneDrive from a non-admin shell: & '$oneDriveExe'`e[0m"
    }
}
else {
    Write-Information "`e[33m`nOneDrive restart sequence:`e[0m"
    if ($PSCmdlet.ShouldProcess('OneDrive', 'Restart')) {
        Stop-Process -Name OneDrive -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Write-Information "`e[32m- OneDrive stopped (admin context)`e[0m"
        Write-Information "`e[33m- Start OneDrive from a non-admin shell: & '$oneDriveExe'`e[0m"
    }
}

Start-Sleep -Seconds 10

Write-Information "`e[33m`nOneDrive process after changes:`e[0m"
Get-Process OneDrive -ErrorAction SilentlyContinue |
    Select-Object Name, Id, Handles, CPU, StartTime, Path |
    Format-List |
    Out-String |
    Write-Information

$afterMarkers = Get-OdlMarkerCounts -Minutes $LogWindowMinutes
Write-Information "`e[33mODL markers after changes (last $LogWindowMinutes min):`e[0m"
$afterMarkers | Format-List | Out-String | Write-Information

Write-Information "`e[33mTop handle processes after changes:`e[0m"
Show-TopHandles | Format-Table -AutoSize | Out-String | Write-Information

Write-Information "`e[36m=== Done ===`e[0m"