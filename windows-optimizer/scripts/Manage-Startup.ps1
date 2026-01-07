<#
.SYNOPSIS
    Manages Windows startup programs.
.DESCRIPTION
    Lists, enables, or disables programs that run at Windows startup.
    Works with both Registry and Task Scheduler startup entries.
.PARAMETER Action
    List, Disable, or Enable startup entries
.PARAMETER Name
    Name of the startup entry to enable/disable (supports wildcards)
.EXAMPLE
    .\Manage-Startup.ps1 -Action List
    .\Manage-Startup.ps1 -Action Disable -Name "Discord"
    .\Manage-Startup.ps1 -Action Disable -Name "*Steam*"
    .\Manage-Startup.ps1 -Action Enable -Name "Discord"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('List', 'Disable', 'Enable')]
    [string]$Action,
    
    [Parameter()]
    [string]$Name = "*"
)

$InformationPreference = 'Continue'

$ErrorActionPreference = 'Stop'

$RegPathCU = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$RegPathLM = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"
$DisabledPathCU = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"
$DisabledPathLM = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"

function Get-StartupEntry {
    $entries = @()
    
    # User Registry Run
    $cuRun = Get-ItemProperty $RegPathCU -ErrorAction SilentlyContinue
    if ($cuRun) {
        $cuRun.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | ForEach-Object {
            $isDisabled = $false
            if (Test-Path $DisabledPathCU) {
                $approval = (Get-ItemProperty $DisabledPathCU -Name $_.Name -ErrorAction SilentlyContinue).$($_.Name)
                if ($approval -and $approval[0] -ne 2) { $isDisabled = $true }
            }
            
            $entries += [PSCustomObject]@{
                Name = $_.Name
                Command = $_.Value
                Location = "HKCU\Run"
                Status = if ($isDisabled) { "Disabled" } else { "Enabled" }
                Scope = "User"
            }
        }
    }
    
    # Machine Registry Run (requires admin for changes)
    $lmRun = Get-ItemProperty $RegPathLM -ErrorAction SilentlyContinue
    if ($lmRun) {
        $lmRun.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | ForEach-Object {
            $isDisabled = $false
            if (Test-Path $DisabledPathLM) {
                $approval = (Get-ItemProperty $DisabledPathLM -Name $_.Name -ErrorAction SilentlyContinue).$($_.Name)
                if ($approval -and $approval[0] -ne 2) { $isDisabled = $true }
            }
            
            $entries += [PSCustomObject]@{
                Name = $_.Name
                Command = $_.Value
                Location = "HKLM\Run"
                Status = if ($isDisabled) { "Disabled" } else { "Enabled" }
                Scope = "Machine"
            }
        }
    }
    
    return $entries
}

switch ($Action) {
    'List' {
        Write-Information "`n=== STARTUP PROGRAMS ===" -ForegroundColor Cyan
        Write-Information ""
        
        $entries = Get-StartupEntry
        
        if ($entries.Count -eq 0) {
            Write-Information "No startup entries found." -ForegroundColor Gray
            return
        }
        
        $enabled = $entries | Where-Object Status -eq "Enabled"
        $disabled = $entries | Where-Object Status -eq "Disabled"
        
        Write-Information "ENABLED ($($enabled.Count)):" -ForegroundColor Green
        $enabled | ForEach-Object {
            Write-Information "  $($_.Name)" -ForegroundColor White
            Write-Information "    Command: $($_.Command)" -ForegroundColor Gray
            Write-Information "    Scope: $($_.Scope)" -ForegroundColor Gray
        }
        
        if ($disabled.Count -gt 0) {
            Write-Information "`nDISABLED ($($disabled.Count)):" -ForegroundColor Yellow
            $disabled | ForEach-Object {
                Write-Information "  $($_.Name)" -ForegroundColor Gray
                Write-Information "    Command: $($_.Command)" -ForegroundColor DarkGray
            }
        }
        
        Write-Information "`nTotal: $($entries.Count) entries`n"
    }
    
    'Disable' {
        if (-not $Name) {
            Write-Information "Error: -Name parameter required for Disable action" -ForegroundColor Red
            return
        }
        
        Write-Information "`n=== DISABLING STARTUP: $Name ===" -ForegroundColor Cyan
        
        $entries = Get-StartupEntry | Where-Object { $_.Name -like $Name -and $_.Status -eq "Enabled" }
        
        if ($entries.Count -eq 0) {
            Write-Information "No enabled entries found matching '$Name'" -ForegroundColor Yellow
            return
        }
        
        foreach ($entry in $entries) {
            try {
                $approvalPath = if ($entry.Location -eq "HKCU\Run") { $DisabledPathCU } else { $DisabledPathLM }
                
                # Create disabled flag (first byte 03 = disabled, 02 = enabled)
                if (-not (Test-Path $approvalPath)) {
                    New-Item -Path $approvalPath -Force | Out-Null
                }
                
                # 03 00 00 00 00 00 00 00 00 00 00 00 = disabled
                $disabledValue = [byte[]](0x03,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)
                Set-ItemProperty -Path $approvalPath -Name $entry.Name -Value $disabledValue -Type Binary
                
                Write-Information "Disabled: $($entry.Name)" -ForegroundColor Green
            } catch {
                Write-Information "Failed to disable $($entry.Name): $_" -ForegroundColor Red
            }
        }
        
        Write-Information "`nNote: Changes take effect after next login/reboot`n"
    }
    
    'Enable' {
        if (-not $Name) {
            Write-Information "Error: -Name parameter required for Enable action" -ForegroundColor Red
            return
        }
        
        Write-Information "`n=== ENABLING STARTUP: $Name ===" -ForegroundColor Cyan
        
        $entries = Get-StartupEntry | Where-Object { $_.Name -like $Name -and $_.Status -eq "Disabled" }
        
        if ($entries.Count -eq 0) {
            Write-Information "No disabled entries found matching '$Name'" -ForegroundColor Yellow
            return
        }
        
        foreach ($entry in $entries) {
            try {
                $approvalPath = if ($entry.Location -eq "HKCU\Run") { $DisabledPathCU } else { $DisabledPathLM }
                
                # 02 00 00 00 00 00 00 00 00 00 00 00 = enabled
                $enabledValue = [byte[]](0x02,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)
                Set-ItemProperty -Path $approvalPath -Name $entry.Name -Value $enabledValue -Type Binary
                
                Write-Information "Enabled: $($entry.Name)" -ForegroundColor Green
            } catch {
                Write-Information "Failed to enable $($entry.Name): $_" -ForegroundColor Red
            }
        }
        
        Write-Information "`nNote: Changes take effect after next login/reboot`n"
    }
}
