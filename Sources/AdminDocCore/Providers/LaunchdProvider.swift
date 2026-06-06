import Foundation

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
                    (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) != nil
                else {
                    invalid.append(file.path)
                    continue
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

        return DiagnosticResult(
            category: .launchServices,
            severity: invalid.isEmpty ? .pass : .fail,
            title: "LaunchAgent and LaunchDaemon plists",
            summary: invalid.isEmpty ? "\(checked) plist file(s) parsed successfully." : "\(invalid.count) invalid plist file(s) found.",
            details: [
                DiagnosticDetail(key: "Checked", value: "\(checked)"),
                DiagnosticDetail(key: "Invalid paths", value: invalid.isEmpty ? "None" : invalid.joined(separator: ", "), privacy: .sensitive)
            ],
            remediation: invalid.isEmpty ? nil : "Open the invalid plist in plutil or Xcode and fix syntax before loading it with launchd.",
            source: "PropertyListSerialization"
        )
    }
}
