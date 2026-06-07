# AdminDoc

AdminDoc is a privacy-first macOS diagnostic and admin utility app for system administrators, helpdesk engineers, and Mac fleet maintainers.

The app runs local checks, explains findings clearly, offers carefully scoped safe utilities, and exports a redacted support report that can be shared without exposing unnecessary personal data.

## Installation

English:

1. Download `AdminDoc.dmg` from the latest GitHub Release.
2. Open the DMG and drag `AdminDoc.app` to Applications.
3. If macOS blocks this unsigned build, prefer Control-clicking `AdminDoc.app`, choosing **Open**, then confirming **Open**.
4. Internal/testing workaround only: if your organization allows temporarily disabling Gatekeeper, run:

```sh
sudo spctl --master-disable
```

Open AdminDoc, then re-enable Gatekeeper immediately:

```sh
sudo spctl --master-enable
```

Русский:

1. Скачайте `AdminDoc.dmg` из последнего GitHub Release.
2. Откройте DMG и перетащите `AdminDoc.app` в папку «Программы».
3. Если macOS блокирует неподписанную сборку, сначала используйте более безопасный вариант: Control-click / правый клик по `AdminDoc.app`, выберите **Открыть**, затем подтвердите **Открыть**.
4. Только для внутреннего тестирования: если политика вашей организации разрешает временно отключить Gatekeeper, выполните:

```sh
sudo spctl --master-disable
```

Откройте AdminDoc, затем сразу включите Gatekeeper обратно:

```sh
sudo spctl --master-enable
```

## Principles

- Diagnostics are read-only.
- Cleanup actions are explicit, scoped, and move items to Trash instead of permanently deleting them.
- The app requests administrator authorization at launch for admin utility actions.
- No shell `sudo` execution.
- No telemetry or network upload.
- All diagnostics run locally.
- Report exports redact personal data by default.
- Findings should be useful to real Mac admins, not just dashboard decoration.

## MVP Scope

AdminDoc is a SwiftPM-based native macOS SwiftUI app with a reusable `AdminDocCore` library.

Implemented categories:

- System
- Storage
- Security
- Network
- MDM & Profiles
- Launch Services
- Logs

Implemented checks:

- macOS version and build
- uptime
- hardware model
- architecture
- system volume free space
- APFS status from structured `diskutil` plist output
- FileVault status
- SIP status
- Gatekeeper status
- application firewall status when available
- active network interfaces
- DNS nameservers
- default gateway
- system proxy state
- Wi-Fi SSID signal when available
- MDM enrollment signal
- installed configuration profile signal
- LaunchAgent and LaunchDaemon plist validation
- explicit MVP log collection policy

Safe utility actions:

- scan user cache, app container cache, temporary, user log, installer/archive, developer cache, and package manager cache locations
- preselect only conservative cleanup candidates
- require confirmation before cleanup
- move selected items to Trash for review or restore
- clear the local DNS cache with `dscacheutil -flushcache`

## Privacy

Markdown and JSON exports are redacted by default. The redactor currently handles:

- username
- hostname
- serial number when available
- local IPv4 addresses
- link-local IPv6 addresses
- MAC addresses
- Wi-Fi SSID when present in diagnostic results

AdminDoc does not upload reports, phone home, or collect analytics. Administrator authorization is requested locally through macOS Authorization Services and kept only for the current app session. Cleanup tools do not scan arbitrary paths or change network services.

## Architecture

```text
Sources/
  AdminDoc/
    App/
    Views/
  AdminDocCore/
    Models/
    Providers/
    Services/
    Support/
Tests/
  AdminDocCoreTests/
```

Key boundaries:

- SwiftUI views live in `Sources/AdminDoc`.
- Diagnostic logic lives in `Sources/AdminDocCore`.
- Command execution goes through `CommandRunning`.
- `ProcessRunner` rejects shell and sudo executables and runs fixed executable paths with arguments.
- Administrator authorization state is handled by `AdminPrivilegeManager`.
- Safe cleanup logic lives in `DiskCleanupService` and only operates on configured user-scoped locations.
- Providers are small and independently testable.
- Report export is handled by `ReportExporter`.

## Development

Build and test:

```sh
swift build
swift test
```

Run as a macOS app bundle:

```sh
./script/build_and_run.sh
```

Regenerate icons and build a local DMG:

```sh
./script/generate_icons.sh
./script/build_dmg.sh
```

The app and DMG icons are generated locally from `Resources/Icons/AdminDocIconSource.png`. `script/render_icon.swift` is a fallback source generator if the PNG is missing; generated `.icns` and `.iconset` outputs are intentionally ignored by git.

The Codex app Run button is wired through `.codex/environments/environment.toml`.

## Reports

The app exports:

- Markdown support report
- JSON support report

ZIP support bundles are intentionally left for a later milestone because they need preview, size estimates, and stricter redaction review.

## Status

AdminDoc is an early MVP skeleton. It is useful for local first-pass diagnostics, but not yet a replacement for a signed, notarized admin support utility.

See [ROADMAP.md](./ROADMAP.md) for next milestones.

## License

MIT License. See [LICENSE](./LICENSE).
