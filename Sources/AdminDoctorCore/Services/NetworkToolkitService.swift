import Foundation

public enum NetworkProbeKind: String, Codable, Sendable {
    case ping
    case traceroute
    case dnsLookup
    case routeTable
    case captivePortal
    case proxyReachability
    case externalIP
}

public struct ProxyEndpoint: Codable, Equatable, Sendable {
    public var kind: String
    public var host: String
    public var port: Int

    public init(kind: String, host: String, port: Int) {
        self.kind = kind
        self.host = host
        self.port = port
    }
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

    public static func dnsLookupSummary(output: String, succeeded: Bool) -> String {
        let addresses = Set(ParserHelpers.captures(in: output, pattern: #"ip_address:\s*([^\s]+)"#))
        if !addresses.isEmpty {
            return "Resolved \(addresses.count) address record(s)."
        }

        let canonicalNames = Set(ParserHelpers.captures(in: output, pattern: #"name:\s*(.+)"#))
        if !canonicalNames.isEmpty {
            return "Resolved name metadata; no address records returned."
        }

        return succeeded ? "DNS lookup completed without address records." : "DNS lookup failed."
    }

    public static func parseExternalIPAddress(_ output: String) -> String? {
        ParserHelpers.trimmedNonEmptyLines(output).first { line in
            line.range(of: #"^(\d{1,3}\.){3}\d{1,3}$"#, options: .regularExpression) != nil ||
                line.range(of: #"^[0-9a-fA-F:]{3,}$"#, options: .regularExpression) != nil
        }
    }

    public static func externalIPSummary(output: String, succeeded: Bool) -> String {
        if let address = parseExternalIPAddress(output) {
            return "External IP appears to be \(address)."
        }

        return succeeded ? "External IP lookup completed without an address." : "External IP lookup failed."
    }

    public static func routeTableSummary(output: String, succeeded: Bool) -> String {
        let defaultRoutes = ParserHelpers.trimmedNonEmptyLines(output).filter { line in
            line.range(of: #"^(default|0/1|128\.0/1)\s+"#, options: .regularExpression) != nil
        }

        if
            let gateway = ParserHelpers.firstCapture(in: output, pattern: #"^default\s+([^\s]+)"#, options: [.anchorsMatchLines])
        {
            return "Default route via \(gateway); \(defaultRoutes.count) default route row(s)."
        }

        if !defaultRoutes.isEmpty {
            return "\(defaultRoutes.count) default route row(s) found."
        }

        return succeeded ? "Route table read; no default route row found." : "Route table read failed."
    }

    public static func captivePortalSummary(output: String, succeeded: Bool) -> String {
        let lowered = output.lowercased()
        if succeeded, lowered.contains("success") {
            return "Apple captive portal probe returned the expected success page."
        }

        if lowered.contains("<html") || lowered.contains("login") || lowered.contains("portal") {
            return "Probe returned a web page that may be a captive portal."
        }

        return succeeded ? "Captive portal probe completed with an unexpected response." : "Captive portal probe failed."
    }

    public static func parseProxyEndpoints(_ output: String) -> [ProxyEndpoint] {
        let lines = keyValueLines(output)
        var endpoints: [ProxyEndpoint] = []

        if
            lines["HTTPEnable"] == "1",
            let host = lines["HTTPProxy"],
            let port = intValue(lines["HTTPPort"])
        {
            endpoints.append(ProxyEndpoint(kind: "HTTP", host: host, port: port))
        }

        if
            lines["HTTPSEnable"] == "1",
            let host = lines["HTTPSProxy"],
            let port = intValue(lines["HTTPSPort"])
        {
            endpoints.append(ProxyEndpoint(kind: "HTTPS", host: host, port: port))
        }

        if
            lines["SOCKSEnable"] == "1",
            let host = lines["SOCKSProxy"],
            let port = intValue(lines["SOCKSPort"])
        {
            endpoints.append(ProxyEndpoint(kind: "SOCKS", host: host, port: port))
        }

        return endpoints
    }

    public static func proxyReachabilitySummary(scutilOutput: String, reachabilityLines: [String]) -> String {
        let endpoints = parseProxyEndpoints(scutilOutput)
        if endpoints.isEmpty {
            return "No configured proxy endpoint requires reachability testing."
        }

        let reachable = reachabilityLines.filter { $0.localizedCaseInsensitiveContains(" reachable") }.count
        return "\(reachable) of \(endpoints.count) configured proxy endpoint(s) reachable."
    }

    private static func keyValueLines(_ output: String) -> [String: String] {
        var lines: [String: String] = [:]
        for line in ParserHelpers.trimmedNonEmptyLines(output) {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else {
                continue
            }
            lines[parts[0]] = parts[1]
        }
        return lines
    }

    private static func intValue(_ value: String?) -> Int? {
        guard let value else {
            return nil
        }
        return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
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

    public func dnsLookup(host rawHost: String) throws -> NetworkProbeSummary {
        let host = try sanitizedHost(rawHost)
        let command = Command("/usr/bin/dscacheutil", arguments: ["-q", "host", "-a", "name", host], timeout: 8)
        let result = try run(command)
        let output = mergedOutput(result)
        return NetworkProbeSummary(
            kind: .dnsLookup,
            host: host,
            ranAt: now(),
            succeeded: result.succeeded && !ParserHelpers.captures(in: output, pattern: #"ip_address:\s*([^\s]+)"#).isEmpty,
            summary: NetworkToolkitParser.dnsLookupSummary(output: output, succeeded: result.succeeded),
            outputLines: clippedLines(output),
            source: command.displayName
        )
    }

    public func routeTable() throws -> NetworkProbeSummary {
        let command = Command("/usr/sbin/netstat", arguments: ["-rn", "-f", "inet"], timeout: 8)
        let result = try run(command)
        let output = mergedOutput(result)
        return NetworkProbeSummary(
            kind: .routeTable,
            host: "local route table",
            ranAt: now(),
            succeeded: result.succeeded,
            summary: NetworkToolkitParser.routeTableSummary(output: output, succeeded: result.succeeded),
            outputLines: clippedLines(output),
            source: command.displayName
        )
    }

    public func externalIP() throws -> NetworkProbeSummary {
        let command = Command(
            "/usr/bin/dig",
            arguments: ["+short", "myip.opendns.com", "@resolver1.opendns.com"],
            timeout: 8
        )
        let result = try run(command)
        let output = mergedOutput(result)
        let address = NetworkToolkitParser.parseExternalIPAddress(output)
        return NetworkProbeSummary(
            kind: .externalIP,
            host: "resolver1.opendns.com",
            ranAt: now(),
            succeeded: result.succeeded && address != nil,
            summary: NetworkToolkitParser.externalIPSummary(output: output, succeeded: result.succeeded),
            outputLines: clippedLines(output),
            source: command.displayName
        )
    }

    public func captivePortal() throws -> NetworkProbeSummary {
        let command = Command(
            "/usr/bin/curl",
            arguments: ["--location", "--max-time", "6", "--silent", "--show-error", "http://captive.apple.com/hotspot-detect.html"],
            timeout: 8
        )
        let result = try run(command)
        let output = mergedOutput(result)
        let expectedResponse = result.succeeded && output.localizedCaseInsensitiveContains("success")
        return NetworkProbeSummary(
            kind: .captivePortal,
            host: "captive.apple.com",
            ranAt: now(),
            succeeded: expectedResponse,
            summary: NetworkToolkitParser.captivePortalSummary(output: output, succeeded: result.succeeded),
            outputLines: clippedLines(output),
            source: command.displayName
        )
    }

    public func proxyReachability() throws -> NetworkProbeSummary {
        let proxyCommand = Command("/usr/sbin/scutil", arguments: ["--proxy"], timeout: 8)
        let proxyResult = try run(proxyCommand)
        let proxyOutput = mergedOutput(proxyResult)
        let endpoints = NetworkToolkitParser.parseProxyEndpoints(proxyOutput)

        var reachabilityLines: [String] = []
        for endpoint in endpoints.prefix(4) {
            let command = Command("/usr/bin/nc", arguments: ["-G", "3", "-z", endpoint.host, "\(endpoint.port)"], timeout: 5)
            let result = try run(command)
            let status = result.succeeded ? "reachable" : "unreachable"
            reachabilityLines.append("\(endpoint.kind) \(endpoint.host):\(endpoint.port) \(status)")
        }

        let output = ([proxyOutput] + reachabilityLines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        let reachableCount = reachabilityLines.filter { $0.localizedCaseInsensitiveContains(" reachable") }.count
        return NetworkProbeSummary(
            kind: .proxyReachability,
            host: endpoints.isEmpty ? "system proxy" : "\(endpoints.count) proxy endpoint(s)",
            ranAt: now(),
            succeeded: proxyResult.succeeded && (endpoints.isEmpty || reachableCount == endpoints.count),
            summary: NetworkToolkitParser.proxyReachabilitySummary(scutilOutput: proxyOutput, reachabilityLines: reachabilityLines),
            outputLines: clippedLines(output),
            source: endpoints.isEmpty ? proxyCommand.displayName : "\(proxyCommand.displayName); nc -G 3 -z"
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
