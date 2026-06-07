import XCTest
@testable import AdminDocCore

final class DiskCleanupServiceTests: XCTestCase {
    func testScanFindsOnlyOlderAllowedItems() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let oldFile = root.appendingPathComponent("old-cache.bin")
        let freshFile = root.appendingPathComponent("fresh-cache.bin")
        let disallowedFile = root.appendingPathComponent("installer.pkg")

        try Data(repeating: 1, count: 512).write(to: oldFile)
        try Data(repeating: 2, count: 512).write(to: freshFile)
        try Data(repeating: 3, count: 512).write(to: disallowedFile)

        let now = Date(timeIntervalSince1970: 10_000)
        try setModificationDate(now.addingTimeInterval(-2.days), for: oldFile)
        try setModificationDate(now.addingTimeInterval(-30), for: freshFile)
        try setModificationDate(now.addingTimeInterval(-2.days), for: disallowedFile)

        let service = DiskCleanupService(
            scopes: [
                CleanupScope(
                    root: root,
                    kind: .temporaryFile,
                    minimumAge: 1.days,
                    defaultSelected: true,
                    reason: "test",
                    allowedExtensions: ["bin"]
                )
            ],
            now: { now }
        )

        let snapshot = try service.scan()

        XCTAssertEqual(snapshot.candidates.map(\.displayName), ["old-cache.bin"])
        XCTAssertEqual(snapshot.candidates.first?.defaultSelected, true)
    }

    func testScanIncludesFreshItemsButOnlyRecommendsOldItems() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let oldDirectory = root.appendingPathComponent("old-cache", isDirectory: true)
        let freshDirectory = root.appendingPathComponent("fresh-cache", isDirectory: true)
        try FileManager.default.createDirectory(at: oldDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: freshDirectory, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 512).write(to: oldDirectory.appendingPathComponent("payload.bin"))
        try Data(repeating: 2, count: 512).write(to: freshDirectory.appendingPathComponent("payload.bin"))

        let now = Date(timeIntervalSince1970: 50_000)
        try setModificationDate(now.addingTimeInterval(-8.days), for: oldDirectory)
        try setModificationDate(now.addingTimeInterval(-2.hours), for: freshDirectory)

        let service = DiskCleanupService(
            scopes: [
                CleanupScope(
                    root: root,
                    kind: .userCache,
                    minimumAge: 0,
                    defaultSelected: true,
                    reason: "test",
                    defaultSelectionMinimumAge: 7.days
                )
            ],
            now: { now }
        )

        let snapshot = try service.scan()

        XCTAssertEqual(Set(snapshot.candidates.map(\.displayName)), ["old-cache", "fresh-cache"])
        XCTAssertEqual(snapshot.candidates.first { $0.displayName == "old-cache" }?.defaultSelected, true)
        XCTAssertEqual(snapshot.candidates.first { $0.displayName == "fresh-cache" }?.defaultSelected, false)
    }

    func testScanAssignsCleanupRiskAndGroupMetadata() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let npmCache = root.appendingPathComponent(".npm/_cacache", isDirectory: true)
        try FileManager.default.createDirectory(at: npmCache, withIntermediateDirectories: true)
        let payload = npmCache.appendingPathComponent("index.bin")
        try Data(repeating: 4, count: 512).write(to: payload)

        let service = DiskCleanupService(
            scopes: [
                CleanupScope(
                    root: npmCache,
                    kind: .packageManagerCache,
                    risk: .manualReview,
                    minimumAge: 0,
                    defaultSelected: false,
                    reason: "Package manager cache item"
                )
            ]
        )

        let snapshot = try service.scan()
        let candidate = try XCTUnwrap(snapshot.candidates.first)

        XCTAssertEqual(candidate.displayName, "index.bin")
        XCTAssertEqual(candidate.risk, .manualReview)
        XCTAssertEqual(candidate.groupIdentifier, "npm")
        XCTAssertEqual(candidate.groupTitle, "npm cache")
        XCTAssertFalse(candidate.requiresPrivilegedHelper)
    }

    func testMoveToTrashRejectsPathsOutsideCleanupScopes() throws {
        let root = try makeTemporaryDirectory()
        let outside = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: outside)
        }

        let outsideFile = outside.appendingPathComponent("outside.tmp")
        try Data("outside".utf8).write(to: outsideFile)

        let service = DiskCleanupService(
            scopes: [
                CleanupScope(
                    root: root,
                    kind: .temporaryFile,
                    minimumAge: 0,
                    defaultSelected: true,
                    reason: "test"
                )
            ]
        )

        let summary = service.moveToTrash([
            CleanupCandidate(
                kind: .temporaryFile,
                path: outsideFile.path,
                displayName: outsideFile.lastPathComponent,
                byteCount: 7,
                modifiedAt: nil,
                defaultSelected: true,
                reason: "test"
            )
        ])

        XCTAssertTrue(FileManager.default.fileExists(atPath: outsideFile.path))
        XCTAssertTrue(summary.trashed.isEmpty)
        XCTAssertEqual(summary.failures.count, 1)
    }

    func testMoveToTrashRejectsPrivilegedHelperCandidates() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let systemCandidate = root.appendingPathComponent("system-cache")
        try Data("system".utf8).write(to: systemCandidate)

        let service = DiskCleanupService(
            scopes: [
                CleanupScope(
                    root: root,
                    kind: .systemCache,
                    risk: .requiresHelper,
                    minimumAge: 0,
                    defaultSelected: false,
                    reason: "System cache item",
                    requiresPrivilegedHelper: true
                )
            ]
        )

        let summary = service.moveToTrash([
            CleanupCandidate(
                kind: .systemCache,
                risk: .requiresHelper,
                path: systemCandidate.path,
                displayName: systemCandidate.lastPathComponent,
                byteCount: 6,
                modifiedAt: nil,
                defaultSelected: false,
                requiresPrivilegedHelper: true,
                reason: "System cache item"
            )
        ])

        XCTAssertTrue(FileManager.default.fileExists(atPath: systemCandidate.path))
        XCTAssertTrue(summary.trashed.isEmpty)
        XCTAssertEqual(summary.failures.count, 1)
        XCTAssertTrue(summary.failures[0].message.contains("Privileged helper"))
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("AdminDocCleanupTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func setModificationDate(_ date: Date, for url: URL) throws {
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
    }
}

private extension Int {
    var days: TimeInterval { TimeInterval(self) * 86_400 }
    var hours: TimeInterval { TimeInterval(self) * 3_600 }
}
