import Foundation

public enum ReportFormat: String, CaseIterable, Sendable {
    case markdown
    case json
    case html
    case pdf

    public var fileExtension: String {
        switch self {
        case .markdown:
            return "md"
        case .json:
            return "json"
        case .html:
            return "html"
        case .pdf:
            return "pdf"
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

    public func html(generatedAt: Date = Date(), results: [DiagnosticResult], context: RedactionContext) -> String {
        let report = report(generatedAt: generatedAt, results: results, context: context)
        let generated = ISO8601DateFormatter().string(from: report.generatedAt)
        var sections: [String] = []

        let summaryRows = report.categorySummaries.map { summary in
            """
            <tr>
              <td>\(escapeHTML(summary.category.title))</td>
              <td>\(summary.failCount)</td>
              <td>\(summary.warningCount)</td>
              <td>\(summary.passCount)</td>
              <td>\(summary.infoCount)</td>
            </tr>
            """
        }.joined(separator: "\n")

        for category in DiagnosticCategory.allCases {
            let categoryResults = report.results.filter { $0.category == category }
            var body = "<h2>\(escapeHTML(category.title))</h2>\n"

            if categoryResults.isEmpty {
                body += "<p>No findings.</p>\n"
            } else {
                for result in categoryResults {
                    let details = result.details.map { detail in
                        """
                        <tr>
                          <td>\(escapeHTML(detail.key))</td>
                          <td>\(escapeHTML(detail.value))</td>
                        </tr>
                        """
                    }.joined(separator: "\n")

                    body += """
                    <article class="finding \(result.severity.rawValue)">
                      <h3><span>\(escapeHTML(result.severity.rawValue.uppercased()))</span> \(escapeHTML(result.title))</h3>
                      <p>\(escapeHTML(result.summary))</p>
                    """

                    if !details.isEmpty {
                        body += """

                          <table>
                            <thead><tr><th>Detail</th><th>Value</th></tr></thead>
                            <tbody>
                        \(details)
                            </tbody>
                          </table>
                        """
                    }

                    if let remediation = result.remediation, !remediation.isEmpty {
                        body += "\n  <p><strong>Remediation:</strong> \(escapeHTML(remediation))</p>"
                    }

                    body += "\n  <p class=\"source\">Source: \(escapeHTML(result.source))</p>\n</article>\n"
                }
            }

            sections.append(body)
        }

        return """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>AdminDoctor Support Report</title>
          <style>
            :root { color-scheme: light dark; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
            body { margin: 32px; line-height: 1.45; background: Canvas; color: CanvasText; }
            header { border-bottom: 1px solid color-mix(in srgb, CanvasText 18%, transparent); margin-bottom: 24px; padding-bottom: 16px; }
            h1 { font-size: 28px; margin: 0 0 12px; }
            h2 { border-top: 1px solid color-mix(in srgb, CanvasText 14%, transparent); margin-top: 28px; padding-top: 20px; }
            table { border-collapse: collapse; width: 100%; margin: 12px 0; font-size: 14px; }
            th, td { border-bottom: 1px solid color-mix(in srgb, CanvasText 12%, transparent); padding: 7px 8px; text-align: left; vertical-align: top; }
            th { color: color-mix(in srgb, CanvasText 72%, transparent); font-weight: 600; }
            .finding { border-left: 4px solid color-mix(in srgb, CanvasText 20%, transparent); padding: 10px 0 10px 14px; margin: 12px 0; }
            .finding h3 { margin: 0 0 6px; font-size: 17px; }
            .finding h3 span { font-size: 12px; letter-spacing: .04em; color: color-mix(in srgb, CanvasText 64%, transparent); }
            .fail { border-left-color: #ff3b30; }
            .warning { border-left-color: #ffcc00; }
            .pass { border-left-color: #34c759; }
            .info { border-left-color: #0a84ff; }
            .source, .meta { color: color-mix(in srgb, CanvasText 62%, transparent); font-size: 13px; }
          </style>
        </head>
        <body>
          <header>
            <h1>AdminDoctor Support Report</h1>
            <p class="meta">Generated: \(escapeHTML(generated))</p>
            <p class="meta">Redaction: enabled. Values redacted by default: \(escapeHTML(report.redactionSummary.joined(separator: ", "))).</p>
            <p class="meta">Schema version: \(report.schemaVersion)</p>
          </header>
          <section>
            <h2>Summary</h2>
            <table>
              <thead><tr><th>Category</th><th>Fail</th><th>Warning</th><th>Pass</th><th>Info</th></tr></thead>
              <tbody>
        \(summaryRows)
              </tbody>
            </table>
          </section>
        \(sections.joined(separator: "\n"))
        </body>
        </html>
        """
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

    private func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
