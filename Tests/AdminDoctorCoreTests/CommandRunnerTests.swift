import XCTest
@testable import AdminDoctorCore

final class CommandRunnerTests: XCTestCase {
    func testRejectsExecutablesOutsideAllowList() {
        let runner = ProcessRunner()
        let rejected = [
            "/bin/sh",
            "/bin/bash",
            "/bin/zsh",
            "/bin/dash",
            "/usr/bin/env",
            "/usr/bin/sudo",
            "/usr/bin/osascript",
            "/usr/bin/python3",
            "/usr/bin/../../bin/sh",
            "/usr/bin/../bin/uname",
            "uname",
            ""
        ]

        for executable in rejected {
            XCTAssertThrowsError(try runner.run(Command(executable)), executable) { error in
                XCTAssertEqual(error as? CommandRunnerError, .unsafeExecutable(executable))
            }
        }
    }

    func testDefaultAllowListHasNoShellsOrPrivilegeTools() {
        let forbiddenNames: Set<String> = ["sh", "bash", "zsh", "dash", "ksh", "csh", "tcsh", "env", "sudo", "su", "osascript", "python3", "perl", "ruby"]

        for executable in ProcessRunner.defaultAllowedExecutables {
            XCTAssertTrue(executable.hasPrefix("/"), executable)
            XCTAssertFalse(executable.contains(".."), executable)
            XCTAssertFalse(forbiddenNames.contains(URL(fileURLWithPath: executable).lastPathComponent), executable)
        }
    }

    func testRunsAllowListedExecutable() throws {
        let result = try ProcessRunner().run(Command("/usr/bin/uname", arguments: ["-s"]))

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines), "Darwin")
    }

    func testCustomAllowListReplacesDefault() {
        let runner = ProcessRunner(allowedExecutables: ["/usr/bin/sw_vers"])

        XCTAssertThrowsError(try runner.run(Command("/usr/bin/uname"))) { error in
            XCTAssertEqual(error as? CommandRunnerError, .unsafeExecutable("/usr/bin/uname"))
        }
    }
}
