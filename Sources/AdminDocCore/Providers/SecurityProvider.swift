import Foundation

public enum SecurityStatusParser {
    public struct XProtectVersions: Equatable, Sendable {
        public var configurationVersion: String?
        public var appVersion: String?
        public var mrtVersion: String?

        public var hasAnySignal: Bool {
            configurationVersion != nil || appVersion != nil || mrtVersion != nil
        }
    }

    public struct InstallHistoryItem: Equatable, Sendable {
        public var name: String
        public var version: String?
        public var installedAt: Date?
    }

    public struct SoftwareUpdateSettings: Equatable, Sendable {
        public var automaticDownload: Bool?
        public var criticalUpdateInstall: Bool?
        public var configDataInstall: Bool?
        public var automaticallyInstallMacOSUpdates: Bool?
        public var lastSuccessfulDate: Date?
    }

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

    public static func parseBundleShortVersion(plistData: Data) -> String? {
        guard
            let object = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil),
            let dictionary = object as? [String: Any]
        else {
            return nil
        }

        return dictionary["CFBundleShortVersionString"] as? String
    }

    public static func parseInstallHistory(jsonData: Data) -> [InstallHistoryItem] {
        struct Payload: Decodable {
            var SPInstallHistoryDataType: [Item]
        }

        struct Item: Decodable {
            var name: String
            var version: String?
            var installDate: String?

            enum CodingKeys: String, CodingKey {
                case name = "_name"
                case version = "install_version"
                case installDate = "install_date"
            }
        }

        guard let payload = try? JSONDecoder().decode(Payload.self, from: jsonData) else {
            return []
        }

        let formatter = ISO8601DateFormatter()
        return payload.SPInstallHistoryDataType.map { item in
            InstallHistoryItem(
                name: item.name,
                version: item.version,
                installedAt: item.installDate.flatMap { formatter.date(from: $0) }
            )
        }
    }

    public static func latestRelevantInstallItems(_ items: [InstallHistoryItem]) -> [InstallHistoryItem] {
        let relevant = items.filter { item in
            let lowered = item.name.lowercased()
            return lowered.contains("macos")
                || lowered.contains("security")
                || lowered.contains("безопас")
                || lowered.contains("xprotect")
                || lowered.contains("mrt")
        }

        return relevant.sorted { left, right in
            switch (left.installedAt, right.installedAt) {
            case let (left?, right?):
                return left > right
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
            }
        }
    }

    public static func parseSoftwareUpdateSettings(plistData: Data) -> SoftwareUpdateSettings? {
        guard
            let object = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil),
            let dictionary = object as? [String: Any]
        else {
            return nil
        }

        return SoftwareUpdateSettings(
            automaticDownload: boolValue(dictionary["AutomaticDownload"]),
            criticalUpdateInstall: boolValue(dictionary["CriticalUpdateInstall"]),
            configDataInstall: boolValue(dictionary["ConfigDataInstall"]),
            automaticallyInstallMacOSUpdates: boolValue(dictionary["AutomaticallyInstallMacOSUpdates"]),
            lastSuccessfulDate: dateValue(dictionary["LastSuccessfulDate"])
        )
    }

    private static func boolValue(_ value: Any?) -> Bool? {
        switch value {
        case let value as Bool:
            return value
        case let value as Int:
            return value != 0
        case let value as NSNumber:
            return value.boolValue
        default:
            return nil
        }
    }

    private static func dateValue(_ value: Any?) -> Date? {
        if let date = value as? Date {
            return date
        }
        if let string = value as? String {
            return ISO8601DateFormatter().date(from: string)
        }
        return nil
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
            firewallResult(),
            xProtectResult(),
            softwareUpdateSettingsResult(),
            securityInstallHistoryResult()
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

    private func xProtectResult() -> DiagnosticResult {
        let versions = SecurityStatusParser.XProtectVersions(
            configurationVersion: bundleVersion(at: "/Library/Apple/System/Library/CoreServices/XProtect.bundle/Contents/Info.plist"),
            appVersion: bundleVersion(at: "/Library/Apple/System/Library/CoreServices/XProtect.app/Contents/Info.plist"),
            mrtVersion: bundleVersion(at: "/Library/Apple/System/Library/CoreServices/MRT.app/Contents/Info.plist")
        )

        guard versions.hasAnySignal else {
            return DiagnosticResult(
                category: .security,
                severity: .warning,
                title: "XProtect",
                summary: "XProtect or MRT version information was not found.",
                remediation: "Confirm that Apple's built-in malware protection components are present.",
                source: "XProtect and MRT Info.plist"
            )
        }

        return DiagnosticResult(
            category: .security,
            severity: .pass,
            title: "XProtect",
            summary: "Built-in malware protection metadata is present.",
            details: [
                DiagnosticDetail(key: "XProtect configuration", value: versions.configurationVersion ?? "Not reported"),
                DiagnosticDetail(key: "XProtect app", value: versions.appVersion ?? "Not reported"),
                DiagnosticDetail(key: "MRT", value: versions.mrtVersion ?? "Not reported")
            ],
            source: "XProtect and MRT Info.plist"
        )
    }

    private func softwareUpdateSettingsResult() -> DiagnosticResult {
        guard
            let data = try? Data(contentsOf: URL(fileURLWithPath: "/Library/Preferences/com.apple.SoftwareUpdate.plist")),
            let settings = SecurityStatusParser.parseSoftwareUpdateSettings(plistData: data)
        else {
            return DiagnosticResult(
                category: .security,
                severity: .info,
                title: "Security update settings",
                summary: "Unable to read Software Update preference signals.",
                source: "com.apple.SoftwareUpdate.plist"
            )
        }

        let criticalEnabled = settings.criticalUpdateInstall != false
        let configEnabled = settings.configDataInstall != false
        let severity: DiagnosticSeverity = (criticalEnabled && configEnabled) ? .pass : .warning

        var details = [
            DiagnosticDetail(key: "Critical updates", value: enabledText(settings.criticalUpdateInstall)),
            DiagnosticDetail(key: "Config data updates", value: enabledText(settings.configDataInstall)),
            DiagnosticDetail(key: "Automatic download", value: enabledText(settings.automaticDownload)),
            DiagnosticDetail(key: "macOS auto install", value: enabledText(settings.automaticallyInstallMacOSUpdates))
        ]
        if let lastSuccessfulDate = settings.lastSuccessfulDate {
            details.append(DiagnosticDetail(key: "Last successful scan", value: ISO8601DateFormatter().string(from: lastSuccessfulDate)))
        }

        return DiagnosticResult(
            category: .security,
            severity: severity,
            title: "Security update settings",
            summary: severity == .pass ? "Critical and configuration data updates appear enabled." : "Critical or configuration data updates may be disabled.",
            details: details,
            remediation: severity == .pass ? nil : "Review Software Update settings or the MDM software update policy.",
            source: "com.apple.SoftwareUpdate.plist"
        )
    }

    private func securityInstallHistoryResult() -> DiagnosticResult {
        guard
            let result = try? runner.run(Command("/usr/sbin/system_profiler", arguments: ["SPInstallHistoryDataType", "-json"], timeout: 20)),
            result.succeeded,
            let data = result.stdout.data(using: .utf8)
        else {
            return DiagnosticResult(
                category: .security,
                severity: .info,
                title: "Security update history",
                summary: "Unable to read structured install history.",
                source: "system_profiler SPInstallHistoryDataType -json"
            )
        }

        let relevantItems = SecurityStatusParser.latestRelevantInstallItems(SecurityStatusParser.parseInstallHistory(jsonData: data))
        guard let latest = relevantItems.first else {
            return DiagnosticResult(
                category: .security,
                severity: .info,
                title: "Security update history",
                summary: "No Apple security-related install history items were found.",
                source: "system_profiler SPInstallHistoryDataType -json"
            )
        }

        let daysSinceLatest = latest.installedAt.map { Date().timeIntervalSince($0) / 86_400 }
        let severity: DiagnosticSeverity = (daysSinceLatest ?? 0) > 45 ? .warning : .pass

        return DiagnosticResult(
            category: .security,
            severity: severity,
            title: "Security update history",
            summary: "Latest relevant item: \(latest.name)\(latest.version.map { " \($0)" } ?? "").",
            details: relevantItems.prefix(5).map { item in
                DiagnosticDetail(
                    key: item.name,
                    value: [
                        item.version,
                        item.installedAt.map { ISO8601DateFormatter().string(from: $0) }
                    ]
                    .compactMap { $0 }
                    .joined(separator: " - ")
                )
            },
            remediation: severity == .pass ? nil : "Check Software Update or MDM update policy; recent security update history may be stale.",
            source: "system_profiler SPInstallHistoryDataType -json"
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

    private func bundleVersion(at path: String) -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return nil
        }
        return SecurityStatusParser.parseBundleShortVersion(plistData: data)
    }

    private func enabledText(_ value: Bool?) -> String {
        switch value {
        case .some(true):
            return "Enabled"
        case .some(false):
            return "Disabled"
        case .none:
            return "Not reported"
        }
    }
}
