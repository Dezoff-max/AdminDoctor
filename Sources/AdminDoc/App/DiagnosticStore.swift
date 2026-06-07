import AdminDocCore
import Foundation

@MainActor
final class DiagnosticStore: ObservableObject {
    @Published private(set) var results: [DiagnosticResult] = []
    @Published private(set) var isRunning = false
    @Published private(set) var lastRunDate: Date?
    @Published private(set) var cleanupSnapshot: CleanupSnapshot?
    @Published private(set) var isScanningCleanup = false
    @Published private(set) var isCleaning = false
    @Published private(set) var isClearingDNSCache = false
    @Published private(set) var networkCacheSummary: NetworkCacheFlushSummary?
    @Published private(set) var adminPrivilegeState: AdminPrivilegeState = .notRequested
    @Published var selectedCleanupIDs: Set<UUID> = []
    @Published var exportError: String?
    @Published var cleanupError: String?
    @Published var cleanupNotice: String?
    @Published var networkCacheError: String?

    private let runner: any CommandRunning
    private let suite: DiagnosticSuite
    private let exporter = ReportExporter()
    private let cleanupService: DiskCleanupService
    private let networkCacheService: NetworkCacheService
    private let adminPrivilegeManager: AdminPrivilegeManager
    private var didRequestLaunchPrivileges = false

    init(
        runner: any CommandRunning = ProcessRunner(),
        cleanupService: DiskCleanupService = DiskCleanupService(),
        networkCacheService: NetworkCacheService? = nil,
        adminPrivilegeManager: AdminPrivilegeManager = AdminPrivilegeManager()
    ) {
        self.runner = runner
        self.suite = DiagnosticSuite.default(runner: runner)
        self.cleanupService = cleanupService
        self.networkCacheService = networkCacheService ?? NetworkCacheService(runner: runner)
        self.adminPrivilegeManager = adminPrivilegeManager
    }

    func runDiagnostics() async {
        guard !isRunning else {
            return
        }

        isRunning = true
        exportError = nil
        let suite = self.suite
        let collected = await Task.detached(priority: .userInitiated) {
            suite.collect()
        }.value

        results = collected.sorted {
            if $0.category.rawValue != $1.category.rawValue {
                return categoryOrder($0.category) < categoryOrder($1.category)
            }
            if $0.severity.sortPriority != $1.severity.sortPriority {
                return $0.severity.sortPriority < $1.severity.sortPriority
            }
            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
        lastRunDate = Date()
        isRunning = false
    }

    func requestAdminPrivilegesAtLaunch() async {
        guard !didRequestLaunchPrivileges else {
            return
        }

        didRequestLaunchPrivileges = true
        adminPrivilegeState = AdminPrivilegeState(
            status: .requesting,
            requestedAt: Date(),
            message: L10n.string("admin.message.requesting")
        )

        let manager = adminPrivilegeManager
        let state = await Task.detached(priority: .userInitiated) {
            manager.requestAdminRights()
        }.value

        adminPrivilegeState = state
    }

    func results(for category: DiagnosticCategory) -> [DiagnosticResult] {
        results.filter { $0.category == category }
    }

    func summary(for category: DiagnosticCategory) -> CategorySummary {
        CategorySummary(category: category, results: results(for: category))
    }

    func writeReport(format: ReportFormat, to url: URL) throws {
        let context = RedactionContext.current(runner: runner, results: results)
        switch format {
        case .markdown:
            let markdown = exporter.markdown(results: results, context: context)
            try markdown.write(to: url, atomically: true, encoding: .utf8)
        case .json:
            let data = try exporter.jsonData(results: results, context: context)
            try data.write(to: url, options: [.atomic])
        }
    }

    func scanCleanup(clearNotice: Bool = true) async {
        guard !isScanningCleanup else {
            return
        }

        isScanningCleanup = true
        cleanupError = nil
        if clearNotice {
            cleanupNotice = nil
        }

        let service = cleanupService
        let result = await Task.detached(priority: .userInitiated) {
            Result { try service.scan() }
        }.value

        switch result {
        case .success(let snapshot):
            cleanupSnapshot = snapshot
            selectedCleanupIDs = Set(snapshot.candidates.filter { $0.defaultSelected && !$0.requiresPrivilegedHelper }.map(\.id))
        case .failure(let error):
            cleanupError = error.localizedDescription
        }

        isScanningCleanup = false
    }

    func moveSelectedCleanupItemsToTrash() async {
        guard
            !isCleaning,
            let snapshot = cleanupSnapshot
        else {
            return
        }

        let selectedCandidates = snapshot.candidates.filter { selectedCleanupIDs.contains($0.id) && !$0.requiresPrivilegedHelper }
        guard !selectedCandidates.isEmpty else {
            cleanupNotice = L10n.string("cleanup.noSelection")
            return
        }

        isCleaning = true
        cleanupError = nil
        cleanupNotice = nil

        let service = cleanupService
        let summary = await Task.detached(priority: .userInitiated) {
            service.moveToTrash(selectedCandidates)
        }.value

        selectedCleanupIDs.removeAll()
        cleanupNotice = cleanupNotice(for: summary)
        isCleaning = false
        await scanCleanup(clearNotice: false)
    }

    func clearDNSCache() async {
        guard !isClearingDNSCache else {
            return
        }

        isClearingDNSCache = true
        networkCacheError = nil

        let service = networkCacheService
        let summary = await Task.detached(priority: .userInitiated) {
            service.flushDNSCache()
        }.value

        networkCacheSummary = summary
        if !summary.succeeded {
            networkCacheError = summary.message
        }
        isClearingDNSCache = false
    }

    var totalSummary: (fail: Int, warning: Int, pass: Int, info: Int) {
        (
            results.filter { $0.severity == .fail }.count,
            results.filter { $0.severity == .warning }.count,
            results.filter { $0.severity == .pass }.count,
            results.filter { $0.severity == .info }.count
        )
    }

    private func categoryOrder(_ category: DiagnosticCategory) -> Int {
        DiagnosticCategory.allCases.firstIndex(of: category) ?? Int.max
    }

    private func cleanupNotice(for summary: CleanupExecutionSummary) -> String {
        if summary.trashed.isEmpty, !summary.failures.isEmpty {
            return L10n.format("cleanup.notice.failedOnly", summary.failures.count)
        }

        if !summary.failures.isEmpty {
            return L10n.format("cleanup.notice.mixed", summary.trashed.count, summary.failures.count)
        }

        return L10n.format("cleanup.notice.trashed", summary.trashed.count, summary.reclaimedBytesLabel)
    }
}
