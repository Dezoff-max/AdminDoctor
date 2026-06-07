import AdminDoctorCore
import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var store: DiagnosticStore
    @SceneStorage("selectedCategory") private var selectedCategoryRaw = DiagnosticCategory.system.rawValue
    @AppStorage(L10n.languagePreferenceKey) private var languageRaw = AppLanguage.systemDefault.rawValue
    @State private var reportPreview: ReportPreview?

    private var selectedCategory: DiagnosticCategory {
        DiagnosticCategory(rawValue: selectedCategoryRaw) ?? .system
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(
                selectedCategoryRaw: $selectedCategoryRaw,
                store: store
            )
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            CategoryDetailView(
                category: selectedCategory,
                results: store.results(for: selectedCategory),
                isRunning: store.isRunning,
                lastRunDate: store.lastRunDate,
                totalSummary: store.totalSummary,
                resourceMetrics: store.resourceMetrics,
                adminPrivilegeState: store.adminPrivilegeState,
                cleanupSnapshot: store.cleanupSnapshot,
                selectedCleanupIDs: $store.selectedCleanupIDs,
                isScanningCleanup: store.isScanningCleanup,
                isCleaning: store.isCleaning,
                cleanupError: store.cleanupError,
                cleanupNotice: store.cleanupNotice,
                cleanupFailures: store.cleanupFailures,
                networkCacheSummary: store.networkCacheSummary,
                isClearingDNSCache: store.isClearingDNSCache,
                networkCacheError: store.networkCacheError,
                localNetworkScanSnapshot: store.localNetworkScanSnapshot,
                isScanningLocalNetwork: store.isScanningLocalNetwork,
                localNetworkScanError: store.localNetworkScanError,
                networkProbeSummary: store.networkProbeSummary,
                isRunningNetworkProbe: store.isRunningNetworkProbe,
                networkProbeError: store.networkProbeError,
                privilegedHelperStatus: store.privilegedHelperStatus,
                isManagingPrivilegedHelper: store.isManagingPrivilegedHelper,
                privilegedHelperMessage: store.privilegedHelperMessage,
                scanCleanup: {
                    Task { await store.scanCleanup() }
                },
                moveSelectedCleanupItemsToTrash: {
                    Task { await store.moveSelectedCleanupItemsToTrash() }
                },
                clearDNSCache: {
                    Task { await store.clearDNSCache() }
                },
                scanLocalNetwork: {
                    Task { await store.scanLocalNetwork() }
                },
                clearLocalNetworkScan: {
                    store.clearLocalNetworkScan()
                },
                ping: { host in
                    Task { await store.ping(host: host) }
                },
                traceroute: { host in
                    Task { await store.traceroute(host: host) }
                },
                dnsLookup: { host in
                    Task { await store.dnsLookup(host: host) }
                },
                routeTable: {
                    Task { await store.routeTable() }
                },
                captivePortal: {
                    Task { await store.captivePortal() }
                },
                proxyReachability: {
                    Task { await store.proxyReachability() }
                },
                refreshPrivilegedHelperStatus: {
                    store.refreshPrivilegedHelperStatus()
                },
                registerPrivilegedHelper: {
                    Task { await store.registerPrivilegedHelper() }
                },
                unregisterPrivilegedHelper: {
                    Task { await store.unregisterPrivilegedHelper() }
                },
                pingPrivilegedHelper: {
                    Task { await store.pingPrivilegedHelper() }
                }
            )
        }
        .environment(\.locale, L10n.currentLocale)
        .id(languageRaw)
        .toolbar {
            ToolbarItemGroup {
                Button {
                    Task { await store.runDiagnostics() }
                } label: {
                    Label(store.isRunning ? L10n.string("common.running") : L10n.string("common.run"), systemImage: store.isRunning ? "progress.indicator" : "play.fill")
                }
                .disabled(store.isRunning)
                .help(L10n.string("diagnostics.run"))

                Menu {
                    Button(L10n.string("common.markdown")) {
                        previewExport(.markdown)
                    }
                    .disabled(store.results.isEmpty)

                    Button(L10n.string("common.json")) {
                        previewExport(.json)
                    }
                    .disabled(store.results.isEmpty)

                    Button(L10n.string("common.html")) {
                        previewExport(.html)
                    }
                    .disabled(store.results.isEmpty)

                    Button(L10n.string("common.pdf")) {
                        previewExport(.pdf)
                    }
                    .disabled(store.results.isEmpty)
                } label: {
                    Label(L10n.string("diagnostics.export"), systemImage: "square.and.arrow.up")
                }
                .help(L10n.string("diagnostics.export.help"))
            }
        }
        .task {
            bringWindowForward()
            store.refreshPrivilegedHelperStatus()
            try? await Task.sleep(nanoseconds: 500_000_000)
            Task {
                await store.requestAdminPrivilegesAtLaunch()
            }
            bringWindowForward()
            if store.results.isEmpty {
                await store.runDiagnostics()
            }
            bringWindowForward()
        }
        .alert(L10n.string("diagnostics.export.failed"), isPresented: Binding(
            get: { store.exportError != nil },
            set: { if !$0 { store.exportError = nil } }
        )) {
            Button(L10n.string("common.ok"), role: .cancel) {}
        } message: {
            Text(store.exportError ?? L10n.string("diagnostics.unknownError"))
        }
        .sheet(item: $reportPreview) { preview in
            ReportPreviewSheet(preview: preview) {
                save(preview)
            }
        }
    }

    private func previewExport(_ format: ReportFormat) {
        do {
            reportPreview = try store.makeReportPreview(format: format)
        } catch {
            store.exportError = error.localizedDescription
        }
    }

    private func save(_ preview: ReportPreview) {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "AdminDoctor-support-report.\(preview.format.fileExtension)"

        switch preview.format {
        case .markdown:
            panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        case .json:
            panel.allowedContentTypes = [.json]
        case .html:
            panel.allowedContentTypes = [.html]
        case .pdf:
            panel.allowedContentTypes = [.pdf]
        }

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            try preview.data.write(to: url, options: [.atomic])
            reportPreview = nil
        } catch {
            store.exportError = error.localizedDescription
        }
    }

    @MainActor
    private func bringWindowForward() {
        NSApp.setActivationPolicy(.regular)
        NSApp.unhide(nil)

        if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        }

        NSApp.activate(ignoringOtherApps: true)
    }
}
