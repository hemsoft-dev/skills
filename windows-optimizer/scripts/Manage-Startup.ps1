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
        Write-Information "[36m`n=== STARTUP PROGRAMS ===`e[0m"
        Write-Information ""
        
        $entries = Get-StartupEntry
        
        if ($entries.Count -eq 0) {
            Write-Information "[90mNo startup entries found.`e[0m"
            return
        }
        
        $enabled = $entries | Where-Object Status -eq "Enabled"
        $disabled = $entries | Where-Object Status -eq "Disabled"
        
        Write-Information "[32mENABLED ($($enabled.Count)):`e[0m"
        $enabled | ForEach-Object {
            Write-Information "[97m  $($_.Name)`e[0m"
            Write-Information "[90m    Command: $($_.Command)`e[0m"
            Write-Information "[90m    Scope: $($_.Scope)`e[0m"
        }
        
        if ($disabled.Count -gt 0) {
            Write-Information "[33m`nDISABLED ($($disabled.Count)):`e[0m"
            $disabled | ForEach-Object {
                Write-Information "[90m  $($_.Name)`e[0m"
                Write-Information "[90m    Command: $($_.Command)`e[0m"
            }
        }
        
        Write-Information "`nTotal: $($entries.Count) entries`n"
    }
    
    'Disable' {
        if (-not $Name) {
            Write-Information "[31mError: -Name parameter required for Disable action`e[0m"
            return
        }
        
        Write-Information "[36m`n=== DISABLING STARTUP: $Name ===`e[0m"
        
        $entries = Get-StartupEntry | Where-Object { $_.Name -like $Name -and $_.Status -eq "Enabled" }
        
        if ($entries.Count -eq 0) {
            Write-Information "[33mNo enabled entries found matching '$Name'`e[0m"
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
                
                Write-Information "[32mDisabled: $($entry.Name)`e[0m"
            } catch {
                Write-Information "[31mFailed to disable $($entry.Name): $_`e[0m"
            }
        }
        
        Write-Information "`nNote: Changes take effect after next login/reboot`n"
    }
    
    'Enable' {
        if (-not $Name) {
            Write-Information "[31mError: -Name parameter required for Enable action`e[0m"
            return
        }
        
        Write-Information "[36m`n=== ENABLING STARTUP: $Name ===`e[0m"
        
        $entries = Get-StartupEntry | Where-Object { $_.Name -like $Name -and $_.Status -eq "Disabled" }
        
        if ($entries.Count -eq 0) {
            Write-Information "[33mNo disabled entries found matching '$Name'`e[0m"
            return
        }
        
        foreach ($entry in $entries) {
            try {
                $approvalPath = if ($entry.Location -eq "HKCU\Run") { $DisabledPathCU } else { $DisabledPathLM }
                
                # 02 00 00 00 00 00 00 00 00 00 00 00 = enabled
                $enabledValue = [byte[]](0x02,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)
                Set-ItemProperty -Path $approvalPath -Name $entry.Name -Value $enabledValue -Type Binary
                
                Write-Information "[32mEnabled: $($entry.Name)`e[0m"
            } catch {
                Write-Information "[31mFailed to enable $($entry.Name): $_`e[0m"
            }
        }
        
        Write-Information "`nNote: Changes take effect after next login/reboot`n"
    }
}
