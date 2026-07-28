#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Reads power telemetry from a USB-connected CyberPower GX150C2 UPS.

.DESCRIPTION
    Reads the standard USB HID PercentLoad feature report and estimates output
    watts from the UPS's rated real-power capacity. This is an estimate, not a
    utility-grade measurement of input power at the wall.

.EXAMPLE
    .\Get-GX150C2Power.ps1
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ratedWatts = 1000

if ($env:OS -ne 'Windows_NT') {
    throw 'Get-GX150C2Power.ps1 requires Windows.'
}

if (-not ('CyberPowerHidFeatureReader' -as [type])) {
    $hidReaderSource = @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;

public static class CyberPowerHidFeatureReader
{
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern SafeFileHandle CreateFileW(
        string fileName,
        uint desiredAccess,
        uint shareMode,
        IntPtr securityAttributes,
        uint creationDisposition,
        uint flagsAndAttributes,
        IntPtr templateFile);

    [DllImport("hid.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.U1)]
    private static extern bool HidD_GetFeature(
        SafeFileHandle hidDeviceObject,
        byte[] reportBuffer,
        int reportBufferLength);

    public static byte[] GetFeature(string devicePath, byte reportId, int reportLength)
    {
        using (SafeFileHandle handle = CreateFileW(
            devicePath,
            0,
            3,
            IntPtr.Zero,
            3,
            0,
            IntPtr.Zero))
        {
            if (handle.IsInvalid)
            {
                throw new Win32Exception(
                    Marshal.GetLastWin32Error(),
                    "Unable to open the UPS HID interface.");
            }

            byte[] buffer = new byte[reportLength];
            buffer[0] = reportId;

            if (!HidD_GetFeature(handle, buffer, buffer.Length))
            {
                throw new Win32Exception(
                    Marshal.GetLastWin32Error(),
                    "Unable to read a UPS HID feature report.");
            }

            return buffer;
        }
    }
}
'@

    Add-Type -TypeDefinition $hidReaderSource
}

$upsDevices = @(
    Get-PnpDevice -PresentOnly |
        Where-Object { $_.InstanceId -like 'HID\VID_0764&PID_0601\*' }
)

if ($upsDevices.Count -eq 0) {
    throw 'No USB-connected CyberPower UPS (VID 0764, PID 0601) was found.'
}

if ($upsDevices.Count -gt 1) {
    throw 'Multiple compatible CyberPower UPS HID interfaces were found.'
}

$upsDevice = $upsDevices[0]
$usbDevices = @(
    Get-PnpDevice -PresentOnly |
        Where-Object { $_.InstanceId -like 'USB\VID_0764&PID_0601\*' }
)

if ($usbDevices.Count -eq 0) {
    throw 'The CyberPower UPS USB parent device was not found.'
}

if ($usbDevices.Count -gt 1) {
    throw 'Multiple compatible CyberPower UPS USB parent devices were found.'
}

$usbDevice = $usbDevices[0]
$modelProperty = Get-PnpDeviceProperty `
    -InstanceId $usbDevice.InstanceId `
    -KeyName 'DEVPKEY_Device_BusReportedDeviceDesc'

if ($modelProperty.Data -ne 'GX150C2') {
    throw "Connected CyberPower UPS is '$($modelProperty.Data)', not GX150C2."
}

$instanceParts = $upsDevice.InstanceId.ToLowerInvariant().Split('\')
if ($instanceParts.Count -lt 3) {
    throw "Unexpected HID instance ID: $($upsDevice.InstanceId)"
}

$hidInterfaceGuid = '{4d1e55b2-f16f-11cf-88cb-001111000030}'
$devicePath = '\\?\' +
    $instanceParts[0] + '#' +
    $instanceParts[1] + '#' +
    $instanceParts[2] + '#' +
    $hidInterfaceGuid

$featureReportLength = 64
$loadReport = [CyberPowerHidFeatureReader]::GetFeature(
    $devicePath,
    0x13,
    $featureReportLength)
$inputVoltageReport = [CyberPowerHidFeatureReader]::GetFeature(
    $devicePath,
    0x0F,
    $featureReportLength)
$outputVoltageReport = [CyberPowerHidFeatureReader]::GetFeature(
    $devicePath,
    0x12,
    $featureReportLength)
$batteryReport = [CyberPowerHidFeatureReader]::GetFeature(
    $devicePath,
    0x08,
    $featureReportLength)

$loadPercent = [int]$loadReport[1]

[pscustomobject]@{
    Timestamp            = Get-Date
    Model                = $modelProperty.Data
    LoadPercent          = $loadPercent
    EstimatedOutputWatts = [math]::Round(($loadPercent / 100) * $ratedWatts)
    EstimateResolutionW  = [math]::Round($ratedWatts / 100)
    RatedWatts           = $ratedWatts
    InputVoltage         = [BitConverter]::ToUInt16($inputVoltageReport, 1)
    OutputVoltage        = [BitConverter]::ToUInt16($outputVoltageReport, 1)
    BatteryChargePercent = [int]$batteryReport[1]
    Measurement          = 'USB HID PercentLoad multiplied by rated watts'
}
