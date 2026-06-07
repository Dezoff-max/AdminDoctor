import AdminDocCore
import SwiftUI

struct CategoryDetailView: View {
    let category: DiagnosticCategory
    let results: [DiagnosticResult]
    let isRunning: Bool
    let lastRunDate: Date?
    let totalSummary: (fail: Int, warning: Int, pass: Int, info: Int)
    let adminPrivilegeState: AdminPrivilegeState
    let cleanupSnapshot: CleanupSnapshot?
    @Binding var selectedCleanupIDs: Set<UUID>
    let isScanningCleanup: Bool
    let isCleaning: Bool
    let cleanupError: String?
    let cleanupNotice: String?
    let networkCacheSummary: NetworkCacheFlushSummary?
    let isClearingDNSCache: Bool
    let networkCacheError: String?
    let scanCleanup: () -> Void
    let moveSelectedCleanupItemsToTrash: () -> Void
    let clearDNSCache: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(
                category: category,
                isRunning: isRunning,
                lastRunDate: lastRunDate,
                totalSummary: totalSummary,
                adminPrivilegeState: adminPrivilegeState
            )

            Divider()

            List {
                if category == .storage {
                    CleanupReviewView(
                        snapshot: cleanupSnapshot,
                        selectedIDs: $selectedCleanupIDs,
                        isScanning: isScanningCleanup,
                        isCleaning: isCleaning,
                        error: cleanupError,
                        notice: cleanupNotice,
                        scan: scanCleanup,
                        clean: moveSelectedCleanupItemsToTrash
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

        return L10n.format("diagnostics.status.lastRun", lastRunDate.formatted(date: .abbreviated, time: .shortened))
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
