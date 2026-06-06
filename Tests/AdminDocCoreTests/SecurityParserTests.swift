import XCTest
@testable import AdminDocCore

final class SecurityParserTests: XCTestCase {
    func testSecurityStatusParsingAndSeverityMapping() {
        XCTAssertEqual(SecurityStatusParser.parseFileVaultStatus("FileVault is On."), .enabled)
        XCTAssertEqual(SecurityStatusParser.parseFileVaultStatus("FileVault is Off."), .disabled)
        XCTAssertEqual(SecurityStatusParser.parseSIPStatus("System Integrity Protection status: disabled."), .disabled)
        XCTAssertEqual(SecurityStatusParser.parseGatekeeperStatus("assessments enabled"), .enabled)

        XCTAssertEqual(SeverityMapping.requiredControl(.enabled), .pass)
        XCTAssertEqual(SeverityMapping.requiredControl(.disabled), .fail)
        XCTAssertEqual(SeverityMapping.recommendedControl(.disabled), .warning)
        XCTAssertEqual(SeverityMapping.requiredSignal(isPresent: false), .warning)
    }
}
