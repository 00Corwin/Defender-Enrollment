<#
.SYNOPSIS
    Read-only before/after audit of Defender-related settings defined in selected GPOs.

.DESCRIPTION
    Generates HTML/XML GPO reports and a filtered CSV evidence file. This is definition-level GPO
    evidence, not endpoint Resultant Set of Policy (RSoP).
#>
[CmdletBinding()]
param(
    [ValidateSet('Before','After')][string]$Phase='Before',
    [string]$OutputDir='C:\Temp\DefenderGpoAudit',
    [Parameter(Mandatory)][string[]]$GpoNames,
    [string[]]$PolicyNames=@(
        'Turn off Microsoft Defender Antivirus',
        'Turn off real-time protection',
        'Scan all downloaded files and attachments'
    )
)
Set-StrictMode -Version Latest;$ErrorActionPreference='Stop'
if(-not(Get-Module -ListAvailable GroupPolicy)){throw 'The GroupPolicy module is required.'}
Import-Module GroupPolicy
New-Item -ItemType Directory -Path $OutputDir -Force|Out-Null
$evidence=@()
foreach($gpoName in $GpoNames){
    try{$gpo=Get-GPO -Name $gpoName -ErrorAction Stop}catch{Write-Warning "GPO not found: $gpoName";$evidence+=[pscustomobject]@{Phase=$Phase;GpoName=$gpoName;PolicyName='';Found=$false;State='';Details='';Error=$_.Exception.Message};continue}
    $safe=($gpoName -replace '[^A-Za-z0-9._-]','_')
    $html=Join-Path $OutputDir "$safe-$Phase.html";$xml=Join-Path $OutputDir "$safe-$Phase.xml"
    Get-GPOReport -Guid $gpo.Id -ReportType Html -Path $html
    Get-GPOReport -Guid $gpo.Id -ReportType Xml -Path $xml
    [xml]$doc=Get-Content $xml -Raw
    $flat=$doc.OuterXml
    foreach($policy in $PolicyNames){
        $found=$flat -match [regex]::Escape($policy)
        $evidence+=[pscustomobject]@{Phase=$Phase;GpoName=$gpoName;PolicyName=$policy;Found=$found;State=if($found){'Defined or referenced'}else{'Not found'};Details="Review $safe-$Phase.html/xml for exact configured value.";Error=''}
    }
}
$csv=Join-Path $OutputDir "Defender-GPO-Validation-$Phase.csv"
$evidence|Export-Csv $csv -NoTypeInformation
$evidence|Format-Table GpoName,PolicyName,Found -AutoSize
Write-Output "Evidence CSV: $csv"
