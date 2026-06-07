import Foundation

public struct DiskInfo: Equatable, Sendable {
    public var volumeName: String?
    public var filesystemName: String?
    public var filesystemType: String?
    public var totalSize: Int64?
    public var freeSpace: Int64?
    public var apfsContainerReference: String?
    public var busProtocol: String?
    public var solidState: Bool?
    public var smartStatus: String?
    public var smartDetails: SMARTInfo?
}

public struct SMARTInfo: Equatable, Sendable {
    public var availableSparePercent: Int64?
    public var availableSpareThresholdPercent: Int64?
    public var percentageUsed: Int64?
    public var mediaErrors: Int64?
    public var errorLogEntries: Int64?
    public var unsafeShutdowns: Int64?
    public var powerOnHours: Int64?
    public var temperatureCelsius: Int64?
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
            apfsContainerReference: dictionary["APFSContainerReference"] as? String,
            busProtocol: dictionary["BusProtocol"] as? String,
            solidState: dictionary["SolidState"] as? Bool,
            smartStatus: dictionary["SMARTStatus"] as? String,
            smartDetails: parseSMARTInfo(dictionary["SMARTDeviceSpecificKeysMayVaryNotGuaranteed"])
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

    private static func parseSMARTInfo(_ value: Any?) -> SMARTInfo? {
        guard let dictionary = value as? [String: Any] else {
            return nil
        }

        let temperature = integerValue(dictionary["TEMPERATURE"]).map { rawValue in
            rawValue > 200 ? rawValue - 273 : rawValue
        }

        return SMARTInfo(
            availableSparePercent: integerValue(dictionary["AVAILABLE_SPARE"]),
            availableSpareThresholdPercent: integerValue(dictionary["AVAILABLE_SPARE_THRESHOLD"]),
            percentageUsed: integerValue(dictionary["PERCENTAGE_USED"]),
            mediaErrors: splitCounter(dictionary, base: "MEDIA_ERRORS"),
            errorLogEntries: splitCounter(dictionary, base: "NUM_ERROR_INFO_LOG_ENTRIES"),
            unsafeShutdowns: splitCounter(dictionary, base: "UNSAFE_SHUTDOWNS"),
            powerOnHours: splitCounter(dictionary, base: "POWER_ON_HOURS"),
            temperatureCelsius: temperature
        )
    }

    private static func splitCounter(_ dictionary: [String: Any], base: String) -> Int64? {
        let direct = integerValue(dictionary[base])
        let low = integerValue(dictionary["\(base)_0"])
        let high = integerValue(dictionary["\(base)_1"])

        if let direct {
            return direct
        }
        if low == nil, high == nil {
            return nil
        }
        return (low ?? 0) + ((high ?? 0) << 32)
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
            apfsResult(),
            smartHealthResult()
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
            } else if free < 20.gibibytes || percentFree < 0.20 {
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
                    DiagnosticDetail(key: "Free percent", value: "\(Int(percentFree * 100))%"),
                    DiagnosticDetail(key: "Used percent", value: "\(Int((1 - percentFree) * 100))%")
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
        guard let info = diskInfo() else {
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

    private func smartHealthResult() -> DiagnosticResult {
        guard let info = diskInfo() else {
            return DiagnosticResult(
                category: .storage,
                severity: .info,
                title: "SSD SMART health",
                summary: "Unable to read disk health information.",
                source: "diskutil info -plist /"
            )
        }

        guard let smartStatus = info.smartStatus ?? info.smartDetails.map({ _ in "Available" }) else {
            return DiagnosticResult(
                category: .storage,
                severity: .info,
                title: "SSD SMART health",
                summary: "SMART status was not reported for this volume.",
                details: [
                    DiagnosticDetail(key: "Media", value: mediaSummary(info))
                ],
                source: "diskutil info -plist /"
            )
        }

        let details = smartDetails(info: info, status: smartStatus)
        let lowered = smartStatus.lowercased()
        let smart = info.smartDetails
        let hasMediaErrors = (smart?.mediaErrors ?? 0) > 0
        let spareBelowThreshold: Bool
        if
            let spare = smart?.availableSparePercent,
            let threshold = smart?.availableSpareThresholdPercent
        {
            spareBelowThreshold = spare <= threshold
        } else {
            spareBelowThreshold = false
        }

        let severity: DiagnosticSeverity
        if lowered.contains("fail") || lowered.contains("failing") {
            severity = .fail
        } else if hasMediaErrors || spareBelowThreshold {
            severity = .warning
        } else if lowered.contains("verified") || lowered.contains("available") {
            severity = .pass
        } else {
            severity = .info
        }

        return DiagnosticResult(
            category: .storage,
            severity: severity,
            title: "SSD SMART health",
            summary: "SMART status \(smartStatus).",
            details: details,
            remediation: severity == .pass ? nil : "Review disk health in Disk Utility or vendor diagnostics and prepare a backup if errors are present.",
            source: "diskutil info -plist /"
        )
    }

    private func diskInfo() -> DiskInfo? {
        guard
            let result = try? runner.run(Command("/usr/sbin/diskutil", arguments: ["info", "-plist", "/"])),
            result.succeeded,
            let data = result.stdout.data(using: .utf8)
        else {
            return nil
        }

        return StorageInfoParser.parseDiskInfo(plistData: data)
    }

    private func smartDetails(info: DiskInfo, status: String) -> [DiagnosticDetail] {
        var details = [
            DiagnosticDetail(key: "Media", value: mediaSummary(info)),
            DiagnosticDetail(key: "SMART status", value: status)
        ]

        if let smart = info.smartDetails {
            if let percentageUsed = smart.percentageUsed {
                details.append(DiagnosticDetail(key: "Percentage used", value: "\(percentageUsed)%"))
            }
            if let spare = smart.availableSparePercent {
                details.append(DiagnosticDetail(key: "Available spare", value: "\(spare)%"))
            }
            if let threshold = smart.availableSpareThresholdPercent {
                details.append(DiagnosticDetail(key: "Spare threshold", value: "\(threshold)%"))
            }
            if let mediaErrors = smart.mediaErrors {
                details.append(DiagnosticDetail(key: "Media errors", value: "\(mediaErrors)"))
            }
            if let errorLogEntries = smart.errorLogEntries {
                details.append(DiagnosticDetail(key: "Error log entries", value: "\(errorLogEntries)"))
            }
            if let temperature = smart.temperatureCelsius {
                details.append(DiagnosticDetail(key: "Temperature", value: "\(temperature) C"))
            }
            if let powerOnHours = smart.powerOnHours {
                details.append(DiagnosticDetail(key: "Power-on hours", value: "\(powerOnHours)"))
            }
        }

        return details
    }

    private func mediaSummary(_ info: DiskInfo) -> String {
        let parts = [
            info.solidState == true ? "SSD" : nil,
            info.busProtocol
        ]
        .compactMap { $0 }

        return parts.isEmpty ? "Unknown" : parts.joined(separator: ", ")
    }
}

private extension Int {
    var gibibytes: Int64 { Int64(self) * 1_024 * 1_024 * 1_024 }
}

extension ByteCountFormatter {
    static func adminDocString(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.includesActualByteCount = false
        return formatter.string(fromByteCount: bytes)
    }
}
