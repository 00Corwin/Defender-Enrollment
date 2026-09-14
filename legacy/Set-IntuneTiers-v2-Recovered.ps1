<#
.SYNOPSIS
    Compatibility adapter for the original "Intune Tier v2" workflow recovered from the issue backlog.

.DESCRIPTION
    Accepts the original CSV shape (name,u_tier), preserves blank u_tier as "leave unchanged",
    and delegates non-blank rows to the newer defensive CMDB-to-Intune implementation.

    For new deployments, prefer scripts/intune/Set-IntuneDeviceTierFromCMDB.ps1 directly.
#>
[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path $_ })]
    [string]$CsvPath,

    [switch]$CreateMissingCategories,

    [string]$ReportPath = ".\SetIntuneTiers_v2_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$rows = @(Import-Csv -Path $CsvPath)
if ($rows.Count -eq 0) {
    throw "CSV '$CsvPath' contains no data rows."
}

$headers = @($rows[0].PSObject.Properties.Name)
if (-not ($headers -contains 'name') -or -not ($headers -contains 'u_tier')) {
    throw "The legacy CSV must contain columns 'name' and 'u_tier'."
}

$activeRows = @($rows | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.u_tier) })
$blankRows  = @($rows | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.u_tier) })

$tempPath = Join-Path ([System.IO.Path]::GetTempPath()) ("DefenderEnrollment-TierV2-{0}.csv" -f ([guid]::NewGuid().ToString('N')))
try {
    if ($activeRows.Count -gt 0) {
        $activeRows |
            Select-Object @{Name='Name';Expression={$_.name}}, @{Name='Tier';Expression={$_.u_tier}} |
            Export-Csv -Path $tempPath -NoTypeInformation -Encoding UTF8

        $targetScript = Join-Path $PSScriptRoot '..\scripts\intune\Set-IntuneDeviceTierFromCMDB.ps1'
        & $targetScript `
            -CsvPath $tempPath `
            -CreateMissingCategories:$CreateMissingCategories `
            -ReportPath $ReportPath `
            -WhatIf:$WhatIfPreference
    }
    else {
        @() | Export-Csv -Path $ReportPath -NoTypeInformation
    }

    if ($blankRows.Count -gt 0) {
        Write-Host "Skipped $($blankRows.Count) row(s) with blank u_tier; those devices were intentionally left unchanged."
    }
}
finally {
    Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
}
