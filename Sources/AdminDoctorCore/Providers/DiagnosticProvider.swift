import Foundation

public protocol DiagnosticProvider: Sendable {
    var category: DiagnosticCategory { get }
    func collect() -> [DiagnosticResult]
}

public struct DiagnosticSuite: Sendable {
    public var providers: [any DiagnosticProvider]

    public init(providers: [any DiagnosticProvider]) {
        self.providers = providers
    }

    public static func `default`(runner: any CommandRunning) -> DiagnosticSuite {
        DiagnosticSuite(providers: [
            SystemInfoProvider(runner: runner),
            StorageProvider(runner: runner),
            SecurityProvider(runner: runner),
            NetworkProvider(runner: runner),
            ProfilesProvider(runner: runner),
            LaunchdProvider(),
            LogProvider()
        ])
    }

    public func collect() -> [DiagnosticResult] {
        providers.flatMap { $0.collect() }
    }
}
