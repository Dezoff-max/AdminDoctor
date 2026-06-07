import AppKit
import Foundation

enum PDFReportRenderer {
    static func data(title: String = "AdminDoctor Support Report", markdown: String) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margin: CGFloat = 54
        let headerHeight: CGFloat = 28
        let textRect = CGRect(
            x: margin,
            y: margin + headerHeight,
            width: pageRect.width - (margin * 2),
            height: pageRect.height - (margin * 2) - headerHeight
        )
        let linesPerPage = 44
        let pages = markdown.components(separatedBy: .newlines).chunked(into: linesPerPage)
        let output = NSMutableData()

        guard
            let consumer = CGDataConsumer(data: output as CFMutableData)
        else {
            return Data()
        }

        var mediaBox = pageRect
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return Data()
        }

        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = 2
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 9.5, weight: .regular),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]

        for pageIndex in pages.indices {
            context.beginPDFPage(nil)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)

            let header = "\(title) - page \(pageIndex + 1) of \(pages.count)" as NSString
            header.draw(
                in: CGRect(x: margin, y: margin, width: textRect.width, height: headerHeight),
                withAttributes: headerAttributes
            )

            let body = pages[pageIndex].joined(separator: "\n") as NSString
            body.draw(
                with: textRect,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: bodyAttributes
            )

            NSGraphicsContext.restoreGraphicsState()
            context.endPDFPage()
        }

        context.closePDF()
        return output as Data
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else {
            return [self]
        }

        var chunks: [[Element]] = []
        var index = startIndex
        while index < endIndex {
            let nextIndex = self.index(index, offsetBy: size, limitedBy: endIndex) ?? endIndex
            chunks.append(Array(self[index..<nextIndex]))
            index = nextIndex
        }
        return chunks
    }
}
