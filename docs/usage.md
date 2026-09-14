# Usage

## Defender migration / Trend removal

Preview only:

```powershell
.\scripts\defender\Enable-DefenderAndRemoveTrend.ps1 -WhatIf
```

Run with the default MDE management tag and attempt Trend removal:

```powershell
.\scripts\defender\Enable-DefenderAndRemoveTrend.ps1
```

Skip Trend removal and only capture state / apply selected Defender changes:

```powershell
.\scripts\defender\Enable-DefenderAndRemoveTrend.ps1 -SkipTrendRemoval
```

## Defender GPO audit

```powershell
$gpos = Get-Content .\examples\gpo_names.example.txt
.\scripts\audit\Audit-DefenderGpo.ps1 -Phase Before -GpoNames $gpos
# make the approved GPO change
.\scripts\audit\Audit-DefenderGpo.ps1 -Phase After -GpoNames $gpos
```

## Generic Intune category assignment

```powershell
.\scripts\intune\Intune-Category-Assignment.ps1 `
  -CsvPath .\examples\device_categories.example.csv `
  -CreateMissingCategories `
  -WhatIf
```

## CMDB Tier0..Tier5 assignment

```powershell
.\scripts\intune\Set-IntuneDeviceTierFromCMDB.ps1 `
  -CsvPath .\examples\cmdb_servers.example.csv `
  -CreateMissingCategories `
  -WhatIf
```

## App-only Tier assignment

```powershell
$secret = Read-Host 'Client secret' -AsSecureString
.\scripts\intune\Set-IntuneTiers.App.ps1 `
  -CsvPath .\examples\cmdb_servers.example.csv `
  -TenantId '<tenant-guid>' `
  -ClientId '<app-guid>' `
  -ClientSecret $secret `
  -WhatIf
```

## MDE tier tags

```powershell
$secret = Read-Host 'Client secret' -AsSecureString
.\scripts\mde\Sync-MdeTierTags.ps1 `
  -CsvPath .\examples\mde_tiers.example.csv `
  -TenantId '<tenant-guid>' `
  -ClientId '<app-guid>' `
  -ClientSecret $secret `
  -WhatIf
```


## Legacy Intune Tier v2 compatibility

The recovered issue #9 CSV shape used `name,u_tier`. Blank `u_tier` values intentionally leave the device unchanged.

```powershell
.\legacy\Set-IntuneTiers-v2-Recovered.ps1 `
  -CsvPath .\legacy-tier-input.csv `
  -WhatIf
```
