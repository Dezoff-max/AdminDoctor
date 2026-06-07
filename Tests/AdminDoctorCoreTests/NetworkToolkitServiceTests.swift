import XCTest
@testable import AdminDoctorCore

final class NetworkToolkitServiceTests: XCTestCase {
    func testParsesPingSummaryWithAverageAndLoss() {
        let output = """
        4 packets transmitted, 4 packets received, 0.0% packet loss
        round-trip min/avg/max/stddev = 10.001/12.500/17.000/2.100 ms
        """

        XCTAssertEqual(
            NetworkToolkitParser.pingSummary(output: output, succeeded: true),
            "Average 12.500 ms, 0.0% packet loss."
        )
    }

    func testParsesTracerouteHopCount() {
        let output = """
        traceroute to 1.1.1.1 (1.1.1.1), 8 hops max
        1  192.168.1.1  1.234 ms
        2  10.0.0.1  5.678 ms
        """

        XCTAssertEqual(
            NetworkToolkitParser.tracerouteSummary(output: output, succeeded: true),
            "2 hop(s) returned."
        )
    }

    func testParsesDNSLookupSummary() {
        let output = """
        name: example.com
        ip_address: 93.184.216.34
        ip_address: 2606:2800:220:1:248:1893:25c8:1946
        """

        XCTAssertEqual(
            NetworkToolkitParser.dnsLookupSummary(output: output, succeeded: true),
            "Resolved 2 address record(s)."
        )
    }

    func testParsesExternalIPAddress() {
        let output = """
        203.0.113.42
        """

        XCTAssertEqual(NetworkToolkitParser.parseExternalIPAddress(output), "203.0.113.42")
        XCTAssertEqual(
            NetworkToolkitParser.externalIPSummary(output: output, succeeded: true),
            "External IP appears to be 203.0.113.42."
        )
    }

    func testParsesRouteTableSummary() {
        let output = """
        Routing tables

        Internet:
        Destination        Gateway            Flags           Netif Expire
        default            192.168.50.1       UGScg             en0
        192.168.50/24      link#15            UCS               en0
        """

        XCTAssertEqual(
            NetworkToolkitParser.routeTableSummary(output: output, succeeded: true),
            "Default route via 192.168.50.1; 1 default route row(s)."
        )
    }

    func testParsesCaptivePortalSuccess() {
        XCTAssertEqual(
            NetworkToolkitParser.captivePortalSummary(output: "<HTML><BODY>Success</BODY></HTML>", succeeded: true),
            "Apple captive portal probe returned the expected success page."
        )
    }

    func testParsesProxyEndpoints() {
        let output = """
        <dictionary> {
          HTTPEnable : 1
          HTTPPort : 8080
          HTTPProxy : proxy.example.com
          HTTPSEnable : 1
          HTTPSPort : 8443
          HTTPSProxy : secure-proxy.example.com
        }
        """

        XCTAssertEqual(
            NetworkToolkitParser.parseProxyEndpoints(output),
            [
                ProxyEndpoint(kind: "HTTP", host: "proxy.example.com", port: 8080),
                ProxyEndpoint(kind: "HTTPS", host: "secure-proxy.example.com", port: 8443)
            ]
        )
        XCTAssertEqual(
            NetworkToolkitParser.proxyReachabilitySummary(scutilOutput: output, reachabilityLines: [
                "HTTP proxy.example.com:8080 reachable",
                "HTTPS secure-proxy.example.com:8443 unreachable"
            ]),
            "1 of 2 configured proxy endpoint(s) reachable."
        )
    }
}
