# Roadmap

AdminDoctor is a privacy-first macOS diagnostics app for system administrators, helpdesk engineers, and Mac fleet maintainers.

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
- [x] Group storage cleanup candidates by source.
- [x] Add cleanup risk labels: safe, caution, manual review, helper required.
- [x] Show system cache and log cleanup candidates as helper-required read-only findings.
- [x] Add a read-only privileged helper scaffold for future system cleanup.
- [x] Keep broad app container scans out of the default GUI path until Full Disk Access/helper support is designed.
- [x] Add reproducible app and DMG icon generation.
- [x] Avoid shell `sudo` execution.

## v0.1.5 - LAN Scanner Vendor Lookup

- [x] Add Advanced IP Scanner-style local LAN table.
- [x] Auto-detect the active LAN interface instead of selecting VPN/tunnel interfaces.
- [x] Scan the local /24 around this Mac and read `arp -an`.
- [x] Bundle IEEE MA-L, MA-M, and MA-S CSV data for offline manufacturer lookup.
- [x] Mark locally administered/randomized MAC addresses as private instead of guessing a manufacturer.
- [x] Add a clear button for LAN scan results and filters.

## v0.1.6 - Read-only Resource And Security Signals

- [x] Add Darwin kernel version to System diagnostics.
- [x] Add CPU load average and logical CPU context.
- [x] Add memory pressure snapshot from `vm_stat`.
- [x] Add top CPU process snapshot.
- [x] Warn when system volume usage exceeds 80%.
- [x] Add SSD/NVMe SMART health from structured `diskutil` data when available.
- [x] Add XProtect and MRT version signals.
- [x] Add Software Update security setting signals.
- [x] Add recent Apple security-related install history.

## v0.1.7 - AdminDoctor Rename And Toolkit UI

- [x] Rename the app, Swift package, targets, bundle, docs, scripts, and release artifacts to AdminDoctor.
- [x] Add EN/RUS language switching in the sidebar.
- [x] Add compact CPU, RAM, disk, and network resource indicators.
- [x] Add local scan history with status counts and warning hints.
- [x] Add user-initiated ping and traceroute tools in Network.
- [x] Update GitHub Actions checkout to a Node 24-ready action version.

## v0.1.8 - Support Exports And Admin Tools

- [x] Add DNS lookup, route table, captive portal, and proxy reachability tools in Network.
- [x] Add redacted HTML and PDF report export.
- [x] Add TCC Full Disk Access and Accessibility inspector signals.
- [x] Bundle the read-only privileged helper scaffold and show helper install/signature status.
- [x] Set the default macOS window size to 1089 x 894.
- [x] Clean legacy AdminDoc build artifacts from local packaging scripts.

## v0.1.9 - Privileged Helper Flow And LAN Inspector

- [x] Add a launchd plist for `SMAppService.daemon(plistName:)` registration.
- [x] Add privileged XPC protocol wiring and a read-only helper service.
- [x] Add app controls to register, unregister, refresh, and ping the helper.
- [x] Add build-script signing hooks for app and helper bundles.
- [x] Improve LAN scan with Bonjour/mDNS name hints.
- [x] Probe common local ports and infer device type from gateway, vendor, hostname, and ports.
- [x] Add type and open-port columns to the LAN table.
- [x] Add horizontal scrolling to the LAN results table.
- [x] Add export preview sheets for Markdown, JSON, HTML, and PDF before saving.

## v0.1.10 - Signed Release Prep And Admin Exports

- [x] Add GitHub Actions workflow for signed and notarized DMG releases.
- [x] Add local notarization script using `xcrun notarytool` and stapling validation.
- [x] Add privileged helper dry-run and quarantine actions for allow-listed system cleanup candidates.
- [x] Add JSONL audit events for privileged helper cleanup actions.
- [x] Add External IP as an explicit user-triggered network probe.
- [x] Add LAN CSV export with readable port service names.
- [x] Improve HTML report styling and PDF rendering.
- [x] Add multiple GitHub README screenshots.

## v0.2.0 - Admin Toolkit Foundation

- [ ] Add a tools sidebar model separate from diagnostic categories.
- [x] Add action audit trail for helper quarantine cleanup.
- [ ] Add action audit trail for every non-read-only utility operation.
- [ ] Add per-tool risk labels: read-only, reversible, privileged-later.
- [x] Add dry-run summaries for helper cleanup.
- [ ] Add dry-run summaries for every future action.
- [ ] Add local-only preferences for defaults and retention windows.
- [ ] Ship signed and notarized privileged-helper releases for operations that truly need root.

## v0.3.0 - MDM And Profiles

- [ ] Replace profile count heuristics with structured profile parsing where available.
- [ ] Detect user vs device profiles.
- [ ] Highlight expired, unsigned, or untrusted profile payloads when detectable without sudo.
- [ ] Add profile parser fixtures from multiple macOS versions.
- [ ] Document privacy behavior for profile payload fields.

## v0.4.0 - Launchd Inspector

- [x] Parse launchd labels, program paths, and disabled state.
- [x] Detect missing executable paths.
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

- [x] Network quick tests: ping and traceroute.
- [x] Network quick tests: DNS lookup, route, captive portal signal, proxy reachability.
- [x] Permissions inspector: app TCC status, Full Disk Access signal, accessibility permission signal.
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

- [ ] CLI companion: `admindoctor`.
- [ ] Compare two reports.
- [ ] Fleet baseline templates.
- [ ] Jamf, Kandji, Mosyle, and Intune-oriented check presets.
- [ ] Offline rule packs.
- [ ] HTML report export.
- [ ] Sparkle update feed for signed builds.
