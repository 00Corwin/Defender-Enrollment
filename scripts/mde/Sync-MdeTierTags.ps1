<#
.SYNOPSIS
    Syncs CMDB Tier0..Tier5 values to Microsoft Defender for Endpoint machine tags.

.CSV
    Hostname,Tier

.PERMISSIONS
    App registration with WindowsDefenderATP / Defender for Endpoint application permission:
    Machine.ReadWrite.All
#>
[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory)][ValidateScript({Test-Path $_})][string]$CsvPath,
    [Parameter(Mandatory)][string]$TenantId,
    [Parameter(Mandatory)][string]$ClientId,
    [Parameter(Mandatory)][securestring]$ClientSecret,
    [int]$MaxRetries=5,
    [string]$ReportPath=".\MdeTierTagSync_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
)
Set-StrictMode -Version Latest;$ErrorActionPreference='Stop'

function ConvertTo-PlainText {param([securestring]$Secure);$b=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secure);try{[Runtime.InteropServices.Marshal]::PtrToStringBSTR($b)}finally{[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b)}}
function ConvertTo-TierName {param([string]$Value);if([string]::IsNullOrWhiteSpace($Value)){return $null};$v=$Value.Trim().ToLowerInvariant()-replace '[\s_-]','';switch($v){{$_ -in @('0','t0','tier0','zero')}{'Tier0';break};{$_ -in @('1','t1','tier1','one')}{'Tier1';break};{$_ -in @('2','t2','tier2','two')}{'Tier2';break};{$_ -in @('3','t3','tier3','three')}{'Tier3';break};{$_ -in @('4','t4','tier4','four')}{'Tier4';break};{$_ -in @('5','t5','tier5','five')}{'Tier5';break};default{$null}}}
function Invoke-WithRetry {
    param([scriptblock]$Operation,[int]$Retries=$MaxRetries)
    for($attempt=0;$attempt -le $Retries;$attempt++){
        try{return & $Operation}catch{
            $status=$null
            if($_.Exception.Response -and $_.Exception.Response.StatusCode){$status=[int]$_.Exception.Response.StatusCode}
            $transient=($status -eq 429 -or ($status -ge 500 -and $status -lt 600))
            if(-not $transient -or $attempt -ge $Retries){throw}
            $delay=[math]::Min(60,[math]::Pow(2,$attempt+1));Start-Sleep -Seconds $delay
        }
    }
}

$plain=ConvertTo-PlainText $ClientSecret
try{
    $tokenBody=@{client_id=$ClientId;client_secret=$plain;scope='https://api.securitycenter.microsoft.com/.default';grant_type='client_credentials'}
    $token=(Invoke-RestMethod -Method POST -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Body $tokenBody -ContentType 'application/x-www-form-urlencoded').access_token
}finally{$plain=$null}
$headers=@{Authorization="Bearer $token"}
$api='https://api.security.microsoft.com/api'
$rows=Import-Csv $CsvPath
if(-not $rows){throw 'CSV contains no rows.'}
if($rows[0].PSObject.Properties.Name -notcontains 'Hostname' -or $rows[0].PSObject.Properties.Name -notcontains 'Tier'){throw 'CSV must contain Hostname,Tier.'}
$report=@()
foreach($row in $rows){
    $host=[string]$row.Hostname;$tier=ConvertTo-TierName $row.Tier;$r=[ordered]@{Hostname=$host;SourceTier=$row.Tier;TargetTier=$tier;MachineId='';CurrentTierTags='';RemovedTags='';AddedTag='';Status='';Message=''}
    if(-not $tier){$r.Status='Failed';$r.Message='Blank or invalid tier.';$report+=[pscustomobject]$r;continue}
    try{
        $escaped=$host.Replace("'","''")
        $uri="$api/machines?`$filter=computerDnsName eq '$escaped'"
        $machines=@((Invoke-WithRetry {Invoke-RestMethod -Method GET -Uri $uri -Headers $headers}).value)
        if($machines.Count -eq 0){$r.Status='Failed';$r.Message='MDE machine not found.';$report+=[pscustomobject]$r;continue}
        $m=$machines|Sort-Object lastSeen -Descending|Select-Object -First 1;$r.MachineId=$m.id
        $current=@($m.machineTags|Where-Object{$_ -match '^Tier[0-5]$'});$r.CurrentTierTags=$current -join ';'
        $remove=@($current|Where-Object{$_ -ne $tier});$added=$false
        foreach($tag in $remove){
            if($PSCmdlet.ShouldProcess($m.computerDnsName,"Remove MDE tag '$tag'")){
                $body=@{Value=$tag;Action='Remove'}|ConvertTo-Json -Compress
                Invoke-WithRetry {Invoke-RestMethod -Method POST -Uri "$api/machines/$($m.id)/tags" -Headers $headers -ContentType 'application/json' -Body $body}|Out-Null
            }
        }
        if($current -notcontains $tier){
            if($PSCmdlet.ShouldProcess($m.computerDnsName,"Add MDE tag '$tier'")){
                $body=@{Value=$tier;Action='Add'}|ConvertTo-Json -Compress
                Invoke-WithRetry {Invoke-RestMethod -Method POST -Uri "$api/machines/$($m.id)/tags" -Headers $headers -ContentType 'application/json' -Body $body}|Out-Null;$added=$true
            }
        }
        $r.RemovedTags=$remove -join ';';$r.AddedTag=if($added){$tier}else{''};$r.Status=if($WhatIfPreference){'WhatIf'}else{'Success'};$r.Message='Tier tags reconciled.'
    }catch{$r.Status='Failed';$r.Message=$_.Exception.Message}
    $report+=[pscustomobject]$r
}
$report|Export-Csv $ReportPath -NoTypeInformation
$report|Group-Object Status|Select-Object Name,Count|Format-Table -AutoSize
Write-Output "Report: $ReportPath"
