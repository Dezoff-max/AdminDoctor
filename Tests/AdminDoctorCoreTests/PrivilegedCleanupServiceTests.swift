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
