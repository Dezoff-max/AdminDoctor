import AdminDoctorCore
import SwiftUI

struct NetworkToolkitView: View {
    let summary: NetworkProbeSummary?
    let isRunning: Bool
    let error: String?
    let ping: (String) -> Void
    let traceroute: (String) -> Void
    let dnsLookup: (String) -> Void
    let routeTable: () -> Void
    let captivePortal: () -> Void
    let proxyReachability: () -> Void

    @State private var host = "1.1.1.1"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Label(L10n.string("network.toolkit.title"), systemImage: "stethoscope")
                    .font(.headline)

                Spacer()

                if isRunning {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            HStack(spacing: 8) {
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
                    dnsLookup(host)
                } label: {
                    Label(L10n.string("network.toolkit.dns"), systemImage: "magnifyingglass")
                }
                .disabled(isRunning)

                Button {
                    traceroute(host)
                } label: {
                    Label(L10n.string("network.toolkit.trace"), systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                }
                .disabled(isRunning)

                Divider()
                    .frame(height: 20)

                Button {
                    routeTable()
                } label: {
                    Label(L10n.string("network.toolkit.routes"), systemImage: "point.3.connected.trianglepath.dotted")
                }
                .disabled(isRunning)

                Button {
                    captivePortal()
                } label: {
                    Label(L10n.string("network.toolkit.captive"), systemImage: "wifi.exclamationmark")
                }
                .disabled(isRunning)

                Button {
                    proxyReachability()
                } label: {
                    Label(L10n.string("network.toolkit.proxy"), systemImage: "arrow.triangle.branch")
                }
                .disabled(isRunning)

                Spacer()
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
        case .dnsLookup:
            return L10n.string("network.toolkit.dnsResult")
        case .routeTable:
            return L10n.string("network.toolkit.routesResult")
        case .captivePortal:
            return L10n.string("network.toolkit.captiveResult")
        case .proxyReachability:
            return L10n.string("network.toolkit.proxyResult")
        }
    }
}
