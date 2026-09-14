<#
.SYNOPSIS
    Assigns existing Intune Device Categories Tier0..Tier5 from a CMDB CSV.

.DESCRIPTION
    Rebuild of the delegated Tier script represented by original issues #7 and #8.
    CSV columns: name,u_tier. Existing categories are not created.

    Accepted tier values: 0..5, Tier0..Tier5, Tier 0..Tier 5, T0..T5, zero..five.
    Duplicate Intune device names are resolved by the most recent lastSyncDateTime.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory)][ValidateScript({ Test-Path $_ })][string]$CsvPath,
    [string]$ReportPath = ".\IntuneTierAssignment_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-TierName {
    param([AllowNull()][string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $v = $Value.Trim().ToLowerInvariant() -replace '[\s_-]',''
    switch ($v) {
        { $_ -in @('0','t0','tier0','zero') } { 'Tier0'; break }
        { $_ -in @('1','t1','tier1','one') } { 'Tier1'; break }
        { $_ -in @('2','t2','tier2','two') } { 'Tier2'; break }
        { $_ -in @('3','t3','tier3','three') } { 'Tier3'; break }
        { $_ -in @('4','t4','tier4','four') } { 'Tier4'; break }
        { $_ -in @('5','t5','tier5','five') } { 'Tier5'; break }
        default { $null }
    }
}

function Get-GraphCollection { param([string]$Uri); $r=@(); while($Uri){$x=Invoke-MgGraphRequest -Method GET -Uri $Uri; if($x.value){$r+=$x.value}; $Uri=$x.'@odata.nextLink'}; $r }

if (-not (Get-Module -ListAvailable Microsoft.Graph.Authentication)) { throw 'Microsoft.Graph PowerShell SDK is required.' }
Import-Module Microsoft.Graph.Authentication
Connect-MgGraph -Scopes @('DeviceManagementManagedDevices.ReadWrite.All') -NoWelcome | Out-Null

$base='https://graph.microsoft.com/v1.0'
$rows=Import-Csv $CsvPath
if (-not $rows) { throw 'CSV contains no rows.' }
if ($rows[0].PSObject.Properties.Name -notcontains 'name' -or $rows[0].PSObject.Properties.Name -notcontains 'u_tier') { throw 'CSV must contain name,u_tier.' }

$categories=Get-GraphCollection "$base/deviceManagement/deviceCategories"
$categoryByName=@{}; foreach($c in $categories){$categoryByName[$c.displayName.ToLowerInvariant()]=$c}
$devices=Get-GraphCollection "$base/deviceManagement/managedDevices?`$select=id,deviceName,lastSyncDateTime,deviceCategoryDisplayName"
$report=@()

foreach($row in $rows){
    $tier=ConvertTo-TierName $row.u_tier
    $r=[ordered]@{Name=$row.name;SourceTier=$row.u_tier;TargetTier=$tier;DeviceId='';CurrentCategory='';Action='';Status='';ErrorDetail=''}
    if(-not $tier){$r.Action='Skip';$r.Status='Failed';$r.ErrorDetail='Blank or invalid tier.';$report+=[pscustomobject]$r;continue}
    if(-not $categoryByName.ContainsKey($tier.ToLowerInvariant())){$r.Action='Skip';$r.Status='Failed';$r.ErrorDetail="Category '$tier' does not exist.";$report+=[pscustomobject]$r;continue}
    $matches=@($devices|Where-Object{$_.deviceName -ieq $row.name}|Sort-Object lastSyncDateTime -Descending)
    if($matches.Count -eq 0){$r.Action='Skip';$r.Status='Failed';$r.ErrorDetail='No matching Intune device.';$report+=[pscustomobject]$r;continue}
    $d=$matches[0];$r.DeviceId=$d.id;$r.CurrentCategory=$d.deviceCategoryDisplayName
    if($d.deviceCategoryDisplayName -eq $tier){$r.Action='NoChange';$r.Status='Success';$report+=[pscustomobject]$r;continue}
    if($PSCmdlet.ShouldProcess($d.deviceName,"Assign category '$tier'")){
        try{
            $odata="$base/deviceManagement/deviceCategories/$($categoryByName[$tier.ToLowerInvariant()].id)"
            Invoke-MgGraphRequest -Method PUT -Uri "$base/deviceManagement/managedDevices('$($d.id)')/deviceCategory/`$ref" -Body (@{'@odata.id'=$odata}|ConvertTo-Json) -ContentType 'application/json'|Out-Null
            $r.Action='Assign';$r.Status='Success'
        }catch{$r.Action='Assign';$r.Status='Failed';$r.ErrorDetail=$_.Exception.Message}
    }else{$r.Action='Assign';$r.Status='WhatIf'}
    $report+=[pscustomobject]$r
}
$report|Export-Csv $ReportPath -NoTypeInformation
$report|Group-Object Status,Action|Select-Object Name,Count|Format-Table -AutoSize
Write-Output "Report: $ReportPath"
