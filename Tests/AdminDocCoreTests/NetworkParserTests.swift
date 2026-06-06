import XCTest
@testable import AdminDocCore

final class NetworkParserTests: XCTestCase {
    func testParsesDefaultGateway() {
        let output = """
           route to: default
        destination: default
               mask: default
            gateway: 192.168.50.1
          interface: en0
        """

        XCTAssertEqual(NetworkParser.parseDefaultGateway(output), "192.168.50.1")
    }

    func testParsesInterfacesAndDns() {
        let ifconfig = """
        lo0: flags=8049<UP,LOOPBACK,RUNNING,MULTICAST> mtu 16384
            inet 127.0.0.1 netmask 0xff000000

        en0: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
            inet6 fe80::1234:abcd prefixlen 64 secured scopeid 0x6
            inet 192.168.50.25 netmask 0xffffff00 broadcast 192.168.50.255
            status: active
        """

        let dns = """
        resolver #1
          nameserver[0] : 192.168.50.1
          nameserver[1] : 9.9.9.9
        """

        let interfaces = NetworkParser.parseInterfaces(ifconfig)
        XCTAssertEqual(interfaces.count, 1)
        XCTAssertEqual(interfaces.first?.name, "en0")
        XCTAssertEqual(interfaces.first?.ipv4Addresses, ["192.168.50.25"])
        XCTAssertEqual(NetworkParser.parseDNSServers(dns), ["192.168.50.1", "9.9.9.9"])
    }
}
