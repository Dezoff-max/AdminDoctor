# Security Policy

AdminDoc is designed for local read-only diagnostics plus explicitly confirmed, reversible admin utilities.

## Supported Versions

AdminDoc is pre-1.0. Security fixes are accepted on `main` until release branches exist.

## Reporting A Vulnerability

Do not open a public issue with sensitive host data or an exploit report.

Please report vulnerabilities privately through GitHub Security Advisories when the repository is available. Include:

- affected version or commit
- steps to reproduce
- expected impact
- whether sensitive data may be exposed

## Privacy Expectations

AdminDoc must not:

- request sudo in the MVP
- run irreversible cleanup commands
- upload reports
- phone home
- collect telemetry
- export personal data without default redaction

Safe cleanup utilities must:

- scan before acting
- operate only on configured user-scoped paths
- show item names, paths, and size estimates before action
- require explicit user confirmation
- move selected items to Trash instead of permanently deleting them
- keep system paths and privileged locations out of scope

## Sensitive Test Data

Use fake fixture values only. Never commit real serial numbers, usernames, hostnames, Wi-Fi SSIDs, local IPs tied to a person or company, tokens, passwords, or customer identifiers.
