<#
.SYNOPSIS
    Collects local Microsoft Defender Antivirus health, configuration and threat-detection data.

.PARAMETER OutputPath
    JSON report path.
#>

[CmdletBinding()]
param(
    [string]$OutputPath = ".\DefenderHealth_$($env:COMPUTERNAME)_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
)

$requiredCommands = @('Get-MpComputerStatus','Get-MpPreference','Get-MpThreatDetection')
$missing = @($requiredCommands | Where-Object { -not (Get-Command $_ -ErrorAction SilentlyContinue) })
if ($missing.Count -gt 0) {
    throw "Required Defender cmdlets are unavailable: $($missing -join ', ')"
}

$status = Get-MpComputerStatus
$preferences = Get-MpPreference
$threatDetections = @(Get-MpThreatDetection -ErrorAction SilentlyContinue)

$summary = [PSCustomObject]@{
    AMRunningMode                  = $status.AMRunningMode
    AMServiceEnabled              = $status.AMServiceEnabled
    AntivirusEnabled              = $status.AntivirusEnabled
    AntispywareEnabled            = $status.AntispywareEnabled
    BehaviorMonitorEnabled        = $status.BehaviorMonitorEnabled
    IoavProtectionEnabled         = $status.IoavProtectionEnabled
    NISEnabled                    = $status.NISEnabled
    OnAccessProtectionEnabled     = $status.OnAccessProtectionEnabled
    RealTimeProtectionEnabled     = $status.RealTimeProtectionEnabled
    AntivirusSignatureVersion     = $status.AntivirusSignatureVersion
    AntivirusSignatureLastUpdated = $status.AntivirusSignatureLastUpdated
    AMEngineVersion               = $status.AMEngineVersion
    AMProductVersion              = $status.AMProductVersion
    IsTamperProtected             = $status.IsTamperProtected
    TamperProtectionSource        = $status.TamperProtectionSource
}

$report = [PSCustomObject]@{
    ComputerName     = $env:COMPUTERNAME
    CollectedAt      = (Get-Date).ToString('o')
    Summary          = $summary
    ComputerStatus   = $status
    Preferences      = $preferences
    ThreatDetections = $threatDetections
}

$report | ConvertTo-Json -Depth 12 | Set-Content -Path $OutputPath -Encoding UTF8
$summary | Format-List
Write-Output "Full Defender report written to: $OutputPath"
