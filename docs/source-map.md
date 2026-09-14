# Source map

The original repository contained only a README. The substantive project code had been stored as GitHub issues. This rebuild converts that backlog into normal repository files.

| Original issue | Original title | Rebuilt file |
|---:|---|---|
| #1 | Codebase | `scripts/defender/Enable-DefenderAndRemoveTrend.ps1` |
| #2 | server scope tag | `scripts/intune/Add-ServerScopeTag.App.ps1` |
| #3 | Server scope tag non-app | `scripts/intune/Add-ServerScopeTag.ps1` |
| #4 | Audit Report GPO | `scripts/audit/Audit-DefenderGpo.ps1` |
| #5 | Intune Cat Assign | `scripts/intune/Intune-Category-Assignment.ps1` |
| #6 | Intune Tier App | `scripts/intune/Set-IntuneTiers.App.ps1` |
| #7 | Intune Tier Delegated | `scripts/intune/Set-IntuneTiers.ps1` |
| #8 | Intune Tier Original | functionally represented by `Set-IntuneTiers.ps1` |
| #9 | Intune Tier v2 | later defensive implementation: `Set-IntuneDeviceTierFromCMDB.ps1`; recovered compatibility version under `legacy/` |
| #10 | Sync MDE Tier Tags | `scripts/mde/Sync-MdeTierTags.ps1` |

## Recovery notes

- Issue #1 was sufficiently detailed to preserve the original workflow while refactoring unsafe hard-coded paths and fixing obvious robustness problems.
- Issues #2-#10 documented the intended parameters, authentication model, permissions and behaviour. The public rebuild re-implements those behaviours as clean standalone scripts rather than copying tenant-specific code verbatim.
- The later CMDB-to-Intune tiering implementation was recovered from related project material and is included because it is more defensive than the early Tier scripts. It has been polished for the public repository while preserving the recovered matching, tier-normalisation, WhatIf and reporting behaviour.
- Internal company names, hostnames, UNC paths, tenant IDs, app IDs and secrets are not included.

## Intentional safety changes in the public rebuild

The recovered issue #1 workflow included two direct `Set-MpPreference` changes (`DisableEmailScanning=$false` and `RealTimeScanDirection=2`) after the Trend Micro removal step. They are retained in the recovered evidence/history but are **not** applied automatically by the refactored public migration helper because endpoint policy should normally be controlled through the approved Defender/Intune/GPO management path. The refactored script still records both values in its pre/post evidence.

The recovered issue #1 workflow also used an internal UNC export path and interactive Server 2016 handling. The public rebuild replaces the UNC path with a local `%ProgramData%` log directory and uses explicit safety switches instead of an interactive prompt.
