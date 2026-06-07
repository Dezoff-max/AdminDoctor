import Foundation

public struct LocalNetworkDevice: Codable, Equatable, Identifiable, Sendable {
    public var ipAddress: String
    public var macAddress: String?
    public var hostname: String?
    public var vendorName: String?
    public var interfaceName: String?
    public var source: String

    public var id: String {
        [ipAddress, macAddress, interfaceName].compactMap { $0 }.joined(separator: "-")
    }

    public init(
        ipAddress: String,
        macAddress: String?,
        hostname: String?,
        vendorName: String? = nil,
        interfaceName: String?,
        source: String
    ) {
        self.ipAddress = ipAddress
        self.macAddress = macAddress
        self.hostname = hostname
        self.vendorName = vendorName
        self.interfaceName = interfaceName
        self.source = source
    }
}

public struct LocalNetworkScanSnapshot: Codable, Equatable, Sendable {
    public var scannedAt: Date
    public var interfaceName: String
    public var localAddress: String
    public var gateway: String?
    public var scanRangeDescription: String
    public var scannedHostCount: Int
    public var cappedToLocalSlash24: Bool
    public var devices: [LocalNetworkDevice]

    public init(
        scannedAt: Date,
        interfaceName: String,
        localAddress: String,
        gateway: String?,
        scanRangeDescription: String,
        scannedHostCount: Int,
        cappedToLocalSlash24: Bool,
        devices: [LocalNetworkDevice]
    ) {
        self.scannedAt = scannedAt
        self.interfaceName = interfaceName
        self.localAddress = localAddress
        self.gateway = gateway
        self.scanRangeDescription = scanRangeDescription
        self.scannedHostCount = scannedHostCount
        self.cappedToLocalSlash24 = cappedToLocalSlash24
        self.devices = devices
    }
}

public enum LocalNetworkScannerError: Error, LocalizedError, Equatable {
    case noLocalIPv4Network
    case commandFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noLocalIPv4Network:
            return "No active local IPv4 network was found."
        case .commandFailed(let command):
            return "Local network scan command failed: \(command)"
        }
    }
}

struct LocalIPv4Network: Equatable, Sendable {
    var interfaceName: String
    var address: String
    var addressValue: UInt32
    var prefixLength: Int
    var networkValue: UInt32
    var broadcastValue: UInt32
    var isActive: Bool

    func contains(_ ipAddress: String) -> Bool {
        guard let value = LocalNetworkParser.ipv4Value(ipAddress) else {
            return false
        }
        return value >= networkValue && value <= broadcastValue
    }
}

struct LocalNetworkScanRange: Equatable, Sendable {
    var addresses: [String]
    var cappedToLocalSlash24: Bool

    var description: String {
        guard let first = addresses.first, let last = addresses.last else {
            return ""
        }

        let firstParts = first.split(separator: ".")
        let lastParts = last.split(separator: ".")
        guard
            firstParts.count == 4,
            lastParts.count == 4,
            firstParts.prefix(3) == lastParts.prefix(3),
            let lastOctet = lastParts.last
        else {
            return "\(first)-\(last)"
        }

        return "\(first)-\(lastOctet)"
    }
}

enum LocalNetworkParser {
    static func parseLocalIPv4Networks(_ output: String) -> [LocalIPv4Network] {
        interfaceBlocks(output).compactMap { block in
            guard
                let header = block.split(whereSeparator: \.isNewline).first,
                let nameEnd = header.firstIndex(of: ":")
            else {
                return nil
            }

            let interfaceName = String(header[..<nameEnd])
            guard !isIgnoredInterfaceName(interfaceName) else {
                return nil
            }

            guard let interfaceAddress = parseInterfaceAddress(in: block) else {
                return nil
            }

            guard
                let address = interfaceAddress.address,
                isCandidateLocalAddress(address),
                let addressValue = ipv4Value(address),
                let maskToken = interfaceAddress.netmask,
                let netmask = netmaskValue(maskToken)
            else {
                return nil
            }

            let networkValue = addressValue & netmask
            let broadcastValue = networkValue | ~netmask
            let isActive = block.localizedCaseInsensitiveContains("status: active")
                || (header.contains("UP") && header.contains("RUNNING"))

            return LocalIPv4Network(
                interfaceName: interfaceName,
                address: address,
                addressValue: addressValue,
                prefixLength: netmask.nonzeroBitCount,
                networkValue: networkValue,
                broadcastValue: broadcastValue,
                isActive: isActive
            )
        }
    }

    static func parseDefaultInterface(_ output: String) -> String? {
        ParserHelpers.firstCapture(in: output, pattern: #"interface:\s*([^\s]+)"#)
    }

    static func parseDefaultGateway(_ output: String) -> String? {
        ParserHelpers.firstCapture(in: output, pattern: #"gateway:\s*([^\s]+)"#)
    }

    static func parseARPDevices(_ output: String) -> [LocalNetworkDevice] {
        let pattern = #"^(.+?)\s+\((\d{1,3}(?:\.\d{1,3}){3})\)\s+at\s+([0-9a-fA-F:]+|\(incomplete\))\s+on\s+([^\s]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else {
            return []
        }

        let range = NSRange(output.startIndex..<output.endIndex, in: output)
        return regex.matches(in: output, options: [], range: range).compactMap { match in
            guard
                let hostRange = Range(match.range(at: 1), in: output),
                let ipRange = Range(match.range(at: 2), in: output),
                let macRange = Range(match.range(at: 3), in: output),
                let interfaceRange = Range(match.range(at: 4), in: output)
            else {
                return nil
            }

            let macAddress = String(output[macRange]).lowercased()
            guard macAddress != "(incomplete)", macAddress != "ff:ff:ff:ff:ff:ff" else {
                return nil
            }

            let hostname = String(output[hostRange])
            return LocalNetworkDevice(
                ipAddress: String(output[ipRange]),
                macAddress: macAddress,
                hostname: hostname == "?" ? nil : hostname,
                vendorName: OUIVendorDatabase.shared.vendorName(for: macAddress),
                interfaceName: String(output[interfaceRange]),
                source: "arp -an"
            )
        }
    }

    static func parseResolvedHostName(_ output: String) -> String? {
        for line in ParserHelpers.trimmedNonEmptyLines(output) {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard parts.count == 2, parts[0].localizedCaseInsensitiveCompare("name") == .orderedSame else {
                continue
            }

            return normalizedHostName(parts[1])
        }

        return nil
    }

    static func normalizedHostName(_ value: String?) -> String? {
        guard var value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }

        if value == "?" || value == "(null)" {
            return nil
        }

        if value.hasSuffix(".") {
            value.removeLast()
        }

        return value.isEmpty ? nil : value
    }

    static func scanRange(for network: LocalIPv4Network, limit: Int = 254) -> LocalNetworkScanRange {
        let cappedToLocalSlash24 = network.prefixLength < 24
        let scanNetwork = cappedToLocalSlash24 ? network.addressValue & 0xffff_ff00 : network.networkValue
        let scanBroadcast = cappedToLocalSlash24 ? scanNetwork | 0x0000_00ff : network.broadcastValue

        guard scanBroadcast > scanNetwork + 1 else {
            return LocalNetworkScanRange(addresses: [], cappedToLocalSlash24: cappedToLocalSlash24)
        }

        let first = scanNetwork + 1
        let last = scanBroadcast - 1
        let hosts = Int(min(UInt32(limit), last - first + 1))
        let addresses = (0..<hosts)
            .map { dottedIPv4(first + UInt32($0)) }
            .filter { $0 != network.address }

        return LocalNetworkScanRange(addresses: addresses, cappedToLocalSlash24: cappedToLocalSlash24)
    }

    static func ipv4Value(_ address: String) -> UInt32? {
        let parts = address.split(separator: ".")
        guard parts.count == 4 else {
            return nil
        }

        var value: UInt32 = 0
        for part in parts {
            guard let octet = UInt8(String(part)) else {
                return nil
            }
            value = (value << 8) | UInt32(octet)
        }
        return value
    }

    static func dottedIPv4(_ value: UInt32) -> String {
        [
            (value >> 24) & 0xff,
            (value >> 16) & 0xff,
            (value >> 8) & 0xff,
            value & 0xff
        ]
        .map(String.init)
        .joined(separator: ".")
    }

    private static let ignoredInterfaceNames: Set<String> = [
        "lo0",
        "gif0",
        "stf0",
        "awdl0",
        "llw0"
    ]

    private static let ignoredInterfacePrefixes = [
        "utun",
        "anpi",
        "bridge"
    ]

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

    private static func isCandidateLocalAddress(_ address: String) -> Bool {
        guard
            !address.hasPrefix("127."),
            !address.hasPrefix("169.254."),
            address != "0.0.0.0",
            let value = ipv4Value(address)
        else {
            return false
        }

        return value < 0xe000_0000
    }

    static func isPrivateLANAddress(_ address: String) -> Bool {
        guard let value = ipv4Value(address) else {
            return false
        }

        let first = (value >> 24) & 0xff
        let second = (value >> 16) & 0xff
        return first == 10
            || (first == 172 && (16...31).contains(second))
            || (first == 192 && second == 168)
    }

    private static func netmaskValue(_ token: String) -> UInt32? {
        if token.hasPrefix("0x") {
            return UInt32(String(token.dropFirst(2)), radix: 16)
        }
        return ipv4Value(token)
    }

    private static func isIgnoredInterfaceName(_ name: String) -> Bool {
        ignoredInterfaceNames.contains(name)
            || ignoredInterfacePrefixes.contains { name.hasPrefix($0) }
    }

    private static func parseInterfaceAddress(in block: String) -> (address: String?, netmask: String?)? {
        for rawLine in block.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.hasPrefix("inet ") else {
                continue
            }

            let tokens = line.split(separator: " ").map(String.init)
            guard
                tokens.count >= 4,
                let addressIndex = tokens.firstIndex(of: "inet"),
                tokens.indices.contains(addressIndex + 1),
                let netmaskIndex = tokens.firstIndex(of: "netmask"),
                tokens.indices.contains(netmaskIndex + 1)
            else {
                continue
            }

            return (tokens[addressIndex + 1], tokens[netmaskIndex + 1])
        }

        return nil
    }
}

public final class LocalNetworkScanner: @unchecked Sendable {
    private let runner: any CommandRunning
    private let now: @Sendable () -> Date
    private let pingSweepEnabled: Bool
    private let nameResolutionEnabled: Bool
    private let scanConcurrency: Int

    public init(
        runner: any CommandRunning,
        now: @escaping @Sendable () -> Date = { Date() },
        pingSweepEnabled: Bool = true,
        nameResolutionEnabled: Bool = true,
        scanConcurrency: Int = 48
    ) {
        self.runner = runner
        self.now = now
        self.pingSweepEnabled = pingSweepEnabled
        self.nameResolutionEnabled = nameResolutionEnabled
        self.scanConcurrency = max(1, scanConcurrency)
    }

    public func scan() throws -> LocalNetworkScanSnapshot {
        let routeOutput = try? output(Command("/sbin/route", arguments: ["-n", "get", "default"], timeout: 3))
        let ifconfigOutput = try output(Command("/sbin/ifconfig", arguments: ["-a"], timeout: 5))
        let networks = LocalNetworkParser.parseLocalIPv4Networks(ifconfigOutput)
        let defaultInterface = routeOutput.flatMap(LocalNetworkParser.parseDefaultInterface)
        let gateway = routeOutput.flatMap(LocalNetworkParser.parseDefaultGateway)

        guard let selectedNetwork = selectNetwork(from: networks, defaultInterface: defaultInterface) else {
            throw LocalNetworkScannerError.noLocalIPv4Network
        }

        let scanRange = LocalNetworkParser.scanRange(for: selectedNetwork)
        if pingSweepEnabled {
            warmARPTable(addresses: scanRange.addresses)
        }

        let arpOutput = try output(Command("/usr/sbin/arp", arguments: ["-an"], timeout: 5))
        let parsedDevices = LocalNetworkParser.parseARPDevices(arpOutput)
        let effectiveGateway = gateway ?? inferGatewayAddress(from: parsedDevices, on: selectedNetwork)
        let resolvedHostnames = nameResolutionEnabled
            ? resolveHostnames(from: parsedDevices)
            : [:]
        let devices = parsedDevices
            .filter { device in
                device.interfaceName == selectedNetwork.interfaceName
                    && selectedNetwork.contains(device.ipAddress)
                    && device.ipAddress != selectedNetwork.address
            }
            .map { device in
                enrichDevice(device, resolvedHostnames: resolvedHostnames)
            }
            .sorted {
                guard
                    let left = LocalNetworkParser.ipv4Value($0.ipAddress),
                    let right = LocalNetworkParser.ipv4Value($1.ipAddress)
                else {
                    return $0.ipAddress.localizedStandardCompare($1.ipAddress) == .orderedAscending
                }
                return left < right
            }

        return LocalNetworkScanSnapshot(
            scannedAt: now(),
            interfaceName: selectedNetwork.interfaceName,
            localAddress: selectedNetwork.address,
            gateway: effectiveGateway,
            scanRangeDescription: scanRange.description,
            scannedHostCount: scanRange.addresses.count,
            cappedToLocalSlash24: scanRange.cappedToLocalSlash24,
            devices: devices
        )
    }

    private func enrichDevice(
        _ device: LocalNetworkDevice,
        resolvedHostnames: [String: String]
    ) -> LocalNetworkDevice {
        LocalNetworkDevice(
            ipAddress: device.ipAddress,
            macAddress: device.macAddress,
            hostname: device.hostname ?? resolvedHostnames[device.ipAddress],
            vendorName: device.vendorName,
            interfaceName: device.interfaceName,
            source: device.source
        )
    }

    private func inferGatewayAddress(
        from devices: [LocalNetworkDevice],
        on network: LocalIPv4Network
    ) -> String? {
        let firstHost = LocalNetworkParser.dottedIPv4(network.networkValue + 1)
        if devices.contains(where: { $0.interfaceName == network.interfaceName && $0.ipAddress == firstHost }) {
            return firstHost
        }

        return nil
    }

    private func selectNetwork(from networks: [LocalIPv4Network], defaultInterface: String?) -> LocalIPv4Network? {
        if let defaultInterface {
            if let matchingActive = networks.first(where: { $0.interfaceName == defaultInterface && $0.isActive && LocalNetworkParser.isPrivateLANAddress($0.address) }) {
                return matchingActive
            }
            if let matchingActive = networks.first(where: { $0.interfaceName == defaultInterface && $0.isActive }) {
                return matchingActive
            }
            if let matching = networks.first(where: { $0.interfaceName == defaultInterface }) {
                return matching
            }
        }

        return networks.first(where: { $0.isActive && $0.interfaceName.hasPrefix("en") && LocalNetworkParser.isPrivateLANAddress($0.address) })
            ?? networks.first(where: { $0.isActive && LocalNetworkParser.isPrivateLANAddress($0.address) })
            ?? networks.first(where: { $0.isActive && $0.interfaceName.hasPrefix("en") })
            ?? networks.first(where: { $0.isActive })
            ?? networks.first
    }

    private func warmARPTable(addresses: [String]) {
        guard !addresses.isEmpty else {
            return
        }

        let queue = DispatchQueue(label: "dev.admindoctor.local-network-scan", attributes: .concurrent)
        let group = DispatchGroup()
        let semaphore = DispatchSemaphore(value: scanConcurrency)

        for address in addresses {
            semaphore.wait()
            group.enter()
            queue.async {
                defer {
                    semaphore.signal()
                    group.leave()
                }

                _ = try? self.runner.run(Command("/sbin/ping", arguments: ["-c", "1", "-W", "200", address], timeout: 0.8))
            }
        }

        group.wait()
    }

    private func resolveHostnames(from devices: [LocalNetworkDevice]) -> [String: String] {
        let addresses = Array(Set(devices.filter { $0.hostname == nil }.map(\.ipAddress))).prefix(64)
        guard !addresses.isEmpty else {
            return [:]
        }

        let queue = DispatchQueue(label: "dev.admindoctor.local-network-name-resolution", attributes: .concurrent)
        let group = DispatchGroup()
        let semaphore = DispatchSemaphore(value: min(scanConcurrency, 24))
        let lock = NSLock()
        var resolved: [String: String] = [:]

        for address in addresses {
            semaphore.wait()
            group.enter()
            queue.async {
                defer {
                    semaphore.signal()
                    group.leave()
                }

                guard
                    let output = try? self.output(Command("/usr/bin/dscacheutil", arguments: ["-q", "host", "-a", "ip_address", address], timeout: 0.7)),
                    let hostname = LocalNetworkParser.parseResolvedHostName(output)
                else {
                    return
                }

                lock.lock()
                resolved[address] = hostname
                lock.unlock()
            }
        }

        group.wait()
        return resolved
    }

    private func output(_ command: Command) throws -> String {
        let result: CommandResult
        do {
            result = try runner.run(command)
        } catch {
            throw LocalNetworkScannerError.commandFailed(command.displayName)
        }

        guard result.succeeded else {
            throw LocalNetworkScannerError.commandFailed(command.displayName)
        }

        return result.stdout
    }
}
