<#
.SYNOPSIS
    Creates Intune device categories when requested and assigns devices from CSV.

.CSV
    DeviceName,Category

.REQUIREMENTS
    Microsoft.Graph.Authentication
    Delegated permission: DeviceManagementManagedDevices.ReadWrite.All
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path $_ })]
    [string]$CsvPath,
    [switch]$CreateMissingCategories,
    [string]$ReportPath = ".\IntuneCategoryAssignment_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-GraphCollection {
    param([Parameter(Mandatory)][string]$Uri)
    $all = @()
    $next = $Uri
    while ($next) {
        $response = Invoke-MgGraphRequest -Method GET -Uri $next
        if ($response.value) { $all += $response.value }
        $next = $response.'@odata.nextLink'
    }
    $all
}

if (-not (Get-Module -ListAvailable Microsoft.Graph.Authentication)) {
    throw 'Install Microsoft Graph PowerShell SDK first: Install-Module Microsoft.Graph -Scope CurrentUser'
}
Import-Module Microsoft.Graph.Authentication
Connect-MgGraph -Scopes 'DeviceManagementManagedDevices.ReadWrite.All' -NoWelcome | Out-Null

$base = 'https://graph.microsoft.com/v1.0'
$rows = Import-Csv $CsvPath
if (-not $rows) { throw 'CSV contains no rows.' }
if ($rows[0].PSObject.Properties.Name -notcontains 'DeviceName' -or $rows[0].PSObject.Properties.Name -notcontains 'Category') {
    throw 'CSV must contain DeviceName and Category columns.'
}

$categories = Get-GraphCollection "$base/deviceManagement/deviceCategories"
$categoryByName = @{}
foreach ($c in $categories) { $categoryByName[$c.displayName.ToLowerInvariant()] = $c }

$devices = Get-GraphCollection "$base/deviceManagement/managedDevices?`$select=id,deviceName,lastSyncDateTime,deviceCategoryDisplayName"
$report = @()

foreach ($row in $rows) {
    $name = [string]$row.DeviceName
    $categoryName = [string]$row.Category
    $result = [ordered]@{ DeviceName=$name; DesiredCategory=$categoryName; DeviceId=''; CurrentCategory=''; Action=''; Status=''; Message='' }

    if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($categoryName)) {
        $result.Action='Skip'; $result.Status='Failed'; $result.Message='DeviceName or Category is blank.'
        $report += [pscustomobject]$result; continue
    }

    $key = $categoryName.Trim().ToLowerInvariant()
    if (-not $categoryByName.ContainsKey($key)) {
        if (-not $CreateMissingCategories) {
            $result.Action='Skip'; $result.Status='Failed'; $result.Message="Category '$categoryName' does not exist."
            $report += [pscustomobject]$result; continue
        }
        if ($PSCmdlet.ShouldProcess($categoryName, 'Create Intune device category')) {
            $body = @{ displayName=$categoryName; description='Created by Defender-Enrollment automation' } | ConvertTo-Json
            $newCategory = Invoke-MgGraphRequest -Method POST -Uri "$base/deviceManagement/deviceCategories" -Body $body -ContentType 'application/json'
            $categoryByName[$key] = $newCategory
        } else {
            $result.Action='CreateCategory'; $result.Status='WhatIf'; $result.Message="Would create '$categoryName'."
            $report += [pscustomobject]$result; continue
        }
    }

    $matches = @($devices | Where-Object { $_.deviceName -ieq $name } | Sort-Object lastSyncDateTime -Descending)
    if ($matches.Count -eq 0) {
        $result.Action='Skip'; $result.Status='Failed'; $result.Message='No matching Intune managed device.'
        $report += [pscustomobject]$result; continue
    }

    $device = $matches[0]
    $category = $categoryByName[$key]
    $result.DeviceId = $device.id
    $result.CurrentCategory = $device.deviceCategoryDisplayName

    if ($device.deviceCategoryDisplayName -eq $categoryName) {
        $result.Action='NoChange'; $result.Status='Success'; $result.Message='Already assigned.'
        $report += [pscustomobject]$result; continue
    }

    if ($PSCmdlet.ShouldProcess($device.deviceName, "Assign Intune category '$categoryName'")) {
        $odataId = "$base/deviceManagement/deviceCategories/$($category.id)"
        $uri = "$base/deviceManagement/managedDevices('$($device.id)')/deviceCategory/`$ref"
        Invoke-MgGraphRequest -Method PUT -Uri $uri -Body (@{ '@odata.id'=$odataId } | ConvertTo-Json) -ContentType 'application/json' | Out-Null
        $result.Action='Assign'; $result.Status='Success'; $result.Message="Assigned '$categoryName'."
    } else {
        $result.Action='Assign'; $result.Status='WhatIf'; $result.Message="Would assign '$categoryName'."
    }
    $report += [pscustomobject]$result
}

$report | Export-Csv $ReportPath -NoTypeInformation
$report | Group-Object Status,Action | Select-Object Name,Count | Format-Table -AutoSize
Write-Output "Report: $ReportPath"
