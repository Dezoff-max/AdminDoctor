import AdminDoctorCore
import AppKit
import Foundation

enum PDFReportRenderer {
    static func data(title: String = "AdminDoctor Support Report", markdown: String) -> Data {
        let fallbackResult = DiagnosticResult(
            category: .logs,
            severity: .info,
            title: title,
            summary: markdown,
            source: "Markdown fallback"
        )
        let report = SupportReport(
            generatedAt: Date(),
            redacted: true,
            redactionSummary: [],
            categorySummaries: [CategorySummary(category: .logs, results: [fallbackResult])],
            results: [fallbackResult]
        )
        return data(report: report)
    }

    static func data(report: SupportReport) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margin: CGFloat = 42
        let contentWidth = pageRect.width - (margin * 2)
        let output = NSMutableData()

        guard let consumer = CGDataConsumer(data: output as CFMutableData) else {
            return Data()
        }

        var mediaBox = pageRect
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return Data()
        }

        var page = PDFPageWriter(context: context, pageRect: pageRect, margin: margin)
        page.begin()

        for block in blocks(for: report, width: contentWidth) {
            page.draw(block)
        }

        page.finish()
        context.closePDF()
        return output as Data
    }

    private static func blocks(for report: SupportReport, width: CGFloat) -> [PDFBlock] {
        var blocks: [PDFBlock] = []
        let generated = ISO8601DateFormatter().string(from: report.generatedAt)

        blocks.append(.text("AdminDoctor Support Report", .title, spacingAfter: 5))
        blocks.append(.text("Generated \(generated)  |  Redaction enabled  |  Schema \(report.schemaVersion)", .meta, spacingAfter: 12))
        if !report.redactionSummary.isEmpty {
            blocks.append(.text("Redacted by default: \(report.redactionSummary.joined(separator: ", ")).", .body, spacingAfter: 16))
        }

        blocks.append(.text("Summary", .section, spacingAfter: 8))
        let summary = report.categorySummaries.map { summary in
            "\(summary.category.title): \(summary.failCount) fail, \(summary.warningCount) warning, \(summary.passCount) pass, \(summary.infoCount) info"
        }.joined(separator: "\n")
        blocks.append(.panel(summary, style: .body, accent: NSColor.systemBlue, width: width))

        for category in DiagnosticCategory.allCases {
            let results = report.results.filter { $0.category == category }
            blocks.append(.text(category.title, .section, spacingBefore: 12, spacingAfter: 6))

            if results.isEmpty {
                blocks.append(.text("No findings.", .meta, spacingAfter: 6))
                continue
            }

            for result in results {
                var lines = ["[\(result.severity.rawValue.uppercased())] \(result.title)", result.summary]
                if !result.details.isEmpty {
                    lines.append("")
                    lines.append(contentsOf: result.details.map { "\($0.key): \($0.value)" })
                }
                if let remediation = result.remediation, !remediation.isEmpty {
                    lines.append("")
                    lines.append("Remediation: \(remediation)")
                }
                lines.append("")
                lines.append("Source: \(result.source)")
                blocks.append(.panel(lines.joined(separator: "\n"), style: .body, accent: color(for: result.severity), width: width))
            }
        }

        return blocks
    }

    private static func color(for severity: DiagnosticSeverity) -> NSColor {
        switch severity {
        case .fail:
            return .systemRed
        case .warning:
            return .systemOrange
        case .pass:
            return .systemGreen
        case .info:
            return .systemBlue
        }
    }
}

private struct PDFPageWriter {
    let context: CGContext
    let pageRect: CGRect
    let margin: CGFloat
    private(set) var y: CGFloat = 0
    private var pageNumber = 0

    init(context: CGContext, pageRect: CGRect, margin: CGFloat) {
        self.context = context
        self.pageRect = pageRect
        self.margin = margin
    }

    mutating func begin() {
        startPage()
    }

    mutating func finish() {
        NSGraphicsContext.restoreGraphicsState()
        context.endPDFPage()
    }

    mutating func draw(_ block: PDFBlock) {
        let availableWidth = pageRect.width - (margin * 2)
        let height = block.height(width: availableWidth)
        if y + height > pageRect.height - margin {
            NSGraphicsContext.restoreGraphicsState()
            context.endPDFPage()
            startPage()
        }

        block.draw(in: CGRect(x: margin, y: y, width: availableWidth, height: height))
        y += height
    }

    private mutating func startPage() {
        pageNumber += 1
        context.beginPDFPage(nil)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        y = margin

        let footer = "AdminDoctor support report - page \(pageNumber)" as NSString
        footer.draw(
            in: CGRect(x: margin, y: pageRect.height - margin + 12, width: pageRect.width - (margin * 2), height: 16),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: 8.5),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
    }
}

private enum PDFTextStyle {
    case title
    case section
    case body
    case meta

    var attributes: [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = 2

        switch self {
        case .title:
            return [.font: NSFont.systemFont(ofSize: 24, weight: .bold), .foregroundColor: NSColor.labelColor, .paragraphStyle: paragraph]
        case .section:
            return [.font: NSFont.systemFont(ofSize: 15, weight: .semibold), .foregroundColor: NSColor.labelColor, .paragraphStyle: paragraph]
        case .body:
            return [.font: NSFont.systemFont(ofSize: 10.5), .foregroundColor: NSColor.labelColor, .paragraphStyle: paragraph]
        case .meta:
            return [.font: NSFont.systemFont(ofSize: 9.5), .foregroundColor: NSColor.secondaryLabelColor, .paragraphStyle: paragraph]
        }
    }
}

private struct PDFBlock {
    let attributedString: NSAttributedString
    let spacingBefore: CGFloat
    let spacingAfter: CGFloat
    let accent: NSColor?
    let panelWidth: CGFloat?

    static func text(
        _ text: String,
        _ style: PDFTextStyle,
        spacingBefore: CGFloat = 0,
        spacingAfter: CGFloat = 4
    ) -> PDFBlock {
        PDFBlock(
            attributedString: NSAttributedString(string: text, attributes: style.attributes),
            spacingBefore: spacingBefore,
            spacingAfter: spacingAfter,
            accent: nil,
            panelWidth: nil
        )
    }

    static func panel(_ text: String, style: PDFTextStyle, accent: NSColor, width: CGFloat) -> PDFBlock {
        PDFBlock(
            attributedString: NSAttributedString(string: text, attributes: style.attributes),
            spacingBefore: 0,
            spacingAfter: 8,
            accent: accent,
            panelWidth: width
        )
    }

    func height(width: CGFloat) -> CGFloat {
        let inset: CGFloat = accent == nil ? 0 : 10
        let textWidth = width - (inset * 2) - (accent == nil ? 0 : 5)
        let rect = attributedString.boundingRect(
            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        return spacingBefore + ceil(rect.height) + spacingAfter + (accent == nil ? 0 : 18)
    }

    func draw(in rect: CGRect) {
        let drawRect = rect.insetBy(dx: 0, dy: spacingBefore)
        if let accent {
            let panelRect = CGRect(x: drawRect.minX, y: drawRect.minY, width: panelWidth ?? drawRect.width, height: drawRect.height - spacingAfter)
            NSColor.controlBackgroundColor.withAlphaComponent(0.42).setFill()
            NSBezierPath(roundedRect: panelRect, xRadius: 6, yRadius: 6).fill()
            accent.setFill()
            NSBezierPath(roundedRect: CGRect(x: panelRect.minX, y: panelRect.minY, width: 4, height: panelRect.height), xRadius: 2, yRadius: 2).fill()
            attributedString.draw(
                with: panelRect.insetBy(dx: 10, dy: 9).offsetBy(dx: 4, dy: 0),
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            )
        } else {
            attributedString.draw(
                with: drawRect,
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            )
        }
    }
}
