<#
.SYNOPSIS
    Maps ServiceNow CMDB server tiering data to Intune Device Categories.

.DESCRIPTION
    Imports a CMDB CSV and maps devices into Intune Device Categories Tier-0 through Tier-5.
    Supports name aliases, optional serial matching, optional category creation, WhatIf and detailed reporting.

.CSV REQUIREMENTS
    Required columns: Name, Tier
    Optional column: Serial Number

.PERMISSIONS
    DeviceManagementManagedDevices.ReadWrite.All
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory)][ValidateScript({ Test-Path $_ })][string]$CsvPath,
    [switch]$CreateMissingCategories,
    [string]$DefaultTier = 'Tier-Unclassified',
    [string]$ReportPath = ".\IntuneTieringReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

function Normalise-Tier {
    param([string]$TierValue,[string]$FallbackTier)
    if([string]::IsNullOrWhiteSpace($TierValue)){return $FallbackTier}
    $clean=$TierValue.Trim()
    switch -Regex ($clean){
        '^(Tier[-_\s]?)?0$|^T0$|^zero$'{'Tier-0';break}
        '^(Tier[-_\s]?)?1$|^T1$|^one$'{'Tier-1';break}
        '^(Tier[-_\s]?)?2$|^T2$|^two$'{'Tier-2';break}
        '^(Tier[-_\s]?)?3$|^T3$|^three$'{'Tier-3';break}
        '^(Tier[-_\s]?)?4$|^T4$|^four$'{'Tier-4';break}
        '^(Tier[-_\s]?)?5$|^T5$|^five$'{'Tier-5';break}
        default{$null}
    }
}
function Get-GraphCollection {param([string]$Uri);$r=@();while($Uri){$x=Invoke-MgGraphRequest -Method GET -Uri $Uri;if($x.value){$r+=$x.value};$Uri=$x.'@odata.nextLink'};$r}
function Get-CsvProperty {param([object]$Row,[string[]]$PossibleNames);foreach($n in $PossibleNames){if($Row.PSObject.Properties.Name -contains $n){return $Row.$n}};$null}

if(-not(Get-Module -ListAvailable Microsoft.Graph.Authentication)){throw 'Microsoft Graph PowerShell SDK is required.'}
Import-Module Microsoft.Graph.Authentication
Connect-MgGraph -Scopes 'DeviceManagementManagedDevices.ReadWrite.All' -NoWelcome | Out-Null
$base='https://graph.microsoft.com/v1.0'
$rows=Import-Csv $CsvPath
if(-not $rows){throw 'CSV contains no rows.'}

$categories=Get-GraphCollection "$base/deviceManagement/deviceCategories";$categoryByName=@{};foreach($c in $categories){$categoryByName[$c.displayName.ToLowerInvariant()]=$c}
$devices=Get-GraphCollection "$base/deviceManagement/managedDevices?`$select=id,deviceName,serialNumber,operatingSystem,deviceCategoryDisplayName,lastSyncDateTime"
$byName=@{};$bySerial=@{}
foreach($d in $devices){
    if($d.deviceName){$k=$d.deviceName.ToLowerInvariant();if(-not $byName.ContainsKey($k)){$byName[$k]=@()};$byName[$k]+=$d}
    if($d.serialNumber){$k=$d.serialNumber.ToLowerInvariant();if(-not $bySerial.ContainsKey($k)){$bySerial[$k]=@()};$bySerial[$k]+=$d}
}
$report=@()
foreach($row in $rows){
    $csvName=Get-CsvProperty $row @('Name','Device Name','ComputerName','Computer Name')
    $csvTier=Get-CsvProperty $row @('Tier','Device Tier','Server Tier','u_tier')
    $csvSerial=Get-CsvProperty $row @('Serial Number','SerialNumber','Serial')
    $desired=Normalise-Tier $csvTier $DefaultTier
    $r=[ordered]@{CsvName=$csvName;CsvSerial=$csvSerial;CsvTier=$csvTier;DesiredTier=$desired;IntuneDeviceName='';IntuneSerial='';OperatingSystem='';CurrentCategory='';MatchMethod='';Action='';Status='';Message=''}
    if([string]::IsNullOrWhiteSpace($csvName)){$r.Action='Skipped';$r.Status='Failed';$r.Message='CSV row has no device name.';$report+=[pscustomobject]$r;continue}
    if([string]::IsNullOrWhiteSpace($desired)){$r.Action='Skipped';$r.Status='Failed';$r.Message="Tier '$csvTier' is invalid.";$report+=[pscustomobject]$r;continue}
    $ck=$desired.ToLowerInvariant()
    if(-not $categoryByName.ContainsKey($ck)){
        if(-not $CreateMissingCategories){$r.Action='Skipped';$r.Status='Failed';$r.Message="Category '$desired' does not exist.";$report+=[pscustomobject]$r;continue}
        if($PSCmdlet.ShouldProcess($desired,'Create Intune Device Category')){
            try{$body=@{displayName=$desired;description='Created by CMDB tiering automation'}|ConvertTo-Json;$new=Invoke-MgGraphRequest -Method POST -Uri "$base/deviceManagement/deviceCategories" -Body $body -ContentType 'application/json';$categoryByName[$ck]=$new}catch{$r.Action='CreateCategory';$r.Status='Failed';$r.Message=$_.Exception.Message;$report+=[pscustomobject]$r;continue}
        }else{$r.Action='CreateCategory';$r.Status='WhatIf';$r.Message="Would create '$desired'.";$report+=[pscustomobject]$r;continue}
    }
    $matches=@();$nk=$csvName.ToLowerInvariant()
    if($byName.ContainsKey($nk)){$matches=@($byName[$nk]);$r.MatchMethod='Name'}elseif($csvSerial){$sk=$csvSerial.ToLowerInvariant();if($bySerial.ContainsKey($sk)){$matches=@($bySerial[$sk]);$r.MatchMethod='Serial'}}
    if($matches.Count -eq 0){$r.Action='Skipped';$r.Status='Failed';$r.Message='No matching Intune device.';$report+=[pscustomobject]$r;continue}
    if($matches.Count -gt 1){$matches=@($matches|Sort-Object lastSyncDateTime -Descending);$r.Message='Multiple matches found; selected most recent LastSyncDateTime.'}
    $d=$matches[0];$r.IntuneDeviceName=$d.deviceName;$r.IntuneSerial=$d.serialNumber;$r.OperatingSystem=$d.operatingSystem;$r.CurrentCategory=$d.deviceCategoryDisplayName
    if($d.deviceCategoryDisplayName -eq $desired){$r.Action='NoChange';$r.Status='Success';if(-not $r.Message){$r.Message="Already assigned to '$desired'."};$report+=[pscustomobject]$r;continue}
    $action="Set Intune Device Category from '$($d.deviceCategoryDisplayName)' to '$desired'"
    if($PSCmdlet.ShouldProcess($d.deviceName,$action)){
        try{$odata="$base/deviceManagement/deviceCategories/$($categoryByName[$ck].id)";Invoke-MgGraphRequest -Method PUT -Uri "$base/deviceManagement/managedDevices('$($d.id)')/deviceCategory/`$ref" -Body (@{'@odata.id'=$odata}|ConvertTo-Json) -ContentType 'application/json'|Out-Null;$r.Action='Updated';$r.Status='Success';$r.Message=$action}catch{$r.Action='Update';$r.Status='Failed';$r.Message=$_.Exception.Message}
    }else{$r.Action='Update';$r.Status='WhatIf';$r.Message="Would $action"}
    $report+=[pscustomobject]$r
}
$report|Export-Csv $ReportPath -NoTypeInformation
$report|Group-Object Status,Action|Select-Object Name,Count|Format-Table -AutoSize
Write-Output "Report written to: $ReportPath"
