import AdminDocCore
import SwiftUI

struct NetworkCacheView: View {
    let summary: NetworkCacheFlushSummary?
    let isClearing: Bool
    let error: String?
    let clearDNSCache: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Label("DNS cache", systemImage: "network")
                    .font(.headline)

                Spacer()

                Button {
                    clearDNSCache()
                } label: {
                    Label("Clear DNS Cache", systemImage: "arrow.clockwise")
                }
                .disabled(isClearing)
            }

            if isClearing {
                ProgressView()
                    .controlSize(.small)
            }

            if let error {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            } else if let summary {
                Text("\(summary.message) \(summary.flushedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.callout)
                    .foregroundStyle(statusColor(for: summary))
                    .textSelection(.enabled)
            } else {
                Text("Flushes the local DNS resolver cache with dscacheutil. Network services and routes are not changed.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func statusColor(for summary: NetworkCacheFlushSummary) -> Color {
        summary.succeeded ? .secondary : .red
    }
}
