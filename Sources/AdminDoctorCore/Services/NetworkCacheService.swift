import Foundation

public struct NetworkCacheFlushSummary: Codable, Equatable, Sendable {
    public var flushedAt: Date
    public var succeeded: Bool
    public var message: String
    public var source: String

    public init(flushedAt: Date, succeeded: Bool, message: String, source: String) {
        self.flushedAt = flushedAt
        self.succeeded = succeeded
        self.message = message
        self.source = source
    }
}

public struct NetworkCacheService: Sendable {
    private let runner: any CommandRunning
    private let now: @Sendable () -> Date

    public init(runner: any CommandRunning, now: @escaping @Sendable () -> Date = { Date() }) {
        self.runner = runner
        self.now = now
    }

    public func flushDNSCache() -> NetworkCacheFlushSummary {
        let command = Command("/usr/bin/dscacheutil", arguments: ["-flushcache"], timeout: 5)

        do {
            let result = try runner.run(command)
            if result.succeeded {
                return NetworkCacheFlushSummary(
                    flushedAt: now(),
                    succeeded: true,
                    message: "DNS cache flush requested.",
                    source: command.displayName
                )
            }

            return NetworkCacheFlushSummary(
                flushedAt: now(),
                succeeded: false,
                message: failureMessage(result),
                source: command.displayName
            )
        } catch {
            return NetworkCacheFlushSummary(
                flushedAt: now(),
                succeeded: false,
                message: error.localizedDescription,
                source: command.displayName
            )
        }
    }

    private func failureMessage(_ result: CommandResult) -> String {
        let output = [result.stderr, result.stdout]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }

        return output ?? "dscacheutil exited with code \(result.exitCode)."
    }
}
