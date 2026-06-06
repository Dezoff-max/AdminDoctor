# Starter Issues

Use these as the first public GitHub issues after creating the repository.

## 1. Harden MDM And Profile Parsing

Improve the MVP `profiles` checks so they parse structured output where available and avoid relying on simple text heuristics.

Labels: `enhancement`, `diagnostics`, `privacy`

Acceptance criteria:

- Device and user profiles are counted separately.
- Profile identifiers are redacted in exports when they contain organization names.
- Tests cover at least two macOS output variants.

## 2. Expand Launchd Validation

Parse launchd plists beyond syntax validation.

Labels: `enhancement`, `diagnostics`

Acceptance criteria:

- Extract label, program, program arguments, and disabled state.
- Warn when a referenced executable path is missing.
- Tests cover valid, invalid, disabled, and broken-path fixtures.

## 3. Add Export Preview

Show exactly what will be included before a report is written.

Labels: `enhancement`, `privacy`, `ui`

Acceptance criteria:

- Preview shows report sections and redaction categories.
- User can choose Markdown or JSON from the preview.
- No unredacted sensitive values appear in preview text.

## 4. Add Signed Release Workflow

Prepare a release workflow for signed and notarized builds.

Labels: `release`, `security`, `ci`

Acceptance criteria:

- Document required Apple Developer secrets.
- Build unsigned artifacts for PRs.
- Build signed/notarized artifacts only for release tags.

## 5. Add Rule-Based Severity Baselines

Let admins tune severity mapping for different environments.

Labels: `enhancement`, `architecture`

Acceptance criteria:

- Baselines are local files.
- No network fetch is required.
- Tests cover FileVault, firewall, and proxy severity overrides.
