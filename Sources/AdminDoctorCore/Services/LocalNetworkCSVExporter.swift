import Foundation

public enum LocalNetworkCSVExporter {
    public static func csv(snapshot: LocalNetworkScanSnapshot) -> String {
        let rows = snapshot.devices.map { device in
            [
                deviceStatus(device, gateway: snapshot.gateway),
                device.deviceType.rawValue,
                deviceName(device, gateway: snapshot.gateway),
                device.ipAddress,
                device.vendorName ?? "",
                device.openPorts.map(LocalNetworkPortCatalog.displayName(for:)).joined(separator: "; "),
                device.macAddress ?? "",
                device.hostname ?? "",
                device.interfaceName ?? ""
            ]
        }

        return ([[
            "Status",
            "Type",
            "Name",
            "IP",
            "Manufacturer",
            "Open ports",
            "MAC address",
            "Hostname",
            "Interface"
        ]] + rows)
        .map { $0.map(escapeCSV).joined(separator: ",") }
        .joined(separator: "\n") + "\n"
    }

    public static func data(snapshot: LocalNetworkScanSnapshot) -> Data {
        Data(csv(snapshot: snapshot).utf8)
    }

    private static func deviceStatus(_ device: LocalNetworkDevice, gateway: String?) -> String {
        device.ipAddress == gateway ? "default gateway" : "online"
    }

    private static func deviceName(_ device: LocalNetworkDevice, gateway: String?) -> String {
        if device.ipAddress == gateway {
            return "Default gateway"
        }
        return device.hostname ?? device.vendorName ?? "Device \(device.ipAddress)"
    }

    private static func escapeCSV(_ value: String) -> String {
        let needsQuotes = value.contains(",") || value.contains("\"") || value.contains("\n")
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return needsQuotes ? "\"\(escaped)\"" : escaped
    }
}
