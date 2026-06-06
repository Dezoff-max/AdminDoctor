# Roadmap

AdminDoc is a privacy-first macOS diagnostics app for system administrators, helpdesk engineers, and Mac fleet maintainers.

## v0.1.0 - MVP Diagnostics

- [x] Create native macOS SwiftUI app shell.
- [x] Add dashboard with System, Storage, Security, Network, MDM & Profiles, Launch Services, and Logs sections.
- [x] Implement diagnostic result model with `pass`, `warning`, `fail`, and `info` severities.
- [x] Add read-only command runner wrapper.
- [x] Add system checks:
  - [x] macOS version and build
  - [x] uptime
  - [x] hardware model
  - [x] architecture
- [x] Add storage checks:
  - [x] free disk space
  - [x] APFS summary
- [x] Add security checks:
  - [x] FileVault status
  - [x] SIP status
  - [x] Gatekeeper status
  - [x] firewall status when available
- [x] Add network checks:
  - [x] active interfaces
  - [x] DNS servers
  - [x] default gateway
  - [x] proxy settings
  - [x] Wi-Fi SSID signal when available
- [x] Export report as Markdown.
- [x] Export report as JSON.
- [x] Redact username, hostname, serial number, local IP addresses, MAC addresses, and Wi-Fi SSID by default.
- [x] Add unit tests for redaction and diagnostic parsing.
- [x] Add GitHub Actions CI.

## v0.2.0 - MDM And Profiles

- [ ] Replace profile count heuristics with structured profile parsing where available.
- [ ] Detect user vs device profiles.
- [ ] Highlight expired, unsigned, or untrusted profile payloads when detectable without sudo.
- [ ] Add profile parser fixtures from multiple macOS versions.
- [ ] Document privacy behavior for profile payload fields.

## v0.3.0 - Launchd Inspector

- [ ] Parse launchd labels, program paths, and disabled state.
- [ ] Detect missing executable paths.
- [ ] Detect duplicate labels across LaunchAgents and LaunchDaemons.
- [ ] Add launchd fixtures for valid, invalid, and broken plists.
- [ ] Add filtering by system, local admin, and current user paths.

## v0.4.0 - Log Playbooks

- [ ] Add predefined unified log query previews for common admin issues:
  - [ ] Wi-Fi
  - [ ] login
  - [ ] software update
  - [ ] FileVault
  - [ ] MDM
- [ ] Require an export preview before any logs are included.
- [ ] Limit log collection by time range.
- [ ] Redact sensitive log output before export.

## v0.5.0 - Support Bundle

- [ ] Export ZIP support bundle.
- [ ] Include Markdown report, JSON report, selected logs, and diagnostic metadata.
- [ ] Add export preview before writing files.
- [ ] Add bundle size estimate.
- [ ] Add redaction summary.

## v1.0.0 - Stable Release

- [ ] Harden provider error handling and timeouts.
- [ ] Add accessibility pass for the main UI.
- [ ] Add screenshots and demo GIF.
- [ ] Add signed and notarized release workflow.
- [ ] Add release checklist.
- [ ] Add documentation for admins, contributors, and security reviewers.
- [ ] Tag `v1.0.0` and publish GitHub release.

## Future Ideas

- [ ] CLI companion: `admindoc`.
- [ ] Compare two reports.
- [ ] Fleet baseline templates.
- [ ] Jamf, Kandji, Mosyle, and Intune-oriented check presets.
- [ ] Offline rule packs.
- [ ] HTML report export.
- [ ] Sparkle update feed for signed builds.
