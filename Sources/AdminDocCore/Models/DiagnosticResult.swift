import Foundation

public enum DiagnosticDetailPrivacy: String, Codable, Sendable {
    case standard
    case sensitive
}

public struct DiagnosticDetail: Codable, Equatable, Sendable {
    public var key: String
    public var value: String
    public var privacy: DiagnosticDetailPrivacy

    public init(key: String, value: String, privacy: DiagnosticDetailPrivacy = .standard) {
        self.key = key
        self.value = value
        self.privacy = privacy
    }
}

public struct DiagnosticResult: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var category: DiagnosticCategory
    public var severity: DiagnosticSeverity
    public var title: String
    public var summary: String
    public var details: [DiagnosticDetail]
    public var remediation: String?
    public var source: String

    public init(
        id: UUID = UUID(),
        category: DiagnosticCategory,
        severity: DiagnosticSeverity,
        title: String,
        summary: String,
        details: [DiagnosticDetail] = [],
        remediation: String? = nil,
        source: String
    ) {
        self.id = id
        self.category = category
        self.severity = severity
        self.title = title
        self.summary = summary
        self.details = details
        self.remediation = remediation
        self.source = source
    }
}

public struct CategorySummary: Codable, Equatable, Sendable {
    public var category: DiagnosticCategory
    public var passCount: Int
    public var warningCount: Int
    public var failCount: Int
    public var infoCount: Int

    public init(category: DiagnosticCategory, results: [DiagnosticResult]) {
        self.category = category
        self.passCount = results.filter { $0.severity == .pass }.count
        self.warningCount = results.filter { $0.severity == .warning }.count
        self.failCount = results.filter { $0.severity == .fail }.count
        self.infoCount = results.filter { $0.severity == .info }.count
    }
}

public struct SupportReport: Codable, Equatable, Sendable {
    public var appName: String
    public var schemaVersion: Int
    public var generatedAt: Date
    public var redacted: Bool
    public var redactionSummary: [String]
    public var categorySummaries: [CategorySummary]
    public var results: [DiagnosticResult]

    public init(
        appName: String = "AdminDoc",
        schemaVersion: Int = 1,
        generatedAt: Date,
        redacted: Bool,
        redactionSummary: [String],
        categorySummaries: [CategorySummary],
        results: [DiagnosticResult]
    ) {
        self.appName = appName
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.redacted = redacted
        self.redactionSummary = redactionSummary
        self.categorySummaries = categorySummaries
        self.results = results
    }
}
