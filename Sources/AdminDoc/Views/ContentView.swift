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
                networkCacheSummary: store.networkCacheSummary,
                isClearingDNSCache: store.isClearingDNSCache,
                networkCacheError: store.networkCacheError,
                scanCleanup: {
                    Task { await store.scanCleanup() }
                },
                moveSelectedCleanupItemsToTrash: {
                    Task { await store.moveSelectedCleanupItemsToTrash() }
                },
                clearDNSCache: {
                    Task { await store.clearDNSCache() }
                }
            )
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    Task { await store.runDiagnostics() }
                } label: {
                    Label(store.isRunning ? "Running" : "Run", systemImage: store.isRunning ? "progress.indicator" : "play.fill")
                }
                .disabled(store.isRunning)
                .help("Run diagnostics")

                Menu {
                    Button("Markdown") {
                        export(.markdown)
                    }
                    .disabled(store.results.isEmpty)

                    Button("JSON") {
                        export(.json)
                    }
                    .disabled(store.results.isEmpty)
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .help("Export redacted report")
            }
        }
        .task {
            await store.requestAdminPrivilegesAtLaunch()
            if store.results.isEmpty {
                await store.runDiagnostics()
            }
        }
        .alert("Export failed", isPresented: Binding(
            get: { store.exportError != nil },
            set: { if !$0 { store.exportError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.exportError ?? "Unknown error")
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
}
