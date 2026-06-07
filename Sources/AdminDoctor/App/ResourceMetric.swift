import AdminDoctorCore
import Foundation

struct ResourceMetric: Identifiable, Equatable {
    enum Kind: String {
        case cpu
        case memory
        case disk
        case network
    }

    var id: Kind { kind }
    var kind: Kind
    var value: String
    var fraction: Double

    static func make(
        results: [DiagnosticResult],
        localNetworkScanSnapshot: LocalNetworkScanSnapshot?
    ) -> [ResourceMetric] {
        [
            cpuMetric(results),
            memoryMetric(results),
            diskMetric(results),
            networkMetric(results, localNetworkScanSnapshot: localNetworkScanSnapshot)
        ].compactMap { $0 }
    }

    private static func cpuMetric(_ results: [DiagnosticResult]) -> ResourceMetric? {
        guard
            let result = results.first(where: { $0.title == "CPU load" }),
            let load = detailValue("5 min", in: result).flatMap(Double.init),
            let cpuCount = detailValue("Logical CPUs", in: result).flatMap(Double.init),
            cpuCount > 0
        else {
            return nil
        }

        return ResourceMetric(
            kind: .cpu,
            value: "\(String(format: "%.2f", load))/\(Int(cpuCount))",
            fraction: min(max(load / cpuCount, 0), 1)
        )
    }

    private static func memoryMetric(_ results: [DiagnosticResult]) -> ResourceMetric? {
        guard
            let result = results.first(where: { $0.title == "Memory" }),
            let percent = firstPercent(in: result.summary)
        else {
            return nil
        }

        return ResourceMetric(kind: .memory, value: "\(percent)%", fraction: Double(percent) / 100)
    }

    private static func diskMetric(_ results: [DiagnosticResult]) -> ResourceMetric? {
        guard
            let result = results.first(where: { $0.title == "System volume free space" }),
            let percent = detailValue("Used percent", in: result).flatMap(firstPercent)
        else {
            return nil
        }

        return ResourceMetric(kind: .disk, value: "\(percent)%", fraction: Double(percent) / 100)
    }

    private static func networkMetric(
        _ results: [DiagnosticResult],
        localNetworkScanSnapshot: LocalNetworkScanSnapshot?
    ) -> ResourceMetric? {
        if let localNetworkScanSnapshot {
            let deviceCount = localNetworkScanSnapshot.devices.count
            return ResourceMetric(
                kind: .network,
                value: "\(deviceCount) LAN",
                fraction: min(Double(deviceCount) / 32, 1)
            )
        }

        guard
            let result = results.first(where: { $0.title == "Network interfaces" }),
            let activeCount = firstInteger(in: result.summary)
        else {
            return nil
        }

        return ResourceMetric(
            kind: .network,
            value: "\(activeCount) IPv4",
            fraction: activeCount > 0 ? 1 : 0
        )
    }

    private static func detailValue(_ key: String, in result: DiagnosticResult) -> String? {
        result.details.first(where: { $0.key == key })?.value
    }

    private static func firstPercent(in value: String) -> Int? {
        guard let match = value.range(of: #"\d+(?=%)"#, options: .regularExpression) else {
            return nil
        }

        return Int(value[match])
    }

    private static func firstInteger(in value: String) -> Int? {
        guard let match = value.range(of: #"\d+"#, options: .regularExpression) else {
            return nil
        }

        return Int(value[match])
    }
}
