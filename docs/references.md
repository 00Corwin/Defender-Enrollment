# Microsoft references

These links are used to validate the public interfaces and permissions used by the scripts.

- Defender for Endpoint API overview: https://learn.microsoft.com/en-us/defender-endpoint/api/apis-intro
- Defender for Endpoint API endpoints and token audience guidance: https://learn.microsoft.com/en-us/defender-endpoint/api/exposed-apis-create-app-partners
- List machines API: https://learn.microsoft.com/en-us/defender-endpoint/api/get-machines
- Add or remove a machine tag: https://learn.microsoft.com/en-us/defender-endpoint/api/add-or-remove-machine-tags
- Intune / Defender security settings management: https://learn.microsoft.com/en-us/intune/device-security/microsoft-defender/security-settings-management
- Configure Intune and Defender for Endpoint integration: https://learn.microsoft.com/en-us/intune/device-security/microsoft-defender/configure-integration
- Microsoft Graph deviceCategory resource: https://learn.microsoft.com/en-us/graph/api/resources/intune-onboarding-devicecategory?view=graph-rest-1.0
- Microsoft Graph list deviceCategories: https://learn.microsoft.com/en-us/graph/api/intune-onboarding-devicecategory-list?view=graph-rest-1.0
- Microsoft Graph roleScopeTags (beta): https://learn.microsoft.com/en-us/graph/api/intune-rbac-rolescopetag-list?view=graph-rest-beta

## API-version note

The server scope-tag scripts retain the recovered project approach based on Microsoft Graph `/beta`. Microsoft documents `/beta` as subject to more frequent change and recommends v1.0 when an equivalent API is available. Validate these scripts in a test scope before production use.
