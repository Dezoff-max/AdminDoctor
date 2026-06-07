import Foundation

public struct ScanHistoryEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var startedAt: Date
    public var failCount: Int
    public var warningCount: Int
    public var passCount: Int
    public var infoCount: Int
    public var topWarningTitles: [String]

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        failCount: Int,
        warningCount: Int,
        passCount: Int,
        infoCount: Int,
        topWarningTitles: [String]
    ) {
        self.id = id
        self.startedAt = startedAt
        self.failCount = failCount
        self.warningCount = warningCount
        self.passCount = passCount
        self.infoCount = infoCount
        self.topWarningTitles = topWarningTitles
    }

    public init(startedAt: Date, results: [DiagnosticResult]) {
        self.init(
            startedAt: startedAt,
            failCount: results.filter { $0.severity == .fail }.count,
            warningCount: results.filter { $0.severity == .warning }.count,
            passCount: results.filter { $0.severity == .pass }.count,
            infoCount: results.filter { $0.severity == .info }.count,
            topWarningTitles: results
                .filter { $0.severity == .fail || $0.severity == .warning }
                .prefix(4)
                .map(\.title)
        )
    }
}
