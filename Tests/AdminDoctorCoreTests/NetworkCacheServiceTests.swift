import XCTest
@testable import AdminDoctorCore

final class NetworkCacheServiceTests: XCTestCase {
    func testFlushDNSCacheUsesDscacheutilWithoutSudo() {
        let runner = MockCommandRunner(result: CommandResult(stdout: "", exitCode: 0))
        let date = Date(timeIntervalSince1970: 100)
        let service = NetworkCacheService(runner: runner, now: { date })

        let summary = service.flushDNSCache()

        XCTAssertTrue(summary.succeeded)
        XCTAssertEqual(summary.flushedAt, date)
        XCTAssertEqual(summary.source, "dscacheutil -flushcache")
        XCTAssertEqual(runner.commands, [
            Command("/usr/bin/dscacheutil", arguments: ["-flushcache"], timeout: 5)
        ])
    }

    func testFlushDNSCacheReportsCommandFailure() {
        let runner = MockCommandRunner(result: CommandResult(stdout: "", stderr: "permission denied", exitCode: 1))
        let service = NetworkCacheService(runner: runner)

        let summary = service.flushDNSCache()

        XCTAssertFalse(summary.succeeded)
        XCTAssertEqual(summary.message, "permission denied")
    }
}

private final class MockCommandRunner: CommandRunning, @unchecked Sendable {
    private let result: CommandResult
    private(set) var commands: [Command] = []

    init(result: CommandResult) {
        self.result = result
    }

    func run(_ command: Command) throws -> CommandResult {
        commands.append(command)
        return result
    }
}
