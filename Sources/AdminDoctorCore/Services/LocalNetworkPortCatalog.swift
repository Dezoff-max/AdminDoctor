import Foundation

public struct LocalNetworkPortService: Codable, Equatable, Sendable {
    public var port: Int
    public var name: String
    public var detail: String

    public init(port: Int, name: String, detail: String) {
        self.port = port
        self.name = name
        self.detail = detail
    }
}
public enum LocalNetworkPortCatalog {
    private static let services: [Int: LocalNetworkPortService] = [
        22: LocalNetworkPortService(port: 22, name: "SSH", detail: "Remote shell"),
        80: LocalNetworkPortService(port: 80, name: "HTTP", detail: "Web"),
        443: LocalNetworkPortService(port: 443, name: "HTTPS", detail: "Secure web"),
        445: LocalNetworkPortService(port: 445, name: "SMB", detail: "Windows/File sharing"),
        548: LocalNetworkPortService(port: 548, name: "AFP", detail: "Apple filing"),
        631: LocalNetworkPortService(port: 631, name: "IPP", detail: "Printing"),
        9100: LocalNetworkPortService(port: 9100, name: "JetDirect", detail: "Printer"),
        5000: LocalNetworkPortService(port: 5000, name: "AirPlay/UPnP", detail: "Media or NAS"),
        7000: LocalNetworkPortService(port: 7000, name: "AirPlay", detail: "Apple media"),
        8008: LocalNetworkPortService(port: 8008, name: "HTTP alt", detail: "Device web service"),
        8080: LocalNetworkPortService(port: 8080, name: "HTTP proxy", detail: "Proxy or web UI"),
        3389: LocalNetworkPortService(port: 3389, name: "RDP", detail: "Remote desktop")
    ]

    public static func service(for port: Int) -> LocalNetworkPortService {
        services[port] ?? LocalNetworkPortService(port: port, name: "TCP \(port)", detail: "Open TCP port")
    }

    public static func displayName(for port: Int) -> String {
        let service = service(for: port)
        return "\(port) \(service.name)"
    }
}
