import AdminDocCore
import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var store: DiagnosticStore
    @SceneStorage("selectedCategory") private var selectedCategoryRaw = DiagnosticCategory.system.rawValue

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
                }
            )
        }
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
                        export(.markdown)
                    }
                    .disabled(store.results.isEmpty)

                    Button(L10n.string("common.json")) {
                        export(.json)
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
            try? await Task.sleep(nanoseconds: 500_000_000)
            await store.requestAdminPrivilegesAtLaunch()
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
    }

    private func export(_ format: ReportFormat) {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "AdminDoc-support-report.\(format.fileExtension)"

        switch format {
        case .markdown:
            panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        case .json:
            panel.allowedContentTypes = [.json]
        }

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            try store.writeReport(format: format, to: url)
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
