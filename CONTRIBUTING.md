# Contributing

Thanks for helping improve AdminDoc.

## Project Rules

- Keep diagnostics read-only unless a future roadmap item explicitly changes that.
- Do not add sudo prompts to MVP checks.
- Do not add telemetry, analytics, or network upload.
- Redact sensitive values in exports by default.
- Prefer structured parsing over string scraping when macOS provides structured output.
- Keep SwiftUI views separate from diagnostic providers.

## Local Workflow

```sh
swift build
swift test
./script/build_and_run.sh
```

## Pull Requests

Good pull requests are focused and include:

- a short explanation of the diagnostic behavior
- parser fixtures or unit tests when output parsing changes
- privacy notes when a new field is collected or exported
- screenshots for UI changes

## Diagnostic Providers

Providers should:

- use `CommandRunning` for commands
- avoid shell interpolation
- avoid destructive commands
- handle missing commands or permissions gracefully
- return `DiagnosticResult` values with clear summaries and remediation hints

## Sensitive Data

Do not include real support reports, serial numbers, hostnames, usernames, Wi-Fi SSIDs, private IPs, MAC addresses, tokens, passwords, or organization identifiers in issues, tests, screenshots, or pull requests.
