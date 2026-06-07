import Foundation

public enum ReportFormat: String, CaseIterable, Sendable {
    case markdown
    case json

    public var fileExtension: String {
        switch self {
        case .markdown:
            return "md"
        case .json:
            return "json"
        }
    }
}

public struct ReportExporter: Sendable {
    private let redactor: Redactor

    public init(redactor: Redactor = Redactor()) {
        self.redactor = redactor
    }

    public func report(generatedAt: Date = Date(), results: [DiagnosticResult], context: RedactionContext) -> SupportReport {
        let redactedResults = sorted(results).map { $0.redacted(using: redactor, context: context) }
        let summaries = DiagnosticCategory.allCases.map { category in
            CategorySummary(category: category, results: redactedResults.filter { $0.category == category })
        }

        return SupportReport(
            generatedAt: generatedAt,
            redacted: true,
            redactionSummary: context.summary,
            categorySummaries: summaries,
            results: redactedResults
        )
    }

    public func markdown(generatedAt: Date = Date(), results: [DiagnosticResult], context: RedactionContext) -> String {
        let report = report(generatedAt: generatedAt, results: results, context: context)
        let generated = ISO8601DateFormatter().string(from: report.generatedAt)
        var lines: [String] = [
            "# AdminDoctor Support Report",
            "",
            "- Generated: \(generated)",
            "- Redaction: enabled",
            "- Schema version: \(report.schemaVersion)",
            "",
            "## Redaction",
            "",
            "The following values are redacted by default: \(report.redactionSummary.joined(separator: ", ")).",
            "",
            "## Summary",
            ""
        ]

        for summary in report.categorySummaries {
            lines.append("- \(summary.category.title): \(summary.failCount) fail, \(summary.warningCount) warning, \(summary.passCount) pass, \(summary.infoCount) info")
        }

        for category in DiagnosticCategory.allCases {
            let categoryResults = report.results.filter { $0.category == category }
            lines.append("")
            lines.append("## \(category.title)")
            lines.append("")

            if categoryResults.isEmpty {
                lines.append("No findings.")
                continue
            }

            for result in categoryResults {
                lines.append("### [\(result.severity.rawValue)] \(result.title)")
                lines.append("")
                lines.append(result.summary)
                lines.append("")

                if !result.details.isEmpty {
                    lines.append("| Detail | Value |")
                    lines.append("| --- | --- |")
                    for detail in result.details {
                        lines.append("| \(escapeMarkdownTable(detail.key)) | \(escapeMarkdownTable(detail.value)) |")
                    }
                    lines.append("")
                }

                if let remediation = result.remediation, !remediation.isEmpty {
                    lines.append("Remediation: \(remediation)")
                    lines.append("")
                }

                lines.append("Source: \(result.source)")
                lines.append("")
            }
        }

        return lines.joined(separator: "\n")
    }

    public func jsonData(generatedAt: Date = Date(), results: [DiagnosticResult], context: RedactionContext) throws -> Data {
        let report = report(generatedAt: generatedAt, results: results, context: context)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(report)
    }

    private func sorted(_ results: [DiagnosticResult]) -> [DiagnosticResult] {
        results.sorted {
            if $0.category.rawValue != $1.category.rawValue {
                return categoryOrder($0.category) < categoryOrder($1.category)
            }
            if $0.severity.sortPriority != $1.severity.sortPriority {
                return $0.severity.sortPriority < $1.severity.sortPriority
            }
            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    private func categoryOrder(_ category: DiagnosticCategory) -> Int {
        DiagnosticCategory.allCases.firstIndex(of: category) ?? Int.max
    }

    private func escapeMarkdownTable(_ value: String) -> String {
        value
            .replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: "<br>")
    }
}
