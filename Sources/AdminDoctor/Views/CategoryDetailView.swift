import AdminDoctorCore
import SwiftUI

struct CategoryDetailView: View {
    let category: DiagnosticCategory
    let results: [DiagnosticResult]
    let isRunning: Bool
    let lastRunDate: Date?
    let totalSummary: (fail: Int, warning: Int, pass: Int, info: Int)
    let resourceMetrics: [ResourceMetric]
    let adminPrivilegeState: AdminPrivilegeState
    let cleanupSnapshot: CleanupSnapshot?
    @Binding var selectedCleanupIDs: Set<UUID>
    let isScanningCleanup: Bool
    let isCleaning: Bool
    let cleanupError: String?
    let cleanupNotice: String?
    let cleanupFailures: [CleanupFailure]
    let privilegedCleanupPlan: PrivilegedCleanupPlan?
    let privilegedCleanupNotice: String?
    let isRunningPrivilegedCleanup: Bool
    let networkCacheSummary: NetworkCacheFlushSummary?
    let isClearingDNSCache: Bool
    let networkCacheError: String?
    let localNetworkScanSnapshot: LocalNetworkScanSnapshot?
    let isScanningLocalNetwork: Bool
    let localNetworkScanError: String?
    let networkProbeSummary: NetworkProbeSummary?
    let isRunningNetworkProbe: Bool
    let networkProbeError: String?
    let privilegedHelperStatus: PrivilegedHelperStatus
    let isManagingPrivilegedHelper: Bool
    let privilegedHelperMessage: String?
    let scanCleanup: () -> Void
    let moveSelectedCleanupItemsToTrash: () -> Void
    let planPrivilegedCleanup: () -> Void
    let quarantinePrivilegedCleanup: () -> Void
    let clearDNSCache: () -> Void
    let scanLocalNetwork: () -> Void
    let clearLocalNetworkScan: () -> Void
    let exportLocalNetworkCSV: () -> Void
    let ping: (String) -> Void
    let traceroute: (String) -> Void
    let dnsLookup: (String) -> Void
    let routeTable: () -> Void
    let captivePortal: () -> Void
    let proxyReachability: () -> Void
    let externalIP: () -> Void
    let refreshPrivilegedHelperStatus: () -> Void
    let registerPrivilegedHelper: () -> Void
    let unregisterPrivilegedHelper: () -> Void
    let pingPrivilegedHelper: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(
                category: category,
                isRunning: isRunning,
                lastRunDate: lastRunDate,
                totalSummary: totalSummary,
                resourceMetrics: resourceMetrics,
                adminPrivilegeState: adminPrivilegeState
            )

            Divider()

            List {
                if category == .storage {
                    PrivilegedHelperStatusView(
                        status: privilegedHelperStatus,
                        isManaging: isManagingPrivilegedHelper,
                        message: privilegedHelperMessage,
                        refresh: refreshPrivilegedHelperStatus,
                        register: registerPrivilegedHelper,
                        unregister: unregisterPrivilegedHelper,
                        ping: pingPrivilegedHelper
                    )
                    .listRowSeparator(.hidden)

                    CleanupReviewView(
                        snapshot: cleanupSnapshot,
                        selectedIDs: $selectedCleanupIDs,
                        isScanning: isScanningCleanup,
                        isCleaning: isCleaning,
                        error: cleanupError,
                        notice: cleanupNotice,
                        failures: cleanupFailures,
                        privilegedPlan: privilegedCleanupPlan,
                        privilegedNotice: privilegedCleanupNotice,
                        isRunningPrivilegedCleanup: isRunningPrivilegedCleanup,
                        scan: scanCleanup,
                        clean: moveSelectedCleanupItemsToTrash,
                        planPrivilegedCleanup: planPrivilegedCleanup,
                        quarantinePrivilegedCleanup: quarantinePrivilegedCleanup
                    )
                    .listRowSeparator(.hidden)
                }

                if category == .network {
                    NetworkCacheView(
                        summary: networkCacheSummary,
                        isClearing: isClearingDNSCache,
                        error: networkCacheError,
                        clearDNSCache: clearDNSCache
                    )
                    .listRowSeparator(.hidden)

                    NetworkToolkitView(
                        summary: networkProbeSummary,
                        isRunning: isRunningNetworkProbe,
                        error: networkProbeError,
                        ping: ping,
                        traceroute: traceroute,
                        dnsLookup: dnsLookup,
                        routeTable: routeTable,
                        captivePortal: captivePortal,
                        proxyReachability: proxyReachability,
                        externalIP: externalIP
                    )
                    .listRowSeparator(.hidden)

                    LocalNetworkScanView(
                        snapshot: localNetworkScanSnapshot,
                        isScanning: isScanningLocalNetwork,
                        error: localNetworkScanError,
                        scan: scanLocalNetwork,
                        clear: clearLocalNetworkScan,
                        exportCSV: exportLocalNetworkCSV
                    )
                    .listRowSeparator(.hidden)
                }

                if results.isEmpty {
                    EmptyCategoryView(isRunning: isRunning)
                        .listRowSeparator(.hidden)
                        .frame(maxWidth: .infinity, minHeight: 260)
                } else {
                    ForEach(results) { result in
                        DiagnosticRowView(result: result)
                    }
                }
            }
            .listStyle(.inset)
        }
        .navigationTitle(category.localizedTitle)
    }
}

private struct HeaderView: View {
    let category: DiagnosticCategory
    let isRunning: Bool
    let lastRunDate: Date?
    let totalSummary: (fail: Int, warning: Int, pass: Int, info: Int)
    let resourceMetrics: [ResourceMetric]
    let adminPrivilegeState: AdminPrivilegeState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Label(category.localizedTitle, systemImage: category.symbolName)
                    .font(.title2.weight(.semibold))
                Spacer()
                AdminPrivilegePill(state: adminPrivilegeState)
                Text(statusText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                SeverityCountPill(title: L10n.string("severity.fail"), count: totalSummary.fail, severity: .fail)
                SeverityCountPill(title: L10n.string("severity.warning"), count: totalSummary.warning, severity: .warning)
                SeverityCountPill(title: L10n.string("severity.pass"), count: totalSummary.pass, severity: .pass)
                SeverityCountPill(title: L10n.string("severity.info"), count: totalSummary.info, severity: .info)
                Spacer()
            }

            if !resourceMetrics.isEmpty {
                ResourceOverviewView(metrics: resourceMetrics)
            }
        }
        .padding(20)
    }

    private var statusText: String {
        if isRunning {
            return L10n.string("diagnostics.runningChecks")
        }

        guard let lastRunDate else {
            return L10n.string("diagnostics.notRun")
        }

        return L10n.format("diagnostics.status.lastRun", lastRunDate.localizedShortDateTimeString())
    }
}

private struct ResourceOverviewView: View {
    let metrics: [ResourceMetric]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(metrics) { metric in
                ResourceMetricTile(metric: metric)
            }
            Spacer()
        }
    }
}

private struct ResourceMetricTile: View {
    let metric: ResourceMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: symbolName)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(metric.value)
                    .font(.caption.monospacedDigit().weight(.semibold))
            }

            ProgressView(value: metric.fraction)
                .tint(color)
                .controlSize(.small)
        }
        .frame(width: 150)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var title: String {
        L10n.string("metrics.\(metric.kind.rawValue)")
    }

    private var symbolName: String {
        switch metric.kind {
        case .cpu:
            return "cpu"
        case .memory:
            return "memorychip"
        case .disk:
            return "internaldrive"
        case .network:
            return "network"
        }
    }

    private var color: Color {
        switch metric.kind {
        case .cpu:
            return .blue
        case .memory:
            return .purple
        case .disk:
            return .orange
        case .network:
            return .green
        }
    }
}

private struct AdminPrivilegePill: View {
    let state: AdminPrivilegeState

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(state.status.localizedTitle)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .help(state.status.localizedMessage)
    }

    private var color: Color {
        switch state.status {
        case .authorized:
            return .green
        case .requesting:
            return .blue
        case .denied, .canceled, .unavailable:
            return .orange
        case .notRequested:
            return .secondary
        }
    }
}

private struct EmptyCategoryView: View {
    let isRunning: Bool

    var body: some View {
        VStack(spacing: 10) {
            if isRunning {
                ProgressView()
                    .controlSize(.small)
                Text(L10n.string("diagnostics.collecting"))
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "checklist")
                    .font(.system(size: 30))
                    .foregroundStyle(.secondary)
                Text(L10n.string("diagnostics.noFindings"))
                    .font(.headline)
                Text(L10n.string("diagnostics.runToPopulate"))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SeverityCountPill: View {
    let title: String
    let count: Int
    let severity: DiagnosticSeverity

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(severityColor)
                .frame(width: 7, height: 7)
            Text("\(count)")
                .font(.callout.monospacedDigit().weight(.semibold))
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var severityColor: Color {
        switch severity {
        case .pass:
            return .green
        case .warning:
            return .yellow
        case .fail:
            return .red
        case .info:
            return .blue
        }
    }
}
