import AdminDoctorCore
import SwiftUI

struct NetworkToolkitView: View {
    let summary: NetworkProbeSummary?
    let isRunning: Bool
    let error: String?
    let ping: (String) -> Void
    let traceroute: (String) -> Void

    @State private var host = "1.1.1.1"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Label(L10n.string("network.toolkit.title"), systemImage: "stethoscope")
                    .font(.headline)

                TextField(L10n.string("network.toolkit.hostPlaceholder"), text: $host)
                    .textFieldStyle(.roundedBorder)
                    .font(.callout.monospaced())
                    .frame(width: 220)

                Button {
                    ping(host)
                } label: {
                    Label(L10n.string("network.toolkit.ping"), systemImage: "dot.radiowaves.left.and.right")
                }
                .disabled(isRunning)

                Button {
                    traceroute(host)
                } label: {
                    Label(L10n.string("network.toolkit.trace"), systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                }
                .disabled(isRunning)

                Spacer()

                if isRunning {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            Text(L10n.string("network.toolkit.description"))
                .font(.callout)
                .foregroundStyle(.secondary)

            if let error {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .textSelection(.enabled)
            }

            if let summary {
                NetworkProbeResultView(summary: summary)
            }
        }
        .padding(14)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct NetworkProbeResultView: View {
    let summary: NetworkProbeSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label(kindTitle, systemImage: summary.succeeded ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(summary.succeeded ? .green : .orange)
                    .font(.callout.weight(.semibold))

                Text(summary.host)
                    .font(.callout.monospaced())
                    .textSelection(.enabled)

                Text(summary.ranAt.localizedShortTimeString())
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            Text(summary.summary)
                .font(.callout)
                .textSelection(.enabled)

            if !summary.outputLines.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(summary.outputLines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .textSelection(.enabled)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background.opacity(0.65), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

            Text(summary.source)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var kindTitle: String {
        switch summary.kind {
        case .ping:
            return L10n.string("network.toolkit.pingResult")
        case .traceroute:
            return L10n.string("network.toolkit.traceResult")
        }
    }
}
