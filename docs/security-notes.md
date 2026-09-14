# Security notes

1. **Do not hard-code secrets.** App-only scripts accept the client secret as a `SecureString`. In production, prefer a managed identity, certificate credential or approved secret store.
2. **Use `-WhatIf` first.** Every script that changes endpoint/tenant state implements `SupportsShouldProcess` or a dedicated preview path.
3. **Pilot changes.** Tiering and tagging scripts can affect targeting and administrative scope. Pilot against a small test set before broad deployment.
4. **Review output files.** Reports can contain device names and configuration state. Store them in an appropriate location and do not commit production reports to Git.
5. **Trend Micro removal can be disruptive.** Vendor uninstall behaviour differs by version and policy. The migration helper deliberately avoids forcing reboots and blocks Server 2016 removal when a pending reboot is detected unless explicitly overridden.
6. **Direct Defender registry changes are legacy migration behaviour.** Policy, tamper protection or modern MDE management can override local changes. Prefer supported Microsoft policy/onboarding methods where available.
7. **Intune `/beta` APIs can change.** The scope-tag automation intentionally retains the original project approach but should be validated before production use.
