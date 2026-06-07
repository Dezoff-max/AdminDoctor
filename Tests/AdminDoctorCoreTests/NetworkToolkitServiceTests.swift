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
}
