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
    }
}
