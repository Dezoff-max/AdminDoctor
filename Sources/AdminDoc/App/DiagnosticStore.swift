import AdminDocCore
import Foundation

@MainActor
final class DiagnosticStore: ObservableObject {
    @Published private(set) var results: [DiagnosticResult] = []
    @Published private(set) var isRunning = false
    @Published private(set) var lastRunDate: Date?
    @Published var exportError: String?

    private let runner: any CommandRunning
    private let suite: DiagnosticSuite
    private let exporter = ReportExporter()

    init(runner: any CommandRunning = ProcessRunner()) {
        self.runner = runner
        self.suite = DiagnosticSuite.default(runner: runner)
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
}
