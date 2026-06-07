import Foundation

public enum NetworkProbeKind: String, Codable, Sendable {
    case ping
    case traceroute
}

public struct NetworkProbeSummary: Codable, Equatable, Sendable {
    public var kind: NetworkProbeKind
    public var host: String
    public var ranAt: Date
    public var succeeded: Bool
    public var summary: String
    public var outputLines: [String]
    public var source: String
}

public enum NetworkToolkitError: Error, Equatable, LocalizedError {
    case invalidHost
    case commandFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidHost:
            return "Enter a host name or IP address."
        case .commandFailed(let command):
            return "Network tool failed to run: \(command)"
        }
    }
}

public enum NetworkToolkitParser {
    public static func pingSummary(output: String, succeeded: Bool) -> String {
        if
            let loss = ParserHelpers.firstCapture(in: output, pattern: #"([0-9.]+%) packet loss"#),
            let average = ParserHelpers.firstCapture(in: output, pattern: #"round-trip min/avg/max/(?:stddev|mdev) = [0-9.]+/([0-9.]+)/"#)
        {
            return "Average \(average) ms, \(loss) packet loss."
        }

        if let transmitted = ParserHelpers.firstCapture(in: output, pattern: #"(\d+ packets transmitted, \d+ packets received, [0-9.]+% packet loss)"#) {
            return transmitted
        }

        return succeeded ? "Ping completed." : "Ping failed."
    }

    public static func tracerouteSummary(output: String, succeeded: Bool) -> String {
        let hopCount = ParserHelpers.trimmedNonEmptyLines(output)
            .filter { line in
                line.range(of: #"^\d+\s+"#, options: .regularExpression) != nil
            }
            .count

        if hopCount > 0 {
            return "\(hopCount) hop(s) returned."
        }

        return succeeded ? "Traceroute completed." : "Traceroute failed."
    }
}

public final class NetworkToolkitService: @unchecked Sendable {
    private let runner: any CommandRunning
    private let now: @Sendable () -> Date

    public init(runner: any CommandRunning, now: @escaping @Sendable () -> Date = { Date() }) {
        self.runner = runner
        self.now = now
    }

    public func ping(host rawHost: String) throws -> NetworkProbeSummary {
        let host = try sanitizedHost(rawHost)
        let command = Command("/sbin/ping", arguments: ["-c", "4", "-W", "1000", host], timeout: 8)
        let result = try run(command)
        let output = mergedOutput(result)
        return NetworkProbeSummary(
            kind: .ping,
            host: host,
            ranAt: now(),
            succeeded: result.succeeded,
            summary: NetworkToolkitParser.pingSummary(output: output, succeeded: result.succeeded),
            outputLines: clippedLines(output),
            source: command.displayName
        )
    }

    public func traceroute(host rawHost: String) throws -> NetworkProbeSummary {
        let host = try sanitizedHost(rawHost)
        let command = Command("/usr/sbin/traceroute", arguments: ["-m", "8", "-q", "1", host], timeout: 14)
        let result = try run(command)
        let output = mergedOutput(result)
        return NetworkProbeSummary(
            kind: .traceroute,
            host: host,
            ranAt: now(),
            succeeded: result.succeeded,
            summary: NetworkToolkitParser.tracerouteSummary(output: output, succeeded: result.succeeded),
            outputLines: clippedLines(output),
            source: command.displayName
        )
    }

    private func sanitizedHost(_ value: String) throws -> String {
        let host = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !host.isEmpty,
            host.count <= 253,
            host.range(of: #"^[A-Za-z0-9.:\-]+$"#, options: .regularExpression) != nil
        else {
            throw NetworkToolkitError.invalidHost
        }

        return host
    }

    private func run(_ command: Command) throws -> CommandResult {
        do {
            return try runner.run(command)
        } catch {
            throw NetworkToolkitError.commandFailed(command.displayName)
        }
    }

    private func mergedOutput(_ result: CommandResult) -> String {
        [result.stdout, result.stderr]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private func clippedLines(_ output: String) -> [String] {
        Array(ParserHelpers.trimmedNonEmptyLines(output).prefix(80))
    }
}
