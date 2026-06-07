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

    func testParsesBundleShortVersion() {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleShortVersionString</key>
            <string>5347</string>
        </dict>
        </plist>
        """

        XCTAssertEqual(SecurityStatusParser.parseBundleShortVersion(plistData: Data(plist.utf8)), "5347")
    }

    func testParsesInstallHistoryAndFiltersSecurityRelevantItems() {
        let json = """
        {
          "SPInstallHistoryDataType": [
            {
              "_name": "Microsoft Word",
              "install_date": "2026-06-03T14:09:16Z",
              "package_source": "package_source_other"
            },
            {
              "_name": "XProtectPlistConfigData",
              "install_date": "2026-06-04T16:27:59Z",
              "install_version": "5347",
              "package_source": "package_source_apple"
            },
            {
              "_name": "macOS 26.5.1",
              "install_date": "2026-06-04T16:40:25Z",
              "install_version": "26.5.1",
              "package_source": "package_source_apple"
            }
          ]
        }
        """

        let items = SecurityStatusParser.parseInstallHistory(jsonData: Data(json.utf8))
        let relevant = SecurityStatusParser.latestRelevantInstallItems(items)

        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(relevant.map(\.name), ["macOS 26.5.1", "XProtectPlistConfigData"])
        XCTAssertEqual(relevant.first?.version, "26.5.1")
    }

    func testParsesSoftwareUpdateSettings() {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>AutomaticDownload</key>
            <integer>1</integer>
            <key>CriticalUpdateInstall</key>
            <true/>
            <key>ConfigDataInstall</key>
            <true/>
            <key>AutomaticallyInstallMacOSUpdates</key>
            <integer>0</integer>
        </dict>
        </plist>
        """

        let settings = SecurityStatusParser.parseSoftwareUpdateSettings(plistData: Data(plist.utf8))

        XCTAssertEqual(settings?.automaticDownload, true)
        XCTAssertEqual(settings?.criticalUpdateInstall, true)
        XCTAssertEqual(settings?.configDataInstall, true)
        XCTAssertEqual(settings?.automaticallyInstallMacOSUpdates, false)
    }
}
