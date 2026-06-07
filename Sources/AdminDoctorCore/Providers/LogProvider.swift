import Foundation

public struct LogProvider: DiagnosticProvider {
    public let category: DiagnosticCategory = .logs

    public init() {}

    public func collect() -> [DiagnosticResult] {
        [
            DiagnosticResult(
                category: .logs,
                severity: .info,
                title: "Unified log playbooks",
                summary: "Log collection is intentionally not included in the MVP run.",
                details: [
                    DiagnosticDetail(key: "Policy", value: "No logs are exported unless a future support bundle flow explicitly previews and redacts them.")
                ],
                source: "MVP policy"
            )
        ]
    }
}
