import XCTest
@testable import AdminDoctorCore

final class RedactorTests: XCTestCase {
    func testRedactsKnownPersonalValuesAndLocalAddresses() {
        let redactor = Redactor()
        let context = RedactionContext(
            usernames: ["alice"],
            hostnames: ["alice-mac.local"],
            serialNumbers: ["C02TESTSERIAL"],
            wifiSSIDs: ["Office WiFi"]
        )

        let input = "alice on alice-mac.local serial C02TESTSERIAL ip 192.168.1.20 public 8.8.8.8 ssid Office WiFi mac aa:bb:cc:dd:ee:ff"
        let output = redactor.redact(input, context: context)

        XCTAssertFalse(output.contains("alice"))
        XCTAssertFalse(output.contains("alice-mac.local"))
        XCTAssertFalse(output.contains("C02TESTSERIAL"))
        XCTAssertFalse(output.contains("192.168.1.20"))
        XCTAssertFalse(output.contains("Office WiFi"))
        XCTAssertFalse(output.contains("aa:bb:cc:dd:ee:ff"))
        XCTAssertTrue(output.contains("8.8.8.8"))
        XCTAssertTrue(output.contains("[redacted-username]"))
        XCTAssertTrue(output.contains("[redacted-local-ip]"))
    }

    func testRedactsReportDetailsBeforeJsonExport() throws {
        let result = DiagnosticResult(
            category: .network,
            severity: .pass,
            title: "Default gateway",
            summary: "Default gateway is 10.0.0.1.",
            details: [DiagnosticDetail(key: "Wi-Fi SSID", value: "Office WiFi", privacy: .sensitive)],
            source: "fixture"
        )

        let exporter = ReportExporter()
        let data = try exporter.jsonData(
            generatedAt: Date(timeIntervalSince1970: 0),
            results: [result],
            context: RedactionContext(wifiSSIDs: ["Office WiFi"])
        )
        let json = String(decoding: data, as: UTF8.self)

        XCTAssertFalse(json.contains("10.0.0.1"))
        XCTAssertFalse(json.contains("Office WiFi"))
        XCTAssertTrue(json.contains("[redacted-local-ip]"))
        XCTAssertTrue(json.contains("[redacted-ssid]"))
    }
}
