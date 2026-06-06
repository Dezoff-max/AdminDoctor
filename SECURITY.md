# Security Policy

AdminDoc is designed for local read-only diagnostics.

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
- run destructive commands
- upload reports
- phone home
- collect telemetry
- export personal data without default redaction

## Sensitive Test Data

Use fake fixture values only. Never commit real serial numbers, usernames, hostnames, Wi-Fi SSIDs, local IPs tied to a person or company, tokens, passwords, or customer identifiers.
