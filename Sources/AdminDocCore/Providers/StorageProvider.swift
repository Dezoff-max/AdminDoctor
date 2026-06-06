import Foundation

public struct DiskInfo: Equatable, Sendable {
    public var volumeName: String?
    public var filesystemName: String?
    public var filesystemType: String?
    public var totalSize: Int64?
    public var freeSpace: Int64?
    public var apfsContainerReference: String?
}

public enum StorageInfoParser {
    public static func parseDiskInfo(plistData: Data) -> DiskInfo? {
        guard
            let object = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil),
            let dictionary = object as? [String: Any]
        else {
            return nil
        }

        return DiskInfo(
            volumeName: dictionary["VolumeName"] as? String,
            filesystemName: dictionary["FilesystemName"] as? String,
            filesystemType: dictionary["FilesystemType"] as? String,
            totalSize: integerValue(dictionary["TotalSize"]),
            freeSpace: integerValue(dictionary["FreeSpace"]),
            apfsContainerReference: dictionary["APFSContainerReference"] as? String
        )
    }

    private static func integerValue(_ value: Any?) -> Int64? {
        switch value {
        case let value as Int:
            return Int64(value)
        case let value as Int64:
            return value
        case let value as NSNumber:
            return value.int64Value
        default:
            return nil
        }
    }
}

public struct StorageProvider: DiagnosticProvider {
    public let category: DiagnosticCategory = .storage

    private let runner: any CommandRunning

    public init(runner: any CommandRunning) {
        self.runner = runner
    }

    public func collect() -> [DiagnosticResult] {
        [
            capacityResult(),
            apfsResult()
        ]
    }

    private func capacityResult() -> DiagnosticResult {
        do {
            let values = try URL(fileURLWithPath: "/").resourceValues(forKeys: [
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeAvailableCapacityKey,
                .volumeTotalCapacityKey
            ])

            let importantFree = values.volumeAvailableCapacityForImportantUsage ?? 0
            let standardFree = Int64(values.volumeAvailableCapacity ?? 0)
            let free = importantFree > 0 ? importantFree : standardFree
            let total = Int64(values.volumeTotalCapacity ?? 0)
            let percentFree = total > 0 ? Double(free) / Double(total) : 0
            let severity: DiagnosticSeverity

            if free < 5.gibibytes || percentFree < 0.05 {
                severity = .fail
            } else if free < 20.gibibytes || percentFree < 0.15 {
                severity = .warning
            } else {
                severity = .pass
            }

            return DiagnosticResult(
                category: .storage,
                severity: severity,
                title: "System volume free space",
                summary: "\(ByteCountFormatter.adminDocString(free)) free of \(ByteCountFormatter.adminDocString(total))",
                details: [
                    DiagnosticDetail(key: "Free", value: ByteCountFormatter.adminDocString(free)),
                    DiagnosticDetail(key: "Total", value: ByteCountFormatter.adminDocString(total)),
                    DiagnosticDetail(key: "Free percent", value: "\(Int(percentFree * 100))%")
                ],
                remediation: severity == .pass ? nil : "Review large local files, caches, snapshots, and managed storage policies.",
                source: "FileManager volume resource values"
            )
        } catch {
            return DiagnosticResult(
                category: .storage,
                severity: .warning,
                title: "System volume free space",
                summary: "Unable to read volume capacity.",
                remediation: "Check whether the app can read the root volume resource values.",
                source: "FileManager volume resource values"
            )
        }
    }

    private func apfsResult() -> DiagnosticResult {
        guard
            let result = try? runner.run(Command("/usr/sbin/diskutil", arguments: ["info", "-plist", "/"])),
            result.succeeded,
            let data = result.stdout.data(using: .utf8),
            let info = StorageInfoParser.parseDiskInfo(plistData: data)
        else {
            return DiagnosticResult(
                category: .storage,
                severity: .info,
                title: "APFS status",
                summary: "Unable to read structured disk information.",
                source: "diskutil info -plist /"
            )
        }

        let filesystem = [info.filesystemName, info.filesystemType]
            .compactMap { $0 }
            .joined(separator: " ")
        let isAPFS = filesystem.localizedCaseInsensitiveContains("apfs")

        return DiagnosticResult(
            category: .storage,
            severity: isAPFS ? .pass : .warning,
            title: "APFS status",
            summary: isAPFS ? "System volume is APFS." : "System volume does not report APFS.",
            details: [
                DiagnosticDetail(key: "Volume", value: info.volumeName ?? "Unknown"),
                DiagnosticDetail(key: "Filesystem", value: filesystem.isEmpty ? "Unknown" : filesystem),
                DiagnosticDetail(key: "APFS container", value: info.apfsContainerReference ?? "Not reported")
            ],
            remediation: isAPFS ? nil : "Confirm whether this Mac is booting from an expected filesystem.",
            source: "diskutil info -plist /"
        )
    }
}

private extension Int {
    var gibibytes: Int64 { Int64(self) * 1_024 * 1_024 * 1_024 }
}

private extension ByteCountFormatter {
    static func adminDocString(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.includesActualByteCount = false
        return formatter.string(fromByteCount: bytes)
    }
}
