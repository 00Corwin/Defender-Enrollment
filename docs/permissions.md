# Permissions and prerequisites

## Microsoft Graph - delegated scripts

### Device category assignment

Required delegated Graph permission:

- `DeviceManagementManagedDevices.ReadWrite.All`

The original project also used `DeviceManagementServiceConfig.Read.All` / `ReadWrite.All` for category discovery/creation. Current Graph documentation places device-category read/write capability under managed-device permissions, but tenants and SDK versions can differ. Grant only the least privilege that works in your environment.

### Server scope-tag scripts

The original project used:

- `DeviceManagementManagedDevices.ReadWrite.All`
- `DeviceManagementRBAC.Read.All`
- `Directory.Read.All`

`Directory.Read.All` is used to resolve Entra device operating-system information from the Intune device's Entra device ID.

## Microsoft Graph - app-only scripts

Grant the equivalent **Application** permissions and provide admin consent. Use a dedicated app registration rather than reusing a broad automation identity.

## Microsoft Defender for Endpoint API

`Sync-MdeTierTags.ps1` requires the WindowsDefenderATP / Defender for Endpoint application permission:

- `Machine.ReadWrite.All`

Admin consent is required.

The script obtains a client-credentials token for the Defender API and writes tags using the machine tags endpoint. For permissions defined under the WindowsDefenderATP resource, current Microsoft guidance uses `https://api.securitycenter.microsoft.com/.default` as the token scope even though requests are sent to `https://api.security.microsoft.com`.

## Group Policy audit

`Audit-DefenderGpo.ps1` requires:

- Windows PowerShell/PowerShell on a management host with the `GroupPolicy` module
- Permission to read the target GPOs

It is read-only.

## Defender migration helper

Run elevated on the target Windows Server. It expects Defender PowerShell cmdlets such as `Get-MpComputerStatus` and `Get-MpPreference` to be present. Trend Micro removal still depends on the vendor's local uninstall utility and any password/tamper controls configured in the environment.
