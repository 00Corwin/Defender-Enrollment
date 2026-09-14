# Defender-Enrollment

PowerShell tooling for Microsoft Defender for Endpoint (MDE) migration, validation, Intune device classification and MDE tier tagging.

This repository consolidates the recovered Defender, Intune and Microsoft Graph PowerShell work into a clean, standalone project. It includes sanitised examples, documented permissions, usage guidance and syntax validation through GitHub Actions.

> **Important:** These scripts perform administrative changes to Defender, Intune and Microsoft Graph. Test in a non-production scope first, use `-WhatIf` where provided and review every permission before granting admin consent.


## Create a new GitHub repository

This package is intentionally independent of any previous Git repository. On ParrotOS, authenticate `gh`, extract the package, then run:

```bash
chmod +x ./create-new-github-repo.sh
./create-new-github-repo.sh public
```

Use `private` instead of `public` if required. See [CREATE_NEW_GITHUB_REPO.md](CREATE_NEW_GITHUB_REPO.md) for the full process.

## What is included

| Area | Script | Purpose | Origin |
|---|---|---|---|
| Defender migration | `scripts/defender/Enable-DefenderAndRemoveTrend.ps1` | Capture pre/post Defender state, optionally force Defender active, set an MDE management tag and launch the Trend Micro removal utility | Recovered, refactored and sanitised |
| Defender reporting | `scripts/defender/Get-DefenderHealthReport.ps1` | Export local Defender health, preferences and detections | Related Defender rollout work |
| Intune scope tags | `scripts/intune/Add-ServerScopeTag.App.ps1` | App-only assignment of an existing Intune scope tag to Windows Server devices | Recovered project script |
| Intune scope tags | `scripts/intune/Add-ServerScopeTag.ps1` | Delegated equivalent of the server scope-tag assignment | Recovered project script |
| GPO audit | `scripts/audit/Audit-DefenderGpo.ps1` | Read-only before/after Defender GPO evidence and CSV output | Recovered project script |
| Intune categories | `scripts/intune/Intune-Category-Assignment.ps1` | Generic CSV-driven category creation/assignment | Recovered project script |
| Intune tiers | `scripts/intune/Set-IntuneTiers.App.ps1` | App-only Tier0..Tier5 assignment | Recovered project script |
| Intune tiers | `scripts/intune/Set-IntuneTiers.ps1` | Delegated Tier0..Tier5 assignment | Recovered project script |
| Intune tiers | `scripts/intune/Set-IntuneDeviceTierFromCMDB.ps1` | More defensive CMDB-to-Intune implementation with aliases, serial matching and reporting | Later reusable version recovered from related project material |
| MDE tags | `scripts/mde/Sync-MdeTierTags.ps1` | Sync CMDB Tier0..Tier5 values to MDE device tags | Recovered project script |

The earlier tiering logic is represented by the newer `Set-IntuneDeviceTierFromCMDB.ps1` implementation. A preserved compatibility version is also included under `legacy/Set-IntuneTiers-v2-Recovered.ps1`.

## Repository layout

```text
Defender-Enrollment/
├── .github/workflows/powershell-parse.yml
├── docs/
│   ├── permissions.md
│   ├── security-notes.md
│   ├── references.md
│   ├── source-map.md
│   └── usage.md
├── examples/
│   ├── cmdb_servers.example.csv
│   ├── device_categories.example.csv
│   ├── gpo_names.example.txt
│   └── mde_tiers.example.csv
├── legacy/
│   └── Set-IntuneTiers-v2-Recovered.ps1
├── scripts/
│   ├── audit/
│   ├── defender/
│   ├── intune/
│   └── mde/
├── CHANGELOG.md
├── CREATE_NEW_GITHUB_REPO.md
├── create-new-github-repo.sh
├── LICENSING.md
└── README.md
```

## Quick start

### 1. Review Defender state only

```powershell
.\scripts\defender\Get-DefenderHealthReport.ps1
```

### 2. Preview the Defender/Trend migration helper

```powershell
.\scripts\defender\Enable-DefenderAndRemoveTrend.ps1 -WhatIf
```

### 3. Preview CMDB tier assignment

```powershell
.\scripts\intune\Set-IntuneDeviceTierFromCMDB.ps1 `
  -CsvPath .\examples\cmdb_servers.example.csv `
  -WhatIf
```

### 4. Preview MDE tier-tag sync

```powershell
$secret = Read-Host 'Client secret' -AsSecureString
.\scripts\mde\Sync-MdeTierTags.ps1 `
  -CsvPath .\examples\mde_tiers.example.csv `
  -TenantId '<tenant-guid>' `
  -ClientId '<app-guid>' `
  -ClientSecret $secret `
  -WhatIf
```

## Current Microsoft platform notes

For cloud-native and Intune-managed Windows endpoints, Microsoft currently recommends Intune as the preferred MDE onboarding approach. Microsoft also provides a Defender deployment tool for supported Windows onboarding/offboarding scenarios. The scripts here are best treated as migration, classification, validation and operational automation rather than a replacement for the current Microsoft onboarding workflow.

Some of the original scope-tag automation uses the Intune `/beta` API and updates `roleScopeTagIds` on managed devices. That pattern has existed in real-world automation, but Microsoft documents parts of the managed-device scope-tag surface inconsistently and `/beta` is subject to change. Use the scope-tag scripts with `-WhatIf` first and validate against your tenant.

## Sanitisation

The rebuild removes internal server names, UNC paths, tenant/application IDs, company-specific identifiers, change numbers and credentials. Example files use synthetic hostnames only. Secrets are accepted as `SecureString` parameters and are never committed.

## Requirements

See [docs/permissions.md](docs/permissions.md) for the Graph/MDE permissions used by each script, [docs/usage.md](docs/usage.md) for examples, and [docs/references.md](docs/references.md) for the Microsoft interfaces used by the rebuild.

## Licence

No open-source licence is granted by default. See [LICENSING.md](LICENSING.md).
