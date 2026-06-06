import Foundation

public enum SecurityStatusParser {
    public static func parseFileVaultStatus(_ output: String) -> BinaryStatus {
        let lowered = output.lowercased()
        if lowered.contains("filevault is on") || lowered.contains("encryption in progress") {
            return .enabled
        }
        if lowered.contains("filevault is off") {
            return .disabled
        }
        return .unavailable
    }

    public static func parseSIPStatus(_ output: String) -> BinaryStatus {
        let lowered = output.lowercased()
        if lowered.contains("enabled") {
            return .enabled
        }
        if lowered.contains("disabled") {
            return .disabled
        }
        return .unavailable
    }

    public static func parseGatekeeperStatus(_ output: String) -> BinaryStatus {
        let lowered = output.lowercased()
        if lowered.contains("assessments enabled") {
            return .enabled
        }
        if lowered.contains("assessments disabled") {
            return .disabled
        }
        return .unavailable
    }

    public static func parseFirewallStatus(_ output: String) -> BinaryStatus {
        let lowered = output.lowercased()
        if lowered.contains("enabled") || lowered.contains("state = 1") {
            return .enabled
        }
        if lowered.contains("disabled") || lowered.contains("state = 0") {
            return .disabled
        }
        return .unavailable
    }
}

public struct SecurityProvider: DiagnosticProvider {
    public let category: DiagnosticCategory = .security

    private let runner: any CommandRunning

    public init(runner: any CommandRunning) {
        self.runner = runner
    }

    public func collect() -> [DiagnosticResult] {
        [
            fileVaultResult(),
            sipResult(),
            gatekeeperResult(),
            firewallResult()
        ]
    }

    private func fileVaultResult() -> DiagnosticResult {
        let raw = output(Command("/usr/bin/fdesetup", arguments: ["status"]))
        let status = raw.map(SecurityStatusParser.parseFileVaultStatus) ?? .unavailable
        let severity = SeverityMapping.recommendedControl(status)

        return DiagnosticResult(
            category: .security,
            severity: severity,
            title: "FileVault",
            summary: summary(status: status, enabled: "FileVault is enabled.", disabled: "FileVault is disabled.", unavailable: "FileVault status unavailable."),
            details: [DiagnosticDetail(key: "Command output", value: raw ?? "Unavailable")],
            remediation: severity == .warning ? "Confirm whether disk encryption is required by policy." : nil,
            source: "fdesetup status"
        )
    }

    private func sipResult() -> DiagnosticResult {
        let raw = output(Command("/usr/bin/csrutil", arguments: ["status"]))
        let status = raw.map(SecurityStatusParser.parseSIPStatus) ?? .unavailable
        let severity = SeverityMapping.requiredControl(status)

        return DiagnosticResult(
            category: .security,
            severity: severity,
            title: "System Integrity Protection",
            summary: summary(status: status, enabled: "SIP is enabled.", disabled: "SIP is disabled.", unavailable: "SIP status unavailable."),
            details: [DiagnosticDetail(key: "Command output", value: raw ?? "Unavailable")],
            remediation: severity == .fail ? "Review why SIP is disabled and re-enable it from Recovery if policy requires it." : nil,
            source: "csrutil status"
        )
    }

    private func gatekeeperResult() -> DiagnosticResult {
        let raw = output(Command("/usr/sbin/spctl", arguments: ["--status"]))
        let status = raw.map(SecurityStatusParser.parseGatekeeperStatus) ?? .unavailable
        let severity = SeverityMapping.recommendedControl(status)

        return DiagnosticResult(
            category: .security,
            severity: severity,
            title: "Gatekeeper",
            summary: summary(status: status, enabled: "Gatekeeper assessments are enabled.", disabled: "Gatekeeper assessments are disabled.", unavailable: "Gatekeeper status unavailable."),
            details: [DiagnosticDetail(key: "Command output", value: raw ?? "Unavailable")],
            remediation: severity == .warning ? "Confirm whether disabled assessments are expected for this Mac." : nil,
            source: "spctl --status"
        )
    }

    private func firewallResult() -> DiagnosticResult {
        let raw = output(Command("/usr/libexec/ApplicationFirewall/socketfilterfw", arguments: ["--getglobalstate"]))
        let status = raw.map(SecurityStatusParser.parseFirewallStatus) ?? .unavailable
        let severity = SeverityMapping.recommendedControl(status)

        return DiagnosticResult(
            category: .security,
            severity: severity,
            title: "Application firewall",
            summary: summary(status: status, enabled: "Firewall is enabled.", disabled: "Firewall is disabled.", unavailable: "Firewall status unavailable."),
            details: [DiagnosticDetail(key: "Command output", value: raw ?? "Unavailable")],
            remediation: severity == .warning ? "Check whether local firewall configuration matches the organization's baseline." : nil,
            source: "socketfilterfw --getglobalstate"
        )
    }

    private func summary(status: BinaryStatus, enabled: String, disabled: String, unavailable: String) -> String {
        switch status {
        case .enabled:
            return enabled
        case .disabled:
            return disabled
        case .unavailable:
            return unavailable
        }
    }

    private func output(_ command: Command) -> String? {
        guard let result = try? runner.run(command), result.succeeded else {
            return nil
        }
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
