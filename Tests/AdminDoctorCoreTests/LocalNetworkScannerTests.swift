import XCTest
@testable import AdminDoctorCore

final class LocalNetworkScannerTests: XCTestCase {
    func testParsesLocalIPv4NetworksAndScanRange() {
        let ifconfig = """
        utun8: flags=8051<UP,POINTOPOINT,RUNNING,MULTICAST> mtu 1380
            inet 198.18.0.1 --> 198.18.0.1 netmask 0xffffffff

        en0: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
            inet6 fe80::1234 prefixlen 64 secured scopeid 0xf
            inet 192.168.50.25 netmask 0xffffff00 broadcast 192.168.50.255
            status: active
        """

        let networks = LocalNetworkParser.parseLocalIPv4Networks(ifconfig)
        let network = networks.first { $0.interfaceName == "en0" }
        let range = network.map { LocalNetworkParser.scanRange(for: $0) }

        XCTAssertEqual(network?.address, "192.168.50.25")
        XCTAssertEqual(network?.prefixLength, 24)
        XCTAssertEqual(range?.addresses.count, 253)
        XCTAssertEqual(range?.addresses.first, "192.168.50.1")
        XCTAssertFalse(range?.addresses.contains("192.168.50.25") ?? true)
    }

    func testParsesARPDevices() {
        let arp = """
        ? (192.168.50.1) at aa:bb:cc:dd:ee:ff on en0 ifscope [ethernet]
        printer.local (192.168.50.45) at 11:22:33:44:55:66 on en0 ifscope [ethernet]
        ? (192.168.50.99) at (incomplete) on en0 ifscope [ethernet]
        ? (192.168.50.255) at ff:ff:ff:ff:ff:ff on en0 ifscope [ethernet]
        """

        let devices = LocalNetworkParser.parseARPDevices(arp)

        XCTAssertEqual(devices.count, 2)
        XCTAssertEqual(devices[0].ipAddress, "192.168.50.1")
        XCTAssertNil(devices[0].hostname)
        XCTAssertEqual(devices[1].hostname, "printer.local")
        XCTAssertEqual(devices[1].macAddress, "11:22:33:44:55:66")
    }

    func testParsesVendorNamesFromBundledOUIDatabase() {
        let arp = """
        ? (192.168.1.1) at a8:42:a1:33:a6:fe on en0 ifscope [ethernet]
        ? (192.168.1.101) at 54:ef:44:23:4b:eb on en0 ifscope [ethernet]
        ? (192.168.1.107) at 1c:d:7d:7d:31:44 on en0 ifscope [ethernet]
        ? (192.168.1.109) at 02:1f:94:3e:dd:6c on en0 ifscope [ethernet]
        """

        let devices = LocalNetworkParser.parseARPDevices(arp)

        XCTAssertEqual(devices.map(\.vendorName), [
            "TP-Link Systems Inc",
            "Lumi United Technology Co., Ltd",
            "Apple, Inc.",
            nil
        ])
        XCTAssertTrue(MACAddressClassifier.isLocallyAdministered("02:1f:94:3e:dd:6c"))
    }

    func testParsesQuotedOUIAssignmentRows() {
        let text = """
        Registry,Assignment,Organization Name,Organization Address
        MA-L,54EF44,"Lumi United Technology Co., Ltd","Shenzhen, CN"
        MA-L,A842A1,TP-Link Systems Inc,5 Peters Canyon Rd
        """

        let rows = OUIVendorDatabase.parseAssignmentRows(text)

        XCTAssertEqual(rows.map(\.prefix), ["54EF44", "A842A1"])
        XCTAssertEqual(rows.map(\.vendor), ["Lumi United Technology Co., Ltd", "TP-Link Systems Inc"])
    }

    func testParsesResolvedHostName() {
        let output = """
        name: printer.local.
        ip_address: 192.168.50.45
        """

        XCTAssertEqual(LocalNetworkParser.parseResolvedHostName(output), "printer.local")
        XCTAssertNil(LocalNetworkParser.parseResolvedHostName("ip_address: 192.168.50.45"))
    }

    func testParsesDigShortName() {
        let output = """
        printer.local.
        """

        XCTAssertEqual(LocalNetworkParser.parseDigShortName(output), "printer.local")
    }

    func testInfersDeviceTypeFromGatewayVendorAndPorts() {
        XCTAssertEqual(
            LocalNetworkDeviceClassifier.infer(
                ipAddress: "192.168.50.1",
                gateway: "192.168.50.1",
                hostname: nil,
                vendorName: "TP-Link Systems Inc",
                openPorts: [80]
            ),
            .router
        )
        XCTAssertEqual(
            LocalNetworkDeviceClassifier.infer(
                ipAddress: "192.168.50.45",
                gateway: "192.168.50.1",
                hostname: "printer.local",
                vendorName: nil,
                openPorts: [631, 9100]
            ),
            .printer
        )
        XCTAssertEqual(
            LocalNetworkDeviceClassifier.infer(
                ipAddress: "192.168.50.60",
                gateway: "192.168.50.1",
                hostname: "nas.local",
                vendorName: "Synology Incorporated",
                openPorts: [548]
            ),
            .nas
        )
    }

    func testScannerUsesDefaultInterfaceAndARPTable() throws {
        let runner = LocalNetworkScannerMockRunner(results: [
            "route -n get default": CommandResult(stdout: """
               route to: default
            destination: default
                 gateway: 192.168.50.1
               interface: en0
            """),
            "ifconfig -a": CommandResult(stdout: """
            en0: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
                inet 192.168.50.25 netmask 0xffffff00 broadcast 192.168.50.255
                status: active
            """),
            "arp -an": CommandResult(stdout: """
            ? (192.168.50.1) at aa:bb:cc:dd:ee:ff on en0 ifscope [ethernet]
            ? (192.168.50.25) at aa:aa:aa:aa:aa:aa on en0 ifscope [ethernet]
            old-vpn.local (10.8.0.2) at 11:22:33:44:55:66 on utun3 ifscope [ethernet]
            """)
        ])
        let date = Date(timeIntervalSince1970: 12_345)
        let scanner = LocalNetworkScanner(
            runner: runner,
            now: { date },
            pingSweepEnabled: false,
            nameResolutionEnabled: false,
            portProbeEnabled: false
        )

        let snapshot = try scanner.scan()

        XCTAssertEqual(snapshot.scannedAt, date)
        XCTAssertEqual(snapshot.interfaceName, "en0")
        XCTAssertEqual(snapshot.localAddress, "192.168.50.25")
        XCTAssertEqual(snapshot.gateway, "192.168.50.1")
        XCTAssertEqual(snapshot.devices.map(\.ipAddress), ["192.168.50.1"])
        XCTAssertEqual(runner.commands.map(\.displayName), [
            "route -n get default",
            "ifconfig -a",
            "arp -an"
        ])
    }

    func testScannerInfersGatewayFromFirstHostWhenRouteHasNoGateway() throws {
        let runner = LocalNetworkScannerMockRunner(results: [
            "route -n get default": CommandResult(stdout: "route to: default\ninterface: en0\n"),
            "ifconfig -a": CommandResult(stdout: """
            en0: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
                inet 192.168.50.25 netmask 0xffffff00 broadcast 192.168.50.255
                status: active
            """),
            "arp -an": CommandResult(stdout: """
            ? (192.168.50.1) at aa:bb:cc:dd:ee:ff on en0 ifscope [ethernet]
            ? (192.168.50.45) at 11:22:33:44:55:66 on en0 ifscope [ethernet]
            """)
        ])
        let scanner = LocalNetworkScanner(
            runner: runner,
            pingSweepEnabled: false,
            nameResolutionEnabled: false,
            portProbeEnabled: false
        )

        let snapshot = try scanner.scan()

        XCTAssertEqual(snapshot.gateway, "192.168.50.1")
        XCTAssertEqual(snapshot.devices.map(\.ipAddress), ["192.168.50.1", "192.168.50.45"])
    }
}

private final class LocalNetworkScannerMockRunner: CommandRunning, @unchecked Sendable {
    private let results: [String: CommandResult]
    private(set) var commands: [Command] = []

    init(results: [String: CommandResult]) {
        self.results = results
    }

    func run(_ command: Command) throws -> CommandResult {
        commands.append(command)
        return results[command.displayName] ?? CommandResult(stdout: "", stderr: "not mocked", exitCode: 1)
    }
}
