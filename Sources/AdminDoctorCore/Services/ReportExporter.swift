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
            :root {
              color-scheme: light dark;
              --border: rgba(120, 120, 128, .24);
              --muted: rgba(120, 120, 128, .92);
              --panel: rgba(120, 120, 128, .10);
              --fail: #ff3b30;
              --warning: #ff9f0a;
              --pass: #34c759;
              --info: #0a84ff;
              font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
            }
            body { margin: 0; line-height: 1.45; background: Canvas; color: CanvasText; }
            main { max-width: 1100px; margin: 0 auto; padding: 34px; }
            header { display: grid; grid-template-columns: 1fr auto; gap: 18px; align-items: start; border-bottom: 1px solid var(--border); margin-bottom: 22px; padding-bottom: 18px; }
            h1 { font-size: 30px; letter-spacing: 0; margin: 0 0 8px; }
            h2 { border-top: 1px solid var(--border); margin-top: 30px; padding-top: 20px; }
            .badge { display: inline-block; border: 1px solid var(--border); border-radius: 7px; padding: 5px 8px; font-size: 12px; color: var(--muted); }
            .summary-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(170px, 1fr)); gap: 10px; margin: 16px 0 8px; }
            .summary-card { border: 1px solid var(--border); background: var(--panel); border-radius: 8px; padding: 10px; }
            .summary-card strong { display: block; margin-bottom: 8px; }
            .counts { display: flex; gap: 8px; flex-wrap: wrap; color: var(--muted); font-size: 13px; }
            table { border-collapse: collapse; width: 100%; margin: 12px 0; font-size: 14px; }
            th, td { border-bottom: 1px solid var(--border); padding: 7px 8px; text-align: left; vertical-align: top; }
            th { color: var(--muted); font-weight: 600; }
            .finding { border: 1px solid var(--border); border-left-width: 5px; border-radius: 8px; padding: 12px 14px; margin: 12px 0; background: rgba(120, 120, 128, .06); break-inside: avoid; }
            .finding h3 { margin: 0 0 7px; font-size: 17px; }
            .finding h3 span { display: inline-block; min-width: 58px; border-radius: 999px; padding: 2px 7px; margin-right: 7px; text-align: center; font-size: 11px; color: white; }
            .fail { border-left-color: #ff3b30; }
            .warning { border-left-color: #ff9f0a; }
            .pass { border-left-color: #34c759; }
            .info { border-left-color: #0a84ff; }
            .fail h3 span { background: var(--fail); }
            .warning h3 span { background: var(--warning); }
            .pass h3 span { background: var(--pass); }
            .info h3 span { background: var(--info); }
            .source, .meta { color: var(--muted); font-size: 13px; }
            @media print {
              main { padding: 22px; }
              .finding { break-inside: avoid; }
            }
          </style>
        </head>
        <body>
        <main>
          <header>
            <div>
              <h1>AdminDoctor Support Report</h1>
              <p class="meta">Generated: \(escapeHTML(generated))</p>
              <p class="meta">Redaction: enabled. Values redacted by default: \(escapeHTML(report.redactionSummary.joined(separator: ", "))).</p>
            </div>
            <div class="badge">Schema \(report.schemaVersion)</div>
          </header>
          <section>
            <h2>Summary</h2>
            <div class="summary-grid">
              \(report.categorySummaries.map { summary in
                  """
                  <div class="summary-card">
                    <strong>\(escapeHTML(summary.category.title))</strong>
                    <div class="counts">
                      <span>\(summary.failCount) fail</span>
                      <span>\(summary.warningCount) warn</span>
                      <span>\(summary.passCount) pass</span>
                      <span>\(summary.infoCount) info</span>
                    </div>
                  </div>
                  """
              }.joined(separator: "\n"))
            </div>
            <table>
              <thead><tr><th>Category</th><th>Fail</th><th>Warning</th><th>Pass</th><th>Info</th></tr></thead>
              <tbody>
        \(summaryRows)
              </tbody>
            </table>
          </section>
        \(sections.joined(separator: "\n"))
        </main>
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
