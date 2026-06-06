import Foundation

public struct NetworkInterfaceInfo: Equatable, Sendable {
    public var name: String
    public var ipv4Addresses: [String]
    public var ipv6Addresses: [String]
    public var isActive: Bool
}

public struct ProxyInfo: Equatable, Sendable {
    public var enabled: Bool
    public var summary: String
}

public enum NetworkParser {
    public static func parseInterfaces(_ output: String) -> [NetworkInterfaceInfo] {
        let blocks = interfaceBlocks(output)
        return blocks.compactMap { block in
            guard let header = block.split(whereSeparator: \.isNewline).first else {
                return nil
            }

            let headerText = String(header)
            guard
                let nameEnd = headerText.firstIndex(of: ":"),
                headerText[headerText.startIndex..<nameEnd] != "lo0"
            else {
                return nil
            }

            let name = String(headerText[headerText.startIndex..<nameEnd])
            let ipv4 = ParserHelpers.captures(in: block, pattern: #"\binet\s+(\d{1,3}(?:\.\d{1,3}){3})"#)
                .filter { !$0.hasPrefix("127.") }
            let ipv6 = ParserHelpers.captures(in: block, pattern: #"\binet6\s+([0-9a-fA-F:]+)"#)
                .filter { $0 != "::1" }
            let lowered = block.lowercased()
            let isActive = lowered.contains("status: active") || (headerText.contains("UP") && headerText.contains("RUNNING"))

            return NetworkInterfaceInfo(name: name, ipv4Addresses: ipv4, ipv6Addresses: ipv6, isActive: isActive)
        }
    }

    public static func parseDNSServers(_ output: String) -> [String] {
        Array(Set(ParserHelpers.captures(in: output, pattern: #"nameserver\[\d+\]\s*:\s*([^\s]+)"#))).sorted()
    }

    public static func parseDefaultGateway(_ output: String) -> String? {
        ParserHelpers.firstCapture(in: output, pattern: #"gateway:\s*([^\s]+)"#)
    }

    public static func parseProxy(_ output: String) -> ProxyInfo {
        var lines: [String: String] = [:]
        for line in ParserHelpers.trimmedNonEmptyLines(output) {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else {
                continue
            }
            lines[parts[0]] = parts[1]
        }

        let httpEnabled = lines["HTTPEnable"] == "1"
        let httpsEnabled = lines["HTTPSEnable"] == "1"
        let pacEnabled = lines["ProxyAutoConfigEnable"] == "1"
        let enabled = httpEnabled || httpsEnabled || pacEnabled

        if enabled {
            let parts = [
                httpEnabled ? "HTTP" : nil,
                httpsEnabled ? "HTTPS" : nil,
                pacEnabled ? "PAC" : nil
            ].compactMap { $0 }
            return ProxyInfo(enabled: true, summary: "Configured: \(parts.joined(separator: ", "))")
        }

        return ProxyInfo(enabled: false, summary: "No system proxy enabled.")
    }

    public static func parseWiFiDevice(_ output: String) -> String? {
        let blocks = output.components(separatedBy: "\n\n")
        for block in blocks where block.localizedCaseInsensitiveContains("Hardware Port: Wi-Fi") || block.localizedCaseInsensitiveContains("Hardware Port: Airport") {
            if let device = ParserHelpers.firstCapture(in: block, pattern: #"Device:\s*([^\s]+)"#) {
                return device
            }
        }
        return nil
    }

    public static func parseSSID(_ output: String) -> String? {
        if output.localizedCaseInsensitiveContains("not associated") {
            return nil
        }
        return ParserHelpers.firstCapture(in: output, pattern: #"Current Wi-Fi Network:\s*(.+)$"#, options: [.anchorsMatchLines])?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func interfaceBlocks(_ output: String) -> [String] {
        var blocks: [String] = []
        var current: [String] = []

        for line in output.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            let isHeader = line.first?.isWhitespace == false && line.contains(":")
            if isHeader, !current.isEmpty {
                blocks.append(current.joined(separator: "\n"))
                current = []
            }
            current.append(line)
        }

        if !current.isEmpty {
            blocks.append(current.joined(separator: "\n"))
        }

        return blocks
    }
}

public struct NetworkProvider: DiagnosticProvider {
    public let category: DiagnosticCategory = .network

    private let runner: any CommandRunning

    public init(runner: any CommandRunning) {
        self.runner = runner
    }

    public func collect() -> [DiagnosticResult] {
        [
            interfacesResult(),
            dnsResult(),
            gatewayResult(),
            proxyResult(),
            wifiResult()
        ]
    }

    private func interfacesResult() -> DiagnosticResult {
        guard let raw = output(Command("/sbin/ifconfig", arguments: ["-a"])) else {
            return DiagnosticResult(
                category: .network,
                severity: .warning,
                title: "Network interfaces",
                summary: "Unable to read interface list.",
                source: "ifconfig -a"
            )
        }

        let interfaces = NetworkParser.parseInterfaces(raw)
        let active = interfaces.filter { $0.isActive && !$0.ipv4Addresses.isEmpty }
        return DiagnosticResult(
            category: .network,
            severity: active.isEmpty ? .warning : .pass,
            title: "Network interfaces",
            summary: active.isEmpty ? "No active IPv4 interface detected." : "\(active.count) active IPv4 interface(s) detected.",
            details: interfaces.map { item in
                DiagnosticDetail(
                    key: item.name,
                    value: (item.ipv4Addresses + item.ipv6Addresses).isEmpty ? "No IP address" : (item.ipv4Addresses + item.ipv6Addresses).joined(separator: ", "),
                    privacy: .sensitive
                )
            },
            remediation: active.isEmpty ? "Check link state, Wi-Fi association, VPN, or DHCP configuration." : nil,
            source: "ifconfig -a"
        )
    }

    private func dnsResult() -> DiagnosticResult {
        guard let raw = output(Command("/usr/sbin/scutil", arguments: ["--dns"])) else {
            return DiagnosticResult(
                category: .network,
                severity: .warning,
                title: "DNS",
                summary: "Unable to read DNS configuration.",
                source: "scutil --dns"
            )
        }

        let servers = NetworkParser.parseDNSServers(raw)
        return DiagnosticResult(
            category: .network,
            severity: SeverityMapping.requiredSignal(isPresent: !servers.isEmpty),
            title: "DNS",
            summary: servers.isEmpty ? "No DNS nameservers found." : "\(servers.count) DNS nameserver(s) configured.",
            details: servers.map { DiagnosticDetail(key: "Nameserver", value: $0, privacy: .sensitive) },
            remediation: servers.isEmpty ? "Check DHCP, profile-managed DNS, or manual network service DNS settings." : nil,
            source: "scutil --dns"
        )
    }

    private func gatewayResult() -> DiagnosticResult {
        guard let raw = output(Command("/sbin/route", arguments: ["-n", "get", "default"])) else {
            return DiagnosticResult(
                category: .network,
                severity: .warning,
                title: "Default gateway",
                summary: "Unable to read default route.",
                source: "route -n get default"
            )
        }

        let gateway = NetworkParser.parseDefaultGateway(raw)
        return DiagnosticResult(
            category: .network,
            severity: SeverityMapping.requiredSignal(isPresent: gateway != nil),
            title: "Default gateway",
            summary: gateway.map { "Default gateway is \($0)." } ?? "No default gateway found.",
            details: gateway.map { [DiagnosticDetail(key: "Gateway", value: $0, privacy: .sensitive)] } ?? [],
            remediation: gateway == nil ? "Check default route, VPN state, and active network service order." : nil,
            source: "route -n get default"
        )
    }

    private func proxyResult() -> DiagnosticResult {
        guard let raw = output(Command("/usr/sbin/scutil", arguments: ["--proxy"])) else {
            return DiagnosticResult(
                category: .network,
                severity: .info,
                title: "Proxy",
                summary: "Unable to read proxy settings.",
                source: "scutil --proxy"
            )
        }

        let proxy = NetworkParser.parseProxy(raw)
        return DiagnosticResult(
            category: .network,
            severity: .info,
            title: "Proxy",
            summary: proxy.summary,
            source: "scutil --proxy"
        )
    }

    private func wifiResult() -> DiagnosticResult {
        guard
            let ports = output(Command("/usr/sbin/networksetup", arguments: ["-listallhardwareports"])),
            let device = NetworkParser.parseWiFiDevice(ports),
            let raw = output(Command("/usr/sbin/networksetup", arguments: ["-getairportnetwork", device])),
            let ssid = NetworkParser.parseSSID(raw)
        else {
            return DiagnosticResult(
                category: .network,
                severity: .info,
                title: "Wi-Fi SSID",
                summary: "No active Wi-Fi SSID detected.",
                source: "networksetup -getairportnetwork"
            )
        }

        return DiagnosticResult(
            category: .network,
            severity: .info,
            title: "Wi-Fi SSID",
            summary: "Wi-Fi network is associated.",
            details: [DiagnosticDetail(key: "Wi-Fi SSID", value: ssid, privacy: .sensitive)],
            source: "networksetup -getairportnetwork"
        )
    }

    private func output(_ command: Command) -> String? {
        guard let result = try? runner.run(command), result.succeeded else {
            return nil
        }
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
