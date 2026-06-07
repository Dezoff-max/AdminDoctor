import AdminDoctorCore
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
    @Published private(set) var isScanningLocalNetwork = false
    @Published private(set) var isRunningNetworkProbe = false
    @Published private(set) var isManagingPrivilegedHelper = false
    @Published private(set) var isRunningPrivilegedCleanup = false
    @Published private(set) var networkCacheSummary: NetworkCacheFlushSummary?
    @Published private(set) var localNetworkScanSnapshot: LocalNetworkScanSnapshot?
    @Published private(set) var networkProbeSummary: NetworkProbeSummary?
    @Published private(set) var privilegedHelperStatus: PrivilegedHelperStatus
    @Published private(set) var privilegedCleanupPlan: PrivilegedCleanupPlan?
    @Published private(set) var adminPrivilegeState: AdminPrivilegeState = .notRequested
    @Published private(set) var scanHistory: [ScanHistoryEntry] = []
    @Published var selectedCleanupIDs: Set<UUID> = []
    @Published var exportError: String?
    @Published var cleanupError: String?
    @Published var cleanupNotice: String?
    @Published var cleanupFailures: [CleanupFailure] = []
    @Published var networkCacheError: String?
    @Published var localNetworkScanError: String?
    @Published var networkProbeError: String?
    @Published var privilegedHelperMessage: String?
    @Published var privilegedCleanupNotice: String?

    private let runner: any CommandRunning
    private let suite: DiagnosticSuite
    private let exporter = ReportExporter()
    private let cleanupService: DiskCleanupService
    private let networkCacheService: NetworkCacheService
    private let localNetworkScanner: LocalNetworkScanner
    private let networkToolkitService: NetworkToolkitService
    private let privilegedHelperStatusService: PrivilegedHelperStatusService
    private let privilegedHelperController: PrivilegedHelperController
    private let adminPrivilegeManager: AdminPrivilegeManager
    private var didRequestLaunchPrivileges = false
    private let scanHistoryLimit = 20
    private let scanHistoryDefaultsKey = "scanHistory"

    init(
        runner: any CommandRunning = ProcessRunner(),
        cleanupService: DiskCleanupService = DiskCleanupService(),
        networkCacheService: NetworkCacheService? = nil,
        localNetworkScanner: LocalNetworkScanner? = nil,
        networkToolkitService: NetworkToolkitService? = nil,
        privilegedHelperStatusService: PrivilegedHelperStatusService? = nil,
        privilegedHelperController: PrivilegedHelperController = PrivilegedHelperController(),
        adminPrivilegeManager: AdminPrivilegeManager = AdminPrivilegeManager()
    ) {
        self.runner = runner
        self.suite = DiagnosticSuite.default(runner: runner)
        self.cleanupService = cleanupService
        self.networkCacheService = networkCacheService ?? NetworkCacheService(runner: runner)
        self.localNetworkScanner = localNetworkScanner ?? LocalNetworkScanner(runner: runner)
        self.networkToolkitService = networkToolkitService ?? NetworkToolkitService(runner: runner)
        let helperStatusService = privilegedHelperStatusService ?? PrivilegedHelperStatusService(runner: runner)
        self.privilegedHelperStatusService = helperStatusService
        self.privilegedHelperController = privilegedHelperController
        self.adminPrivilegeManager = adminPrivilegeManager
        self.scanHistory = Self.loadScanHistory(key: scanHistoryDefaultsKey)
        self.privilegedHelperStatus = helperStatusService.status(bundledToolPath: Self.bundledPrivilegedHelperPath())
            .withRuntimeStatus(serviceManagementStatus: privilegedHelperController.serviceStatusTitle(), xpcVersion: nil)
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

        let sortedResults = collected.sorted {
            if $0.category.rawValue != $1.category.rawValue {
                return categoryOrder($0.category) < categoryOrder($1.category)
            }
            if $0.severity.sortPriority != $1.severity.sortPriority {
                return $0.severity.sortPriority < $1.severity.sortPriority
            }
            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
        let finishedAt = Date()
        results = sortedResults
        lastRunDate = finishedAt
        recordScanHistory(startedAt: finishedAt, results: sortedResults)
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
        let preview = try makeReportPreview(format: format)
        try preview.data.write(to: url, options: [.atomic])
    }

    func makeReportPreview(format: ReportFormat) throws -> ReportPreview {
        let context = RedactionContext.current(runner: runner, results: results)
        switch format {
        case .markdown:
            let markdown = exporter.markdown(results: results, context: context)
            return ReportPreview(
                format: format,
                title: L10n.string("common.markdown"),
                kind: .text,
                text: markdown,
                data: Data(markdown.utf8)
            )
        case .json:
            let data = try exporter.jsonData(results: results, context: context)
            let text = String(data: data, encoding: .utf8) ?? ""
            return ReportPreview(
                format: format,
                title: L10n.string("common.json"),
                kind: .text,
                text: text,
                data: data
            )
        case .html:
            let html = exporter.html(results: results, context: context)
            return ReportPreview(
                format: format,
                title: L10n.string("common.html"),
                kind: .html,
                text: html,
                data: Data(html.utf8)
            )
        case .pdf:
            let report = exporter.report(results: results, context: context)
            let data = PDFReportRenderer.data(report: report)
            return ReportPreview(
                format: format,
                title: L10n.string("common.pdf"),
                kind: .pdf,
                text: exporter.markdown(results: results, context: context),
                data: data
            )
        }
    }

    func scanCleanup(clearNotice: Bool = true) async {
        guard !isScanningCleanup else {
            return
        }

        isScanningCleanup = true
        cleanupError = nil
        privilegedCleanupPlan = nil
        privilegedCleanupNotice = nil
        if clearNotice {
            cleanupNotice = nil
            cleanupFailures = []
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
        cleanupFailures = []

        let service = cleanupService
        let summary = await Task.detached(priority: .userInitiated) {
            service.moveToTrash(selectedCandidates)
        }.value

        let trashedPaths = Set(summary.trashed.map(\.path))
        selectedCleanupIDs.removeAll()
        cleanupNotice = cleanupNotice(for: summary)
        cleanupFailures = summary.failures
        isCleaning = false
        await scanCleanup(clearNotice: false)

        if
            !trashedPaths.isEmpty,
            let cleanupSnapshot,
            cleanupSnapshot.candidates.contains(where: { trashedPaths.contains($0.path) })
        {
            cleanupNotice = [cleanupNotice, L10n.string("cleanup.notice.recreated")]
                .compactMap { $0 }
                .joined(separator: "\n")
        }
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

    func scanLocalNetwork() async {
        guard !isScanningLocalNetwork else {
            return
        }

        isScanningLocalNetwork = true
        localNetworkScanError = nil

        let scanner = localNetworkScanner
        let result = await Task.detached(priority: .userInitiated) {
            Result { try scanner.scan() }
        }.value

        switch result {
        case .success(let snapshot):
            localNetworkScanSnapshot = snapshot
        case .failure(let error):
            localNetworkScanError = error.localizedDescription
        }

        isScanningLocalNetwork = false
    }

    func clearLocalNetworkScan() {
        guard !isScanningLocalNetwork else {
            return
        }

        localNetworkScanSnapshot = nil
        localNetworkScanError = nil
    }

    func localNetworkCSVData() -> Data? {
        localNetworkScanSnapshot.map(LocalNetworkCSVExporter.data(snapshot:))
    }

    func ping(host: String) async {
        await runNetworkProbe(host: host, kind: .ping)
    }

    func traceroute(host: String) async {
        await runNetworkProbe(host: host, kind: .traceroute)
    }

    func dnsLookup(host: String) async {
        await runNetworkProbe(host: host, kind: .dnsLookup)
    }

    func routeTable() async {
        await runNetworkProbe(host: "", kind: .routeTable)
    }

    func captivePortal() async {
        await runNetworkProbe(host: "", kind: .captivePortal)
    }

    func proxyReachability() async {
        await runNetworkProbe(host: "", kind: .proxyReachability)
    }

    func externalIP() async {
        await runNetworkProbe(host: "", kind: .externalIP)
    }

    func refreshPrivilegedHelperStatus() {
        let currentVersion = privilegedHelperStatus.xpcVersion
        privilegedHelperStatus = privilegedHelperStatusService.status(bundledToolPath: Self.bundledPrivilegedHelperPath())
            .withRuntimeStatus(
                serviceManagementStatus: privilegedHelperController.serviceStatusTitle(),
                xpcVersion: currentVersion
            )
    }

    func registerPrivilegedHelper() async {
        let controller = privilegedHelperController
        await runPrivilegedHelperOperation(successMessage: L10n.string("helper.operation.registered")) {
            try controller.register()
        }
    }

    func unregisterPrivilegedHelper() async {
        let controller = privilegedHelperController
        await runPrivilegedHelperOperation(successMessage: L10n.string("helper.operation.unregistered")) {
            try controller.unregister()
        }
    }

    func pingPrivilegedHelper() async {
        guard !isManagingPrivilegedHelper else {
            return
        }

        isManagingPrivilegedHelper = true
        privilegedHelperMessage = nil

        let controller = privilegedHelperController
        let result = await Task.detached(priority: .userInitiated) {
            Result { try controller.helperVersion() }
        }.value

        switch result {
        case .success(let version):
            privilegedHelperStatus = privilegedHelperStatusService.status(bundledToolPath: Self.bundledPrivilegedHelperPath())
                .withRuntimeStatus(
                    serviceManagementStatus: privilegedHelperController.serviceStatusTitle(),
                    xpcVersion: version
                )
            privilegedHelperMessage = L10n.format("helper.operation.pinged", version)
        case .failure(let error):
            refreshPrivilegedHelperStatus()
            privilegedHelperMessage = error.localizedDescription
        }

        isManagingPrivilegedHelper = false
    }

    func planPrivilegedCleanup() async {
        guard !isRunningPrivilegedCleanup else {
            return
        }

        let paths = privilegedCleanupCandidatePaths()
        guard !paths.isEmpty else {
            privilegedCleanupNotice = L10n.string("cleanup.privileged.noCandidates")
            return
        }

        isRunningPrivilegedCleanup = true
        privilegedCleanupNotice = nil
        let controller = privilegedHelperController
        let result = await Task.detached(priority: .userInitiated) {
            Result { try controller.planSystemCleanup(paths: paths) }
        }.value

        switch result {
        case .success(let plan):
            privilegedCleanupPlan = plan
            privilegedCleanupNotice = L10n.format(
                "cleanup.privileged.planSummary",
                plan.eligibleCandidates.count,
                plan.eligibleBytesLabel,
                plan.rejected.count
            )
        case .failure(let error):
            privilegedCleanupNotice = error.localizedDescription
        }
        refreshPrivilegedHelperStatus()
        isRunningPrivilegedCleanup = false
    }

    func quarantinePrivilegedCleanup() async {
        guard !isRunningPrivilegedCleanup else {
            return
        }

        let paths = privilegedCleanupPlan?.eligibleCandidates.map(\.path) ?? privilegedCleanupCandidatePaths()
        guard !paths.isEmpty else {
            privilegedCleanupNotice = L10n.string("cleanup.privileged.noCandidates")
            return
        }

        isRunningPrivilegedCleanup = true
        privilegedCleanupNotice = nil
        let controller = privilegedHelperController
        let result = await Task.detached(priority: .userInitiated) {
            Result { try controller.quarantineSystemCleanup(paths: paths) }
        }.value

        switch result {
        case .success(let quarantineResult):
            privilegedCleanupNotice = L10n.format(
                "cleanup.privileged.quarantineSummary",
                quarantineResult.moved.count,
                quarantineResult.movedBytesLabel,
                quarantineResult.failures.count,
                quarantineResult.quarantineRoot
            )
            privilegedCleanupPlan = nil
            await scanCleanup(clearNotice: false)
        case .failure(let error):
            privilegedCleanupNotice = error.localizedDescription
        }
        refreshPrivilegedHelperStatus()
        isRunningPrivilegedCleanup = false
    }

    var totalSummary: (fail: Int, warning: Int, pass: Int, info: Int) {
        (
            results.filter { $0.severity == .fail }.count,
            results.filter { $0.severity == .warning }.count,
            results.filter { $0.severity == .pass }.count,
            results.filter { $0.severity == .info }.count
        )
    }

    var resourceMetrics: [ResourceMetric] {
        ResourceMetric.make(results: results, localNetworkScanSnapshot: localNetworkScanSnapshot)
    }

    private func categoryOrder(_ category: DiagnosticCategory) -> Int {
        DiagnosticCategory.allCases.firstIndex(of: category) ?? Int.max
    }

    private func runNetworkProbe(host: String, kind: NetworkProbeKind) async {
        guard !isRunningNetworkProbe else {
            return
        }

        isRunningNetworkProbe = true
        networkProbeError = nil

        let service = networkToolkitService
        let result = await Task.detached(priority: .userInitiated) {
            Result {
                switch kind {
                case .ping:
                    return try service.ping(host: host)
                case .traceroute:
                    return try service.traceroute(host: host)
                case .dnsLookup:
                    return try service.dnsLookup(host: host)
                case .routeTable:
                    return try service.routeTable()
                case .captivePortal:
                    return try service.captivePortal()
                case .proxyReachability:
                    return try service.proxyReachability()
                case .externalIP:
                    return try service.externalIP()
                }
            }
        }.value

        switch result {
        case .success(let summary):
            networkProbeSummary = summary
            if !summary.succeeded {
                networkProbeError = summary.summary
            }
        case .failure(let error):
            networkProbeError = error.localizedDescription
        }

        isRunningNetworkProbe = false
    }

    private func runPrivilegedHelperOperation(
        successMessage: String,
        operation: @escaping @Sendable () throws -> Void
    ) async {
        guard !isManagingPrivilegedHelper else {
            return
        }

        isManagingPrivilegedHelper = true
        privilegedHelperMessage = nil

        let result = await Task.detached(priority: .userInitiated) {
            Result { try operation() }
        }.value

        switch result {
        case .success:
            privilegedHelperMessage = successMessage
        case .failure(let error):
            privilegedHelperMessage = error.localizedDescription
        }

        refreshPrivilegedHelperStatus()
        isManagingPrivilegedHelper = false
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

    private func privilegedCleanupCandidatePaths() -> [String] {
        cleanupSnapshot?.candidates
            .filter(\.requiresPrivilegedHelper)
            .map(\.path) ?? []
    }

    private func recordScanHistory(startedAt: Date, results: [DiagnosticResult]) {
        let entry = ScanHistoryEntry(startedAt: startedAt, results: results)
        scanHistory = Array(([entry] + scanHistory).prefix(scanHistoryLimit))
        saveScanHistory()
    }

    private func saveScanHistory() {
        guard let data = try? JSONEncoder().encode(scanHistory) else {
            return
        }

        UserDefaults.standard.set(data, forKey: scanHistoryDefaultsKey)
    }

    private static func loadScanHistory(key: String) -> [ScanHistoryEntry] {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let history = try? JSONDecoder().decode([ScanHistoryEntry].self, from: data)
        else {
            return []
        }

        return history
    }

    private static func bundledPrivilegedHelperPath() -> String? {
        let helperURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Library")
            .appendingPathComponent("LaunchServices")
            .appendingPathComponent(PrivilegedHelperStatusService.helperExecutableName)
        return helperURL.path
    }
}
