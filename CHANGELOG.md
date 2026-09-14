# Changelog

## 1.0.0 - 2026-09-14

Initial standalone release of the rebuilt Defender-Enrollment project.

- Consolidated the recovered Defender, Intune and Microsoft Graph PowerShell work into normal versioned files.
- Sanitised internal hostnames, paths, identifiers, tenant-specific values and credentials.
- Refactored the Defender/Trend migration helper with `SupportsShouldProcess`, safer logging and a corrected Windows Server 2016 check.
- Added app-only and delegated Intune scope-tag scripts.
- Added read-only Defender GPO audit tooling.
- Added generic Intune category assignment and Tier0..Tier5 assignment workflows.
- Added the later defensive CMDB-to-Intune tiering implementation.
- Added MDE Tier0..Tier5 tag synchronisation with retry/backoff.
- Added Defender health reporting, examples, permissions documentation, security notes and GitHub Actions syntax validation.
- Added a ParrotOS-friendly helper that creates a brand-new GitHub repository and pushes the initial release.
