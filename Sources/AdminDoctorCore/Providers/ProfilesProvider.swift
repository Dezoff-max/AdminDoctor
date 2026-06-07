import Foundation

public struct ProfilesProvider: DiagnosticProvider {
    public let category: DiagnosticCategory = .profiles

    private let runner: any CommandRunning

    public init(runner: any CommandRunning) {
        self.runner = runner
    }

    public func collect() -> [DiagnosticResult] {
        [
            enrollmentResult(),
            installedProfilesResult()
        ]
    }

    private func enrollmentResult() -> DiagnosticResult {
        guard let raw = output(Command("/usr/bin/profiles", arguments: ["status", "-type", "enrollment"])) else {
            return DiagnosticResult(
                category: .profiles,
                severity: .info,
                title: "MDM enrollment",
                summary: "MDM enrollment status unavailable.",
                source: "profiles status -type enrollment"
            )
        }

        let enrolled = raw.localizedCaseInsensitiveContains("MDM enrollment: Yes")
            || raw.localizedCaseInsensitiveContains("Enrolled via DEP: Yes")
        return DiagnosticResult(
            category: .profiles,
            severity: .info,
            title: "MDM enrollment",
            summary: enrolled ? "MDM enrollment signal present." : "No MDM enrollment signal reported.",
            details: ParserHelpers.trimmedNonEmptyLines(raw).map { DiagnosticDetail(key: "profiles", value: $0) },
            source: "profiles status -type enrollment"
        )
    }

    private func installedProfilesResult() -> DiagnosticResult {
        guard let raw = output(Command("/usr/bin/profiles", arguments: ["list"])) else {
            return DiagnosticResult(
                category: .profiles,
                severity: .info,
                title: "Configuration profiles",
                summary: "Installed profile list unavailable.",
                source: "profiles list"
            )
        }

        let count = ParserHelpers.captures(in: raw, pattern: #"attribute:\s+profileIdentifier"#).count
        return DiagnosticResult(
            category: .profiles,
            severity: .info,
            title: "Configuration profiles",
            summary: count == 0 ? "No installed configuration profiles reported." : "\(count) installed profile identifier(s) reported.",
            source: "profiles list"
        )
    }

    private func output(_ command: Command) -> String? {
        guard let result = try? runner.run(command), result.succeeded else {
            return nil
        }
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
