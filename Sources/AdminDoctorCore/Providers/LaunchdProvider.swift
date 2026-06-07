import Foundation

struct LaunchdStartupItem: Equatable, Sendable {
    var label: String
    var kind: String
    var sourcePath: String
    var program: String?
    var programArguments: [String]
    var runAtLoad: Bool
    var keepAlive: Bool
    var disabled: Bool
    var triggerSummary: String
    var missingExecutablePath: String?

    var displayName: String {
        let executableHint = program ?? programArguments.first
        if
            let executableHint,
            executableHint.hasSuffix(".app") || executableHint.contains(".app/")
        {
            return LaunchdParser.appDisplayName(from: executableHint) ?? label
        }
        return label
    }

    var commandSummary: String {
        if !programArguments.isEmpty {
            return LaunchdParser.truncated(programArguments.joined(separator: " "))
        }
        if let program, !program.isEmpty {
            return LaunchdParser.truncated(program)
        }
        return "No Program or ProgramArguments"
    }

    var detailSummary: String {
        let state = disabled ? "disabled" : "enabled"
        var parts = [
            "\(kind), \(state)",
            triggerSummary,
            commandSummary,
            sourcePath
        ]

        if let missingExecutablePath {
            parts.insert("missing executable: \(missingExecutablePath)", at: 2)
        }

        return parts.joined(separator: "\n")
    }
}

enum LaunchdParser {
    static func parseStartupItem(propertyList: Any, sourcePath: String, kind: String) -> LaunchdStartupItem? {
        guard let dictionary = propertyList as? [String: Any] else {
            return nil
        }

        let label = stringValue(dictionary["Label"])
            ?? URL(fileURLWithPath: sourcePath).deletingPathExtension().lastPathComponent
        let program = stringValue(dictionary["Program"])
        let programArguments = stringArray(dictionary["ProgramArguments"])
        let runAtLoad = boolValue(dictionary["RunAtLoad"]) ?? false
        let keepAlive = keepAliveValue(dictionary["KeepAlive"])
        let disabled = boolValue(dictionary["Disabled"]) ?? false
        let triggerSummary = triggerSummary(
            dictionary: dictionary,
            runAtLoad: runAtLoad,
            keepAlive: keepAlive,
            disabled: disabled
        )
        let executablePath = executablePath(program: program, programArguments: programArguments)

        return LaunchdStartupItem(
            label: label,
            kind: kind,
            sourcePath: sourcePath,
            program: program,
            programArguments: programArguments,
            runAtLoad: runAtLoad,
            keepAlive: keepAlive,
            disabled: disabled,
            triggerSummary: triggerSummary,
            missingExecutablePath: missingExecutablePath(executablePath)
        )
    }

    static func kind(for directory: URL) -> String {
        let path = directory.standardizedFileURL.path
        if path.hasSuffix("/Library/LaunchDaemons") {
            return "LaunchDaemon"
        }
        if path.hasSuffix("/Library/LaunchAgents") {
            if path.hasPrefix(FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path) {
                return "User LaunchAgent"
            }
            return "Local LaunchAgent"
        }
        return directory.lastPathComponent
    }

    static func appDisplayName(from path: String) -> String? {
        guard let appRange = path.range(of: ".app", options: [.caseInsensitive]) else {
            return nil
        }

        let prefix = path[..<appRange.upperBound]
        let appName = URL(fileURLWithPath: String(prefix)).deletingPathExtension().lastPathComponent
        return appName.isEmpty ? nil : appName
    }

    static func truncated(_ value: String, limit: Int = 220) -> String {
        guard value.count > limit else {
            return value
        }

        let end = value.index(value.startIndex, offsetBy: limit)
        return String(value[..<end]) + "..."
    }

    private static func executablePath(program: String?, programArguments: [String]) -> String? {
        if let program, program.hasPrefix("/") {
            return program
        }

        guard let firstArgument = programArguments.first, firstArgument.hasPrefix("/") else {
            return nil
        }

        return firstArgument
    }

    private static func missingExecutablePath(_ path: String?) -> String? {
        guard let path else {
            return nil
        }

        return FileManager.default.fileExists(atPath: path) ? nil : path
    }

    private static func triggerSummary(
        dictionary: [String: Any],
        runAtLoad: Bool,
        keepAlive: Bool,
        disabled: Bool
    ) -> String {
        if disabled {
            return "Disabled in plist"
        }

        var triggers: [String] = []
        if runAtLoad {
            triggers.append("RunAtLoad")
        }
        if keepAlive {
            triggers.append("KeepAlive")
        }
        if dictionary["StartInterval"] != nil {
            triggers.append("StartInterval")
        }
        if dictionary["StartCalendarInterval"] != nil {
            triggers.append("StartCalendarInterval")
        }
        if dictionary["WatchPaths"] != nil {
            triggers.append("WatchPaths")
        }
        if dictionary["QueueDirectories"] != nil {
            triggers.append("QueueDirectories")
        }
        if dictionary["MachServices"] != nil {
            triggers.append("MachServices")
        }
        if dictionary["Sockets"] != nil {
            triggers.append("Sockets")
        }

        return triggers.isEmpty ? "launchd-managed" : triggers.joined(separator: ", ")
    }

    private static func keepAliveValue(_ value: Any?) -> Bool {
        switch value {
        case let value as Bool:
            return value
        case let value as NSNumber:
            return value.boolValue
        case let value as [String: Any]:
            return !value.isEmpty
        default:
            return false
        }
    }

    private static func boolValue(_ value: Any?) -> Bool? {
        switch value {
        case let value as Bool:
            return value
        case let value as NSNumber:
            return value.boolValue
        case let value as String:
            if ["true", "yes", "1"].contains(value.lowercased()) {
                return true
            }
            if ["false", "no", "0"].contains(value.lowercased()) {
                return false
            }
            return nil
        default:
            return nil
        }
    }

    private static func stringValue(_ value: Any?) -> String? {
        guard let value = value as? String, !value.isEmpty else {
            return nil
        }
        return value
    }

    private static func stringArray(_ value: Any?) -> [String] {
        (value as? [String]) ?? []
    }
}

public struct LaunchdProvider: DiagnosticProvider {
    public let category: DiagnosticCategory = .launchServices

    private let inspectedDirectories: [URL]

    public init(inspectedDirectories: [URL]? = nil) {
        self.inspectedDirectories = inspectedDirectories ?? [
            URL(fileURLWithPath: "/Library/LaunchAgents"),
            URL(fileURLWithPath: "/Library/LaunchDaemons"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents")
        ]
    }

    public func collect() -> [DiagnosticResult] {
        [plistValidationResult()]
    }

    private func plistValidationResult() -> DiagnosticResult {
        var checked = 0
        var invalid: [String] = []
        var startupItems: [LaunchdStartupItem] = []

        for directory in inspectedDirectories {
            guard
                let files = try? FileManager.default.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )
            else {
                continue
            }

            for file in files where file.pathExtension == "plist" {
                checked += 1
                guard
                    let data = try? Data(contentsOf: file),
                    let propertyList = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)
                else {
                    invalid.append(file.path)
                    continue
                }

                if let item = LaunchdParser.parseStartupItem(
                    propertyList: propertyList,
                    sourcePath: file.path,
                    kind: LaunchdParser.kind(for: directory)
                ) {
                    startupItems.append(item)
                }
            }
        }

        if checked == 0 {
            return DiagnosticResult(
                category: .launchServices,
                severity: .info,
                title: "LaunchAgent and LaunchDaemon plists",
                summary: "No launchd plists found in inspected admin paths.",
                source: "PropertyListSerialization"
            )
        }

        startupItems.sort { lhs, rhs in
            if lhs.kind == rhs.kind {
                return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            }
            return lhs.kind.localizedStandardCompare(rhs.kind) == .orderedAscending
        }

        let missingExecutables = startupItems.compactMap(\.missingExecutablePath)
        let details = [
            DiagnosticDetail(key: "Checked", value: "\(checked)"),
            DiagnosticDetail(key: "Startup items", value: "\(startupItems.count)"),
            DiagnosticDetail(key: "Invalid paths", value: invalid.isEmpty ? "None" : invalid.joined(separator: ", "), privacy: .sensitive)
        ] + startupItems.map { item in
            DiagnosticDetail(key: item.displayName, value: item.detailSummary, privacy: .sensitive)
        }

        let severity: DiagnosticSeverity
        if !invalid.isEmpty {
            severity = .fail
        } else if !missingExecutables.isEmpty {
            severity = .warning
        } else {
            severity = .pass
        }

        let summary: String
        if !invalid.isEmpty {
            summary = "\(invalid.count) invalid plist file(s) found."
        } else if !missingExecutables.isEmpty {
            summary = "\(startupItems.count) startup item(s) parsed; \(missingExecutables.count) missing executable path(s)."
        } else {
            summary = "\(startupItems.count) startup item(s) parsed successfully."
        }

        return DiagnosticResult(
            category: .launchServices,
            severity: severity,
            title: "LaunchAgent and LaunchDaemon plists",
            summary: summary,
            details: details,
            remediation: remediation(invalid: invalid, missingExecutables: missingExecutables),
            source: "PropertyListSerialization"
        )
    }

    private func remediation(invalid: [String], missingExecutables: [String]) -> String? {
        if !invalid.isEmpty {
            return "Open the invalid plist in plutil or Xcode and fix syntax before loading it with launchd."
        }
        if !missingExecutables.isEmpty {
            return "Review startup entries with missing executable paths; they can slow login or indicate removed software leaving launchd plists behind."
        }
        return nil
    }
}
