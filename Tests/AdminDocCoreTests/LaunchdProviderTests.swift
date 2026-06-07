import XCTest
@testable import AdminDocCore

final class LaunchdProviderTests: XCTestCase {
    func testCollectListsLaunchdStartupItems() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let agents = root.appendingPathComponent("Library/LaunchAgents", isDirectory: true)
        let daemons = root.appendingPathComponent("Library/LaunchDaemons", isDirectory: true)
        try FileManager.default.createDirectory(at: agents, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: daemons, withIntermediateDirectories: true)

        try writePlist(
            [
                "Label": "com.example.sync",
                "ProgramArguments": [
                    "/Applications/SyncTool.app/Contents/MacOS/SyncTool",
                    "--background"
                ],
                "RunAtLoad": true
            ],
            to: agents.appendingPathComponent("com.example.sync.plist")
        )
        try writePlist(
            [
                "Label": "com.example.daemon",
                "Program": "/usr/local/bin/exampled",
                "KeepAlive": true
            ],
            to: daemons.appendingPathComponent("com.example.daemon.plist")
        )

        let result = try XCTUnwrap(LaunchdProvider(inspectedDirectories: [agents, daemons]).collect().first)
        let details = Dictionary(uniqueKeysWithValues: result.details.map { ($0.key, $0.value) })

        XCTAssertEqual(details["Checked"], "2")
        XCTAssertEqual(details["Startup items"], "2")
        XCTAssertTrue(details["SyncTool"]?.contains("RunAtLoad") == true)
        XCTAssertTrue(details["SyncTool"]?.contains("/Applications/SyncTool.app/Contents/MacOS/SyncTool --background") == true)
        XCTAssertTrue(details["com.example.daemon"]?.contains("KeepAlive") == true)
    }

    func testCollectReportsInvalidLaunchdPlists() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let agents = root.appendingPathComponent("LaunchAgents", isDirectory: true)
        try FileManager.default.createDirectory(at: agents, withIntermediateDirectories: true)
        try Data("not a plist".utf8).write(to: agents.appendingPathComponent("broken.plist"))

        let result = try XCTUnwrap(LaunchdProvider(inspectedDirectories: [agents]).collect().first)

        XCTAssertEqual(result.severity, .fail)
        XCTAssertTrue(result.summary.contains("invalid plist"))
        XCTAssertTrue(result.details.first { $0.key == "Invalid paths" }?.value.contains("broken.plist") == true)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("AdminDocLaunchdTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writePlist(_ dictionary: [String: Any], to url: URL) throws {
        let data = try PropertyListSerialization.data(fromPropertyList: dictionary, format: .xml, options: 0)
        try data.write(to: url)
    }
}
