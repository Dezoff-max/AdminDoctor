import Foundation

public struct RedactionContext: Equatable, Sendable {
    public var usernames: [String]
    public var hostnames: [String]
    public var serialNumbers: [String]
    public var wifiSSIDs: [String]

    public init(
        usernames: [String] = [],
        hostnames: [String] = [],
        serialNumbers: [String] = [],
        wifiSSIDs: [String] = []
    ) {
        self.usernames = usernames.filter { !$0.isEmpty }
        self.hostnames = hostnames.filter { !$0.isEmpty }
        self.serialNumbers = serialNumbers.filter { !$0.isEmpty }
        self.wifiSSIDs = wifiSSIDs.filter { !$0.isEmpty }
    }

    public static func current(runner: (any CommandRunning)? = nil, results: [DiagnosticResult] = []) -> RedactionContext {
        var usernames = [NSUserName(), NSFullUserName()].filter { !$0.isEmpty }
        usernames = Array(Set(usernames))

        var hostnames = [ProcessInfo.processInfo.hostName]
        if let localized = Host.current().localizedName {
            hostnames.append(localized)
        }
        hostnames = Array(Set(hostnames.filter { !$0.isEmpty }))

        var serialNumbers: [String] = []
        if
            let runner,
            let result = try? runner.run(Command("/usr/sbin/ioreg", arguments: ["-rd1", "-c", "IOPlatformExpertDevice"])),
            result.succeeded,
            let serial = SystemInfoParser.parseSerialNumber(result.stdout)
        {
            serialNumbers.append(serial)
        }

        let wifiSSIDs = results
            .flatMap(\.details)
            .filter { $0.key.localizedCaseInsensitiveContains("ssid") }
            .map(\.value)

        return RedactionContext(
            usernames: usernames,
            hostnames: hostnames,
            serialNumbers: serialNumbers,
            wifiSSIDs: wifiSSIDs
        )
    }

    public var summary: [String] {
        [
            "username",
            "hostname",
            "serial number",
            "local IP address",
            "link-local IPv6 address",
            "MAC address",
            "Wi-Fi SSID"
        ]
    }
}

public struct Redactor: Sendable {
    public init() {}

    public func redact(_ input: String, context: RedactionContext) -> String {
        var output = input

        for username in context.usernames.sorted(by: { $0.count > $1.count }) {
            output = output.replacingOccurrences(of: username, with: "[redacted-username]")
        }

        for hostname in context.hostnames.sorted(by: { $0.count > $1.count }) {
            output = output.replacingOccurrences(of: hostname, with: "[redacted-hostname]")
        }

        for serial in context.serialNumbers.sorted(by: { $0.count > $1.count }) {
            output = output.replacingOccurrences(of: serial, with: "[redacted-serial]")
        }

        for ssid in context.wifiSSIDs.sorted(by: { $0.count > $1.count }) {
            output = output.replacingOccurrences(of: ssid, with: "[redacted-ssid]")
        }

        output = replace(pattern: #"(?<![0-9])(?:10(?:\.[0-9]{1,3}){3}|192\.168(?:\.[0-9]{1,3}){2}|172\.(?:1[6-9]|2[0-9]|3[0-1])(?:\.[0-9]{1,3}){2}|169\.254(?:\.[0-9]{1,3}){2})(?![0-9])"#, in: output, with: "[redacted-local-ip]")
        output = replace(pattern: #"\bfe80(?::[0-9a-fA-F]{0,4}){2,}(?:%[A-Za-z0-9]+)?\b"#, in: output, with: "[redacted-link-local-ipv6]")
        output = replace(pattern: #"\b(?:[0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}\b"#, in: output, with: "[redacted-mac]")

        return output
    }

    private func replace(pattern: String, in input: String, with replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return input
        }
        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        return regex.stringByReplacingMatches(in: input, options: [], range: range, withTemplate: replacement)
    }
}

public extension DiagnosticResult {
    func redacted(using redactor: Redactor, context: RedactionContext) -> DiagnosticResult {
        DiagnosticResult(
            id: id,
            category: category,
            severity: severity,
            title: redactor.redact(title, context: context),
            summary: redactor.redact(summary, context: context),
            details: details.map { detail in
                DiagnosticDetail(
                    key: redactor.redact(detail.key, context: context),
                    value: redactor.redact(detail.value, context: context),
                    privacy: detail.privacy
                )
            },
            remediation: remediation.map { redactor.redact($0, context: context) },
            source: source
        )
    }
}
