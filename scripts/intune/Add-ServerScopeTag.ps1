<#
.SYNOPSIS
    Delegated assignment of an existing Intune scope tag to Windows Server devices.

.DESCRIPTION
    Resolves the scope tag by display name, detects Windows Server by reading the corresponding
    Entra device operatingSystem, retrieves per-device roleScopeTagIds and appends the tag.

.PERMISSIONS
    DeviceManagementManagedDevices.ReadWrite.All
    DeviceManagementRBAC.Read.All
    Directory.Read.All
#>
[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [string]$ScopeTagName='Microsoft Defender for Server',
    [int]$SleepMs=300,
    [string]$ReportPath=".\ServerScopeTag_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
)
Set-StrictMode -Version Latest;$ErrorActionPreference='Stop'
if(-not(Get-Module -ListAvailable Microsoft.Graph.Authentication)){throw 'Microsoft.Graph PowerShell SDK is required.'}
Import-Module Microsoft.Graph.Authentication
Connect-MgGraph -Scopes @('DeviceManagementManagedDevices.ReadWrite.All','DeviceManagementRBAC.Read.All','Directory.Read.All') -NoWelcome|Out-Null

function Get-GraphCollection {
    param([string]$Uri)
    $all=@(); while($Uri){$x=Invoke-MgGraphRequest -Method GET -Uri $Uri;if($x.value){$all+=$x.value};$Uri=$x.'@odata.nextLink'}; $all
}
function Get-EntraOperatingSystem {
    param([string]$AzureAdDeviceId)
    if([string]::IsNullOrWhiteSpace($AzureAdDeviceId)){return $null}
    $escaped=$AzureAdDeviceId.Replace("'","''")
    try{(Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/devices(deviceId='$escaped')?`$select=deviceId,displayName,operatingSystem").operatingSystem}catch{$null}
}
function Add-ScopeTagToServers {
    param([string]$ScopeTagName,[int]$SleepMs,[string]$ReportPath)
    $beta='https://graph.microsoft.com/beta'
    $tags=Get-GraphCollection "$beta/deviceManagement/roleScopeTags"
    $tag=@($tags|Where-Object{$_.displayName -eq $ScopeTagName})
    if($tag.Count -ne 1){throw "Expected one scope tag named '$ScopeTagName'; found $($tag.Count)."}
    $tag=$tag[0]
    $devices=Get-GraphCollection "$beta/deviceManagement/managedDevices?`$select=id,deviceName,azureADDeviceId,lastSyncDateTime"
    $report=@()
    foreach($d in $devices){
        $os=Get-EntraOperatingSystem $d.azureADDeviceId
        if($os -notmatch 'Windows Server'){continue}
        $r=[ordered]@{DeviceName=$d.deviceName;ManagedDeviceId=$d.id;AzureAdDeviceId=$d.azureADDeviceId;OperatingSystem=$os;ScopeTagName=$ScopeTagName;CurrentScopeTags='';ResultScopeTags='';Action='';Status='';ErrorDetail=''}
        try{
            $detail=Invoke-MgGraphRequest -Method GET -Uri "$beta/deviceManagement/managedDevices('$($d.id)')?`$select=id,deviceName,roleScopeTagIds"
            $current=@($detail.roleScopeTagIds);$r.CurrentScopeTags=($current -join ';')
            if($current -contains $tag.id){$r.Action='NoChange';$r.Status='Success';$r.ResultScopeTags=$r.CurrentScopeTags}
            else{
                $merged=@($current + $tag.id | Select-Object -Unique);$r.ResultScopeTags=($merged -join ';')
                if($PSCmdlet.ShouldProcess($d.deviceName,"Add Intune scope tag '$ScopeTagName'")){
                    Invoke-MgGraphRequest -Method PATCH -Uri "$beta/deviceManagement/managedDevices('$($d.id)')" -Body (@{roleScopeTagIds=$merged}|ConvertTo-Json) -ContentType 'application/json'|Out-Null
                    $r.Action='Add';$r.Status='Success'
                }else{$r.Action='Add';$r.Status='WhatIf'}
            }
        }catch{$r.Action='Error';$r.Status='Failed';$r.ErrorDetail=$_.Exception.Message}
        $report+=[pscustomobject]$r
        if($SleepMs -gt 0){Start-Sleep -Milliseconds $SleepMs}
    }
    $report|Export-Csv $ReportPath -NoTypeInformation
    $report|Group-Object Status,Action|Select-Object Name,Count|Format-Table -AutoSize
    Write-Output "Report: $ReportPath"
}

Add-ScopeTagToServers -ScopeTagName $ScopeTagName -SleepMs $SleepMs -ReportPath $ReportPath
