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

## v0.1.1 - Safe Storage Cleanup

- [x] Add scan-first storage cleanup panel.
- [x] Limit cleanup to user-scoped cache, temporary, log, and installer/archive locations.
- [x] Preselect conservative cleanup candidates.
- [x] Require user confirmation before cleanup.
- [x] Move selected items to Trash instead of permanently deleting them.
- [x] Add cleanup service tests for scope and age filtering.

## v0.1.2 - Admin Authorization And Network Cache

- [x] Request administrator authorization at app launch through macOS Authorization Services.
- [x] Keep authorization state in memory for the current app session.
- [x] Show admin authorization status in the dashboard header.
- [x] Add a Network button to clear the local DNS cache.
- [x] Add reproducible app and DMG icon generation.
- [x] Avoid shell `sudo` execution.

## v0.2.0 - Admin Toolkit Foundation

- [ ] Add a tools sidebar model separate from diagnostic categories.
- [ ] Add action audit trail for any non-read-only utility operation.
- [ ] Add per-tool risk labels: read-only, reversible, privileged-later.
- [ ] Add dry-run summaries for every future action.
- [ ] Add local-only preferences for defaults and retention windows.
- [ ] Add a signed privileged helper for operations that truly need root.

## v0.3.0 - MDM And Profiles

- [ ] Replace profile count heuristics with structured profile parsing where available.
- [ ] Detect user vs device profiles.
- [ ] Highlight expired, unsigned, or untrusted profile payloads when detectable without sudo.
- [ ] Add profile parser fixtures from multiple macOS versions.
- [ ] Document privacy behavior for profile payload fields.

## v0.4.0 - Launchd Inspector

- [ ] Parse launchd labels, program paths, and disabled state.
- [ ] Detect missing executable paths.
- [ ] Detect duplicate labels across LaunchAgents and LaunchDaemons.
- [ ] Add launchd fixtures for valid, invalid, and broken plists.
- [ ] Add filtering by system, local admin, and current user paths.

## v0.5.0 - Log Playbooks

- [ ] Add predefined unified log query previews for common admin issues:
  - [ ] Wi-Fi
  - [ ] login
  - [ ] software update
  - [ ] FileVault
  - [ ] MDM
- [ ] Require an export preview before any logs are included.
- [ ] Limit log collection by time range.
- [ ] Redact sensitive log output before export.

## v0.6.0 - Support Bundle

- [ ] Export ZIP support bundle.
- [ ] Include Markdown report, JSON report, selected logs, and diagnostic metadata.
- [ ] Add export preview before writing files.
- [ ] Add bundle size estimate.
- [ ] Add redaction summary.

## v0.7.0 - Swiss Army Admin Tools

- [ ] Network quick tests: DNS lookup, ping, route, captive portal signal, proxy reachability.
- [ ] Permissions inspector: app TCC status, Full Disk Access signal, accessibility permission signal.
- [ ] App inventory: signed/notarized status, quarantine flag, architecture, last opened date.
- [ ] Login items and background services inspector.
- [ ] Software Update and Rosetta status.
- [ ] Certificate and keychain expiration review without exporting secrets.
- [ ] Local account posture: secure token, admin membership, password age signals where available without sudo.
- [ ] Report comparison for before/after troubleshooting.

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
