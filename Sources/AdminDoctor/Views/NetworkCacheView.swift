import AdminDoctorCore
import SwiftUI

struct NetworkCacheView: View {
    let summary: NetworkCacheFlushSummary?
    let isClearing: Bool
    let error: String?
    let clearDNSCache: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Label(L10n.string("network.cache.title"), systemImage: "network")
                    .font(.headline)

                Spacer()

                Button {
                    clearDNSCache()
                } label: {
                    Label(L10n.string("network.cache.clear"), systemImage: "arrow.clockwise")
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
                Text("\(message(for: summary)) \(summary.flushedAt.localizedShortTimeString())")
                    .font(.callout)
                    .foregroundStyle(statusColor(for: summary))
                    .textSelection(.enabled)
            } else {
                Text(L10n.string("network.cache.description"))
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

    private func message(for summary: NetworkCacheFlushSummary) -> String {
        summary.succeeded ? L10n.string("network.cache.success") : summary.message
    }
}
