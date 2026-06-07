import PDFKit
import SwiftUI
import WebKit

struct ReportPreviewSheet: View {
    let preview: ReportPreview
    let save: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Label(L10n.format("report.preview.title", preview.title), systemImage: "doc.text.magnifyingglass")
                    .font(.headline)

                Spacer()

                Button(L10n.string("common.cancel")) {
                    dismiss()
                }

                Button {
                    save()
                } label: {
                    Label(L10n.string("report.preview.save"), systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(14)

            Divider()

            previewBody
                .frame(minWidth: 760, minHeight: 560)
        }
    }

    @ViewBuilder
    private var previewBody: some View {
        switch preview.kind {
        case .text:
            ScrollView {
                Text(preview.text)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
        case .html:
            HTMLReportPreview(html: preview.text)
        case .pdf:
            PDFReportPreview(data: preview.data)
        }
    }
}

private struct HTMLReportPreview: NSViewRepresentable {
    let html: String

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: nil)
    }
}

private struct PDFReportPreview: NSViewRepresentable {
    let data: Data

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView(frame: .zero)
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .windowBackgroundColor
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        pdfView.document = PDFDocument(data: data)
    }
}
