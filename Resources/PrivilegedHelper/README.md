# AdminDoc Privileged Helper Scaffold

AdminDoc can scan user-scoped cleanup locations directly and move selected user items to Trash. System cleanup locations such as `/Library/Caches` and `/Library/Logs` are intentionally marked as `requiresHelper` in the main app.

The `AdminDocPrivilegedHelper` executable target is a development scaffold for the future signed helper. It currently supports only read-only JSON scanning:

```sh
swift run AdminDocPrivilegedHelper scan-system-cleanup
```

Deletion from privileged locations is not implemented here. Before AdminDoc can safely clean system paths, the helper must be:

- signed with the same Team ID as the app
- installed and updated through `SMAppService`
- exposed through a narrow XPC protocol
- audited with explicit allow-listed paths
- covered by tests for dry-run, authorization, and failure reporting

This keeps the MVP useful for admins without silently crossing into unsafe root file operations.
