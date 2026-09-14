<#
.SYNOPSIS
    Migration helper for moving a Windows Server from Trend Micro protection to Microsoft Defender.

.DESCRIPTION
    Rebuild of the original Defender-Enrollment codebase. Captures Defender state before and after,
    can set ForceDefenderPassiveMode to 0, can apply the local MDE management tag, and can launch
    a detected Trend Micro NTRmv.exe uninstall utility.

    Internal UNC paths and tenant-specific values from the original project were removed.

.PARAMETER LogDirectory
    Directory used for JSON and text evidence.

.PARAMETER DeviceTag
    Local Defender device-tag value. Defaults to MDE-Management, matching the original project.

.PARAMETER SkipTrendRemoval
    Do not attempt to find or launch Trend Micro NTRmv.exe.

.PARAMETER SkipDefenderRegistryChange
    Do not change ForceDefenderPassiveMode.

.PARAMETER SkipDeviceTag
    Do not set the local Defender DeviceTagging Group value.

.PARAMETER ForceServer2016
    Permit Trend removal on Windows Server 2016 even when the interactive confirmation would otherwise be required.
    A pending reboot still blocks removal unless -IgnorePendingReboot is also used.

.PARAMETER IgnorePendingReboot
    Do not block Trend removal when a pending reboot indicator is found. Use with care.

.EXAMPLE
    .\Enable-DefenderAndRemoveTrend.ps1 -WhatIf
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [string]$LogDirectory = "$env:ProgramData\DefenderEnrollment\Logs",
    [string]$DeviceTag = 'MDE-Management',
    [switch]$SkipTrendRemoval,
    [switch]$SkipDefenderRegistryChange,
    [switch]$SkipDeviceTag,
    [switch]$ForceServer2016,
    [switch]$IgnorePendingReboot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-PendingReboot {
    $indicators = [ordered]@{
        ComponentBasedServicing = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
        WindowsUpdate           = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
        PendingFileRename       = $null -ne (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue)
    }
    [PSCustomObject]@{
        IsPending  = ($indicators.Values -contains $true)
        Indicators = $indicators
    }
}

function Get-PropertyValue {
    param(
        [Parameter(Mandatory)]$InputObject,
        [Parameter(Mandatory)][string]$Name
    )
    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -ne $property) { return $property.Value }
    return $null
}

function Get-DefenderSnapshot {
    $status = Get-MpComputerStatus
    $pref = Get-MpPreference
    $atpPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Advanced Threat Protection'
    $tagPath = Join-Path $atpPath 'DeviceTagging'
    $forcePassive = (Get-ItemProperty -Path $atpPath -Name ForceDefenderPassiveMode -ErrorAction SilentlyContinue).ForceDefenderPassiveMode
    $groupTag = (Get-ItemProperty -Path $tagPath -Name Group -ErrorAction SilentlyContinue).Group

    $statusProperties = @(
        'AMRunningMode',
        'AMServiceEnabled',
        'AntivirusEnabled',
        'AntispywareEnabled',
        'BehaviorMonitorEnabled',
        'IoavProtectionEnabled',
        'IsTamperProtected',
        'NISEnabled',
        'OnAccessProtectionEnabled',
        'RealTimeProtectionEnabled',
        'RealTimeScanDirection',
        'TamperProtectionSource',
        'TroubleShootingMode',
        'AMProductVersion',
        'AMEngineVersion',
        'AntivirusSignatureVersion',
        'AntivirusSignatureLastUpdated'
    )

    $preferenceProperties = @(
        'CheckForSignaturesBeforeRunningScan',
        'CloudBlockLevel',
        'DisableArchiveScanning',
        'DisableBehaviorMonitoring',
        'DisableCatchupFullScan',
        'DisableCatchupQuickScan',
        'DisableEmailScanning',
        'DisableIOAVProtection',
        'DisableRealtimeMonitoring',
        'DisableRemovableDriveScanning',
        'DisableScanningNetworkFiles',
        'DisableScriptScanning',
        'EnableLowCpuPriority',
        'EnableNetworkProtection',
        'HighThreatDefaultAction',
        'ModerateThreatDefaultAction',
        'LowThreatDefaultAction',
        'SevereThreatDefaultAction',
        'UnknownThreatDefaultAction',
        'IntrusionPreventionSystemEnable',
        'MAPSReporting',
        'PUAProtection',
        'RealTimeScanDirection',
        'ScanAvgCPULoadFactor',
        'ScanParameters',
        'ScanScheduleDay',
        'ScanScheduleOffset',
        'ScanScheduleQuickScanTime',
        'ScanScheduleTime',
        'ExclusionProcess',
        'ExclusionExtension',
        'ExclusionPath',
        'AttackSurfaceReductionRules_Ids',
        'AttackSurfaceReductionRules_Actions',
        'ThreatIDDefaultAction_Ids',
        'ThreatIDDefaultAction_Actions',
        'SubmitSamplesConsent',
        'SignatureUpdateInterval'
    )

    $statusOutput = [ordered]@{}
    foreach ($name in $statusProperties) {
        $statusOutput[$name] = Get-PropertyValue -InputObject $status -Name $name
    }

    $preferenceOutput = [ordered]@{}
    foreach ($name in $preferenceProperties) {
        $preferenceOutput[$name] = Get-PropertyValue -InputObject $pref -Name $name
    }

    [PSCustomObject]@{
        ComputerName             = $env:COMPUTERNAME
        Timestamp                = (Get-Date).ToString('o')
        DefenderStatus           = [PSCustomObject]$statusOutput
        DefenderPreferences      = [PSCustomObject]$preferenceOutput
        ForceDefenderPassiveMode = $forcePassive
        DeviceTagGroup           = $groupTag
    }
}

if (-not (Test-Administrator)) {
    throw 'Run this script from an elevated PowerShell session.'
}

foreach ($cmd in 'Get-MpComputerStatus','Get-MpPreference') {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        throw "Required Defender cmdlet is unavailable: $cmd"
    }
}

New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$base = Join-Path $LogDirectory "$($env:COMPUTERNAME)_$stamp"
$prePath = "${base}_pre.json"
$postPath = "${base}_post.json"
$runPath = "${base}_run.log"

function Write-RunLog {
    param([string]$Message)
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    Write-Output $line
    Add-Content -Path $runPath -Value $line
}

Write-RunLog 'Capturing pre-change Defender state.'
Get-DefenderSnapshot | ConvertTo-Json -Depth 10 | Set-Content -Path $prePath -Encoding UTF8

$os = Get-CimInstance Win32_OperatingSystem
$isServer2016 = $os.Caption -match 'Windows Server 2016'
$pending = Test-PendingReboot
Write-RunLog "Operating system: $($os.Caption)"
Write-RunLog "Pending reboot: $($pending.IsPending)"

$atpPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Advanced Threat Protection'
$tagPath = Join-Path $atpPath 'DeviceTagging'

if (-not $SkipDefenderRegistryChange) {
    if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Set ForceDefenderPassiveMode=0')) {
        New-Item -Path $atpPath -Force | Out-Null
        New-ItemProperty -Path $atpPath -Name ForceDefenderPassiveMode -PropertyType DWord -Value 0 -Force | Out-Null
        Write-RunLog 'Set ForceDefenderPassiveMode to 0.'
    }
}

if (-not $SkipDeviceTag) {
    if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Set local Defender device tag '$DeviceTag'")) {
        New-Item -Path $tagPath -Force | Out-Null
        New-ItemProperty -Path $tagPath -Name Group -PropertyType String -Value $DeviceTag -Force | Out-Null
        Write-RunLog "Set Defender DeviceTagging Group to '$DeviceTag'."
    }
}

if (-not $SkipTrendRemoval) {
    $pathsToCheck = @(
        'C:\Program Files\Trend Micro\OfficeScan Client\NTRmv.exe',
        'C:\Program Files\Trend Micro\Security Agent\NTRmv.exe',
        'C:\Program Files (x86)\Trend Micro\OfficeScan Client\NTRmv.exe',
        'C:\Program Files (x86)\Trend Micro\Security Agent\NTRmv.exe'
    )
    $trendUninstaller = $pathsToCheck | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $trendUninstaller) {
        Write-RunLog 'Trend Micro NTRmv.exe was not found in the known locations.'
    }
    else {
        if ($pending.IsPending -and -not $IgnorePendingReboot) {
            throw 'A pending reboot was detected. Trend removal was blocked to reduce the risk of an unexpected restart.'
        }
        if ($isServer2016 -and -not $ForceServer2016) {
            throw 'Windows Server 2016 detected. Re-run with -ForceServer2016 only after validating reboot risk for this server.'
        }
        if ($PSCmdlet.ShouldProcess($trendUninstaller, 'Launch Trend Micro removal utility')) {
            Write-RunLog "Launching Trend Micro removal utility: $trendUninstaller"
            $proc = Start-Process -FilePath $trendUninstaller -Wait -PassThru
            Write-RunLog "Trend Micro removal utility exited with code $($proc.ExitCode)."
        }
    }
}

Write-RunLog 'Capturing post-change Defender state.'
Get-DefenderSnapshot | ConvertTo-Json -Depth 10 | Set-Content -Path $postPath -Encoding UTF8
Write-RunLog "Pre-change report: $prePath"
Write-RunLog "Post-change report: $postPath"
Write-RunLog 'End of script.'
