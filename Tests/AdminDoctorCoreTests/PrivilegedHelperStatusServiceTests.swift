import XCTest
@testable import AdminDoctorCore

final class PrivilegedHelperStatusServiceTests: XCTestCase {
    func testReportsBundledOnlyWhenBundledToolExistsButSystemInstallIsMissing() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let helperURL = tempRoot.appendingPathComponent("AdminDoctorPrivilegedHelper")
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: helperURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: helperURL.path)

        let service = PrivilegedHelperStatusService(
            runner: NoopHelperStatusRunner(),
            installedToolPath: tempRoot.appendingPathComponent("missing-installed").path,
            launchDaemonPath: tempRoot.appendingPathComponent("missing.plist").path,
            now: { Date(timeIntervalSince1970: 42) }
        )
        let status = service.status(bundledToolPath: helperURL.path)

        XCTAssertEqual(status.state, .bundledOnly)
        XCTAssertTrue(status.bundledToolPresent)
        XCTAssertFalse(status.installedToolPresent)
        XCTAssertFalse(status.launchDaemonPresent)
        XCTAssertNil(status.codeSignatureVerified)
        XCTAssertEqual(status.checkedAt, Date(timeIntervalSince1970: 42))
    }
}

private final class NoopHelperStatusRunner: CommandRunning, @unchecked Sendable {
    func run(_ command: Command) throws -> CommandResult {
        CommandResult(stdout: "", exitCode: 0)
    }
}
