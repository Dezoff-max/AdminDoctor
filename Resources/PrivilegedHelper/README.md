# AdminDoctor Privileged Helper Scaffold

AdminDoctor can scan user-scoped cleanup locations directly and move selected user items to Trash. System cleanup locations such as `/Library/Caches` and `/Library/Logs` are intentionally marked as `requiresHelper` in the main app.

The `AdminDoctorPrivilegedHelper` executable target is a development scaffold for the future signed helper. It currently supports only read-only JSON scanning:

```sh
swift run AdminDoctorPrivilegedHelper scan-system-cleanup
```

Release bundles copy the helper executable to:

```text
AdminDoctor.app/Contents/Library/LaunchServices/AdminDoctorPrivilegedHelper
```

Release bundles also include the SMAppService LaunchDaemon plist at:

```text
AdminDoctor.app/Contents/Library/LaunchDaemons/dev.admindoctor.AdminDoctorPrivilegedHelper.plist
```

The plist uses `BundleProgram` and exposes the Mach service `dev.admindoctor.AdminDoctorPrivilegedHelper`. The main app can register/unregister the daemon with `SMAppService.daemon(plistName:)` and ping the helper through XPC after macOS enables the daemon.

For production signing, build with a valid Developer ID or development signing identity:

```sh
CODE_SIGN_IDENTITY="Developer ID Application: Example Team (TEAMID)" ./script/build_dmg.sh
```

This Mac currently needs a valid code signing identity before the helper can be approved as a production signed daemon.

Deletion from privileged locations is not implemented here. Before AdminDoctor can safely clean system paths, the helper must be:

- signed with the same Team ID as the app
- installed and updated through `SMAppService`
- exposed through a narrow XPC protocol
- audited with explicit allow-listed paths
- covered by tests for dry-run, authorization, and failure reporting

This keeps the MVP useful for admins without silently crossing into unsafe root file operations.
