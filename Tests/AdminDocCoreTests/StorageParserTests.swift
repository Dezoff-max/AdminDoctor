import XCTest
@testable import AdminDocCore

final class StorageParserTests: XCTestCase {
    func testParsesDiskutilInfoPlist() throws {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>VolumeName</key>
            <string>Macintosh HD</string>
            <key>FilesystemName</key>
            <string>APFS</string>
            <key>FilesystemType</key>
            <string>apfs</string>
            <key>TotalSize</key>
            <integer>1000</integer>
            <key>FreeSpace</key>
            <integer>250</integer>
            <key>APFSContainerReference</key>
            <string>disk3</string>
            <key>BusProtocol</key>
            <string>Apple Fabric</string>
            <key>SolidState</key>
            <true/>
            <key>SMARTStatus</key>
            <string>Verified</string>
            <key>SMARTDeviceSpecificKeysMayVaryNotGuaranteed</key>
            <dict>
                <key>AVAILABLE_SPARE</key>
                <integer>100</integer>
                <key>AVAILABLE_SPARE_THRESHOLD</key>
                <integer>99</integer>
                <key>PERCENTAGE_USED</key>
                <integer>3</integer>
                <key>MEDIA_ERRORS_0</key>
                <integer>0</integer>
                <key>MEDIA_ERRORS_1</key>
                <integer>0</integer>
                <key>TEMPERATURE</key>
                <integer>309</integer>
            </dict>
        </dict>
        </plist>
        """

        let info = StorageInfoParser.parseDiskInfo(plistData: Data(plist.utf8))

        XCTAssertEqual(info?.volumeName, "Macintosh HD")
        XCTAssertEqual(info?.filesystemName, "APFS")
        XCTAssertEqual(info?.filesystemType, "apfs")
        XCTAssertEqual(info?.totalSize, 1000)
        XCTAssertEqual(info?.freeSpace, 250)
        XCTAssertEqual(info?.apfsContainerReference, "disk3")
        XCTAssertEqual(info?.busProtocol, "Apple Fabric")
        XCTAssertEqual(info?.solidState, true)
        XCTAssertEqual(info?.smartStatus, "Verified")
        XCTAssertEqual(info?.smartDetails?.availableSparePercent, 100)
        XCTAssertEqual(info?.smartDetails?.percentageUsed, 3)
        XCTAssertEqual(info?.smartDetails?.mediaErrors, 0)
        XCTAssertEqual(info?.smartDetails?.temperatureCelsius, 36)
    }
}
