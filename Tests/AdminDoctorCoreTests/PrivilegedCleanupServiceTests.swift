import XCTest
@testable import AdminDoctorCore

final class PrivilegedCleanupServiceTests: XCTestCase {
    func testPlanRejectsOutsidePathsAndAllowsCurrentSystemCandidates() throws {
        let root = temporaryRoot()
        let cache = root.appendingPathComponent("Library/Caches", isDirectory: true)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        let candidate = cache.appendingPathComponent("com.example.cache")
        try Data("cache".utf8).write(to: candidate)

        let audit = root.appendingPathComponent("audit.jsonl")
        let service = PrivilegedCleanupService(
            scopes: [testScope(cache)],
            quarantineBase: root.appendingPathComponent("quarantine", isDirectory: true),
            auditLogURL: audit,
            now: { Date(timeIntervalSince1970: 100) }
        )

        let plan = service.plan(paths: [candidate.path, "/private/not-allowed"])

        XCTAssertEqual(plan.eligibleCandidates.map(\.path), [candidate.path])
        XCTAssertEqual(plan.rejected.map(\.path), ["/private/not-allowed"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: audit.path))
    }

    func testQuarantineMovesAllowedCandidateAndAudits() throws {
        let root = temporaryRoot()
        let cache = root.appendingPathComponent("Library/Caches", isDirectory: true)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        let candidate = cache.appendingPathComponent("com.example.cache")
        try Data("cache".utf8).write(to: candidate)

        let audit = root.appendingPathComponent("audit.jsonl")
        let service = PrivilegedCleanupService(
            scopes: [testScope(cache)],
            quarantineBase: root.appendingPathComponent("quarantine", isDirectory: true),
            auditLogURL: audit,
            now: { Date(timeIntervalSince1970: 100) }
        )

        let result = service.quarantine(paths: [candidate.path])

        XCTAssertEqual(result.moved.map(\.path), [candidate.path])
        XCTAssertTrue(result.failures.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: candidate.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.quarantineRoot))
        XCTAssertTrue((try String(contentsOf: audit)).contains("\"result\":\"moved\""))
    }

    func testQuarantineCreatesOwnerOnlyDirectories() throws {
        let root = temporaryRoot()
        let cache = root.appendingPathComponent("Library/Caches", isDirectory: true)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        let candidate = cache.appendingPathComponent("com.example.cache")
        try Data("cache".utf8).write(to: candidate)

        let quarantineBase = root.appendingPathComponent("quarantine", isDirectory: true)
        let service = PrivilegedCleanupService(
            scopes: [testScope(cache)],
            quarantineBase: quarantineBase,
            auditLogURL: root.appendingPathComponent("audit.jsonl"),
            now: { Date(timeIntervalSince1970: 100) }
        )

        let result = service.quarantine(paths: [candidate.path])

        XCTAssertTrue(result.failures.isEmpty)
        for path in [quarantineBase.path, result.quarantineRoot] {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o700)
        }
    }

    func testQuarantineRefusesSymbolicLinkQuarantineBase() throws {
        let root = temporaryRoot()
        let cache = root.appendingPathComponent("Library/Caches", isDirectory: true)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        let candidate = cache.appendingPathComponent("com.example.cache")
        try Data("cache".utf8).write(to: candidate)

        let redirected = root.appendingPathComponent("elsewhere", isDirectory: true)
        try FileManager.default.createDirectory(at: redirected, withIntermediateDirectories: true)
        let quarantineBase = root.appendingPathComponent("quarantine", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: quarantineBase, withDestinationURL: redirected)

        let service = PrivilegedCleanupService(
            scopes: [testScope(cache)],
            quarantineBase: quarantineBase,
            auditLogURL: root.appendingPathComponent("audit.jsonl"),
            now: { Date(timeIntervalSince1970: 100) }
        )

        let result = service.quarantine(paths: [candidate.path])

        XCTAssertTrue(result.moved.isEmpty)
        XCTAssertFalse(result.failures.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: candidate.path))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: redirected.path), [])
    }

    func testQuarantineRefusesWorldWritableQuarantineBase() throws {
        let root = temporaryRoot()
        let cache = root.appendingPathComponent("Library/Caches", isDirectory: true)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        let candidate = cache.appendingPathComponent("com.example.cache")
        try Data("cache".utf8).write(to: candidate)

        let container = root.appendingPathComponent("shared", isDirectory: true)
        try FileManager.default.createDirectory(
            at: container,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o777]
        )
        // createDirectory applies the umask, so set the mode explicitly.
        try FileManager.default.setAttributes([.posixPermissions: 0o777], ofItemAtPath: container.path)

        let service = PrivilegedCleanupService(
            scopes: [testScope(cache)],
            quarantineBase: container.appendingPathComponent("quarantine", isDirectory: true),
            auditLogURL: root.appendingPathComponent("audit.jsonl"),
            now: { Date(timeIntervalSince1970: 100) }
        )

        let result = service.quarantine(paths: [candidate.path])

        XCTAssertTrue(result.moved.isEmpty)
        XCTAssertFalse(result.failures.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: candidate.path))
    }

    func testClientRequirementPinsBundleIdentifierAndTeam() {
        let requirement = PrivilegedHelperXPCContract.clientCodeSigningRequirement(teamIdentifier: "ABCDE12345")

        XCTAssertEqual(
            requirement,
            "anchor apple generic and identifier \"dev.admindoctor.AdminDoctor\" and certificate leaf[subject.OU] = \"ABCDE12345\""
        )
    }

    func testClientRequirementIsUnavailableWithoutValidTeam() {
        XCTAssertNil(PrivilegedHelperXPCContract.clientCodeSigningRequirement(teamIdentifier: nil))
        XCTAssertNil(PrivilegedHelperXPCContract.clientCodeSigningRequirement(teamIdentifier: ""))
        XCTAssertNil(PrivilegedHelperXPCContract.clientCodeSigningRequirement(teamIdentifier: "TEAM\" or anchor apple"))
    }

    private func testScope(_ root: URL) -> CleanupScope {
        CleanupScope(
            root: root,
            kind: .systemCache,
            risk: .requiresHelper,
            minimumAge: 0,
            defaultSelected: false,
            reason: "System cache item",
            requiresPrivilegedHelper: true
        )
    }

    private func temporaryRoot() -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AdminDoctorPrivilegedCleanupTests-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return root
    }
}
