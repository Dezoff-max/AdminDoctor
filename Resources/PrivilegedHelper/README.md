# AdminDoctor Privileged Helper

AdminDoctor can scan user-scoped cleanup locations directly and move selected user items to Trash. System cleanup locations such as `/Library/Caches` and `/Library/Logs` are intentionally marked as `requiresHelper` in the main app.

The `AdminDoctorPrivilegedHelper` executable target supports read-only scans, dry-run planning, and reversible quarantine moves for allow-listed system cleanup candidates.

```sh
swift run AdminDoctorPrivilegedHelper scan-system-cleanup
swift run AdminDoctorPrivilegedHelper plan-system-cleanup --path /Library/Caches/example
swift run AdminDoctorPrivilegedHelper quarantine-system-cleanup --path /Library/Caches/example
```

Release bundles copy the helper executable to:

```text
AdminDoctor.app/Contents/Library/LaunchServices/AdminDoctorPrivilegedHelper
```

Release bundles also include the SMAppService LaunchDaemon plist at:

```text
AdminDoctor.app/Contents/Library/LaunchDaemons/dev.admindoctor.AdminDoctorPrivilegedHelper.plist
```

The plist uses `BundleProgram` and exposes the Mach service `dev.admindoctor.AdminDoctorPrivilegedHelper`. The main app can register/unregister the daemon with `SMAppService.daemon(plistName:)` and call the helper through XPC after macOS enables the daemon.

For production signing, build with a valid Developer ID or development signing identity:

```sh
CODE_SIGN_IDENTITY="Developer ID Application: Example Team (TEAMID)" ./script/build_dmg.sh
```

This Mac currently needs a valid code signing identity before the helper can be approved as a production signed daemon.

Privileged cleanup is intentionally narrow:

- only paths found by the current allow-listed system cleanup scan are eligible
- symbolic links and paths outside the allow-list are rejected
- dry-run planning is available before action
- quarantine moves go to `/Users/Shared/AdminDoctor/PrivilegedCleanup`
- JSONL audit events are written to `/Library/Logs/AdminDoctor/privileged-helper-audit.jsonl`
- irreversible deletion is not implemented

This keeps the tool useful for admins without silently crossing into unsafe root file operations.
