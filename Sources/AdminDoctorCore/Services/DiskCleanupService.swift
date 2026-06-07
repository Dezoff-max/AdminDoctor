import Darwin
import Foundation

public struct CleanupScope: Equatable, Sendable {
    public var root: URL
    public var kind: CleanupCandidateKind
    public var risk: CleanupRisk
    public var minimumAge: TimeInterval
    public var defaultSelected: Bool
    public var defaultSelectionMinimumAge: TimeInterval?
    public var requiresPrivilegedHelper: Bool
    public var reason: String
    public var allowedExtensions: Set<String>?
    public var includeDirectories: Bool
    public var includeRegularFiles: Bool

    public init(
        root: URL,
        kind: CleanupCandidateKind,
        risk: CleanupRisk = .manualReview,
        minimumAge: TimeInterval,
        defaultSelected: Bool,
        reason: String,
        allowedExtensions: Set<String>? = nil,
        defaultSelectionMinimumAge: TimeInterval? = nil,
        requiresPrivilegedHelper: Bool = false,
        includeDirectories: Bool = true,
        includeRegularFiles: Bool = true
    ) {
        self.root = root
        self.kind = kind
        self.risk = risk
        self.minimumAge = minimumAge
        self.defaultSelected = defaultSelected
        self.defaultSelectionMinimumAge = defaultSelectionMinimumAge
        self.requiresPrivilegedHelper = requiresPrivilegedHelper
        self.reason = reason
        self.allowedExtensions = allowedExtensions.map { Set($0.map { $0.lowercased() }) }
        self.includeDirectories = includeDirectories
        self.includeRegularFiles = includeRegularFiles
    }
}

public struct CleanupPolicy: Equatable, Sendable {
    public var maxCandidateCount: Int
    public var maxSizeTraversalEntries: Int

    public init(maxCandidateCount: Int = 2_000, maxSizeTraversalEntries: Int = 20_000) {
        self.maxCandidateCount = maxCandidateCount
        self.maxSizeTraversalEntries = maxSizeTraversalEntries
    }
}

public final class DiskCleanupService: @unchecked Sendable {
    private let fileManager: FileManager
    private let scopes: [CleanupScope]
    private let policy: CleanupPolicy
    private let now: @Sendable () -> Date

    public init(
        fileManager: FileManager = .default,
        scopes: [CleanupScope]? = nil,
        policy: CleanupPolicy = CleanupPolicy(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.fileManager = fileManager
        self.scopes = scopes ?? DiskCleanupService.defaultScopes(fileManager: fileManager)
        self.policy = policy
        self.now = now
    }

    public static func defaultScopes(fileManager: FileManager = .default) -> [CleanupScope] {
        let home = fileManager.homeDirectoryForCurrentUser
        let downloadsExtensions: Set<String> = ["7z", "dmg", "gz", "ipsw", "iso", "pkg", "rar", "tar", "tgz", "xip", "zip"]

        var scopes = [
            CleanupScope(
                root: home.appendingPathComponent("Library/Caches", isDirectory: true),
                kind: .userCache,
                risk: .safe,
                minimumAge: 0,
                defaultSelected: true,
                reason: "User cache item",
                defaultSelectionMinimumAge: 7.days
            ),
            CleanupScope(
                root: URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true),
                kind: .temporaryFile,
                risk: .safe,
                minimumAge: 0,
                defaultSelected: true,
                reason: "Temporary item",
                defaultSelectionMinimumAge: 1.days
            ),
            CleanupScope(
                root: home.appendingPathComponent("Library/Logs", isDirectory: true),
                kind: .userLog,
                risk: .caution,
                minimumAge: 0,
                defaultSelected: false,
                reason: "User log item"
            ),
            CleanupScope(
                root: home.appendingPathComponent("Downloads", isDirectory: true),
                kind: .downloadedInstaller,
                risk: .manualReview,
                minimumAge: 0,
                defaultSelected: false,
                reason: "Downloaded installer or archive",
                allowedExtensions: downloadsExtensions,
                includeDirectories: false
            )
        ]

        scopes.append(contentsOf: systemCleanupScopes())

        scopes.append(contentsOf: [
            developerScope(home, "Library/Developer/Xcode/DerivedData", defaultSelectionMinimumAge: 7.days),
            developerScope(home, "Library/Developer/Xcode/iOS DeviceSupport", defaultSelectionMinimumAge: 90.days),
            developerScope(home, "Library/Developer/Xcode/watchOS DeviceSupport", defaultSelectionMinimumAge: 90.days),
            developerScope(home, "Library/Developer/Xcode/tvOS DeviceSupport", defaultSelectionMinimumAge: 90.days),
            developerScope(home, "Library/Developer/CoreSimulator/Caches", defaultSelectionMinimumAge: 7.days),
            packageScope(home, ".swiftpm/cache"),
            packageScope(home, ".swiftpm/repositories"),
            packageScope(home, ".npm/_cacache"),
            packageScope(home, ".cargo/registry/cache"),
            packageScope(home, ".cargo/git/checkouts"),
            packageScope(home, ".gradle/caches"),
            packageScope(home, "Library/Caches/pip"),
            packageScope(home, "Library/Caches/Homebrew"),
            packageScope(home, "Library/Caches/Yarn"),
            packageScope(home, "Library/Caches/go-build"),
            packageScope(home, "Library/pnpm/store")
        ])

        return scopes
    }

    public static func systemCleanupScopes() -> [CleanupScope] {
        [
            CleanupScope(
                root: URL(fileURLWithPath: "/Library/Caches", isDirectory: true),
                kind: .systemCache,
                risk: .requiresHelper,
                minimumAge: 0,
                defaultSelected: false,
                reason: "System cache item",
                requiresPrivilegedHelper: true
            ),
            CleanupScope(
                root: URL(fileURLWithPath: "/Library/Logs", isDirectory: true),
                kind: .systemLog,
                risk: .requiresHelper,
                minimumAge: 0,
                defaultSelected: false,
                reason: "System log item",
                requiresPrivilegedHelper: true
            )
        ]
    }

    public func scan() throws -> CleanupSnapshot {
        var candidates: [CleanupCandidate] = []
        var skippedPaths: [String] = []
        let scanDate = now()

        for scope in scopes {
            let root = scope.root.standardizedFileURL
            guard directoryExists(at: root) else {
                continue
            }

            do {
                let urls = try immediateChildren(of: root)

                for url in urls where candidates.count < policy.maxCandidateCount {
                    guard let candidate = candidate(for: url, in: scope, scanDate: scanDate) else {
                        continue
                    }
                    candidates.append(candidate)
                }
            } catch {
                skippedPaths.append(root.path)
            }
        }

        return CleanupSnapshot(
            scannedAt: scanDate,
            candidates: candidates.sorted {
                if $0.defaultSelected != $1.defaultSelected {
                    return $0.defaultSelected && !$1.defaultSelected
                }
                if $0.byteCount != $1.byteCount {
                    return $0.byteCount > $1.byteCount
                }
                return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            },
            skippedPaths: skippedPaths
        )
    }

    private func immediateChildren(of root: URL) throws -> [URL] {
        guard let directory = opendir(root.path) else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        defer { closedir(directory) }

        var urls: [URL] = []
        while let entry = readdir(directory) {
            let name = withUnsafePointer(to: &entry.pointee.d_name) { pointer in
                pointer.withMemoryRebound(to: CChar.self, capacity: Int(entry.pointee.d_namlen)) {
                    String(cString: $0)
                }
            }

            guard name != ".", name != "..", !name.hasPrefix(".") else {
                continue
            }

            urls.append(root.appendingPathComponent(name))
        }

        return urls
    }

    public func moveToTrash(_ candidates: [CleanupCandidate]) -> CleanupExecutionSummary {
        var trashed: [CleanupCandidate] = []
        var failures: [CleanupFailure] = []

        for candidate in candidates {
            let url = URL(fileURLWithPath: candidate.path).standardizedFileURL
            guard !candidate.requiresPrivilegedHelper else {
                failures.append(CleanupFailure(path: candidate.path, message: "Privileged helper is required for this system cleanup candidate."))
                continue
            }

            guard isAllowedCleanupPath(url) else {
                failures.append(CleanupFailure(path: candidate.path, message: "Path is outside configured cleanup scopes."))
                continue
            }

            guard fileManager.fileExists(atPath: url.path) else {
                failures.append(CleanupFailure(path: candidate.path, message: "Item no longer exists."))
                continue
            }

            do {
                var resultingURL: NSURL?
                try fileManager.trashItem(at: url, resultingItemURL: &resultingURL)
                trashed.append(candidate)
            } catch {
                failures.append(CleanupFailure(path: candidate.path, message: error.localizedDescription))
            }
        }

        return CleanupExecutionSummary(trashed: trashed, failures: failures)
    }

    private func candidate(for url: URL, in scope: CleanupScope, scanDate: Date) -> CleanupCandidate? {
        let standardized = url.standardizedFileURL
        guard isInside(standardized, root: scope.root.standardizedFileURL) else {
            return nil
        }

        guard let values = try? standardized.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey]) else {
            return nil
        }

        guard values.isSymbolicLink != true else {
            return nil
        }

        if values.isDirectory == true, !scope.includeDirectories {
            return nil
        }

        if values.isRegularFile == true, !scope.includeRegularFiles {
            return nil
        }

        if let allowedExtensions = scope.allowedExtensions {
            guard allowedExtensions.contains(standardized.pathExtension.lowercased()) else {
                return nil
            }
        }

        let modifiedAt = resourceDate(standardized, key: .contentModificationDateKey)
        if let modifiedAt, scanDate.timeIntervalSince(modifiedAt) < scope.minimumAge {
            return nil
        }

        let byteCount = allocatedSize(of: standardized)
        guard byteCount > 0 else {
            return nil
        }

        let defaultSelected = isDefaultSelected(
            by: scope,
            modifiedAt: modifiedAt,
            scanDate: scanDate
        )

        return CleanupCandidate(
            kind: scope.kind,
            risk: scope.risk,
            path: standardized.path,
            displayName: standardized.lastPathComponent,
            byteCount: byteCount,
            modifiedAt: modifiedAt,
            defaultSelected: defaultSelected,
            requiresPrivilegedHelper: scope.requiresPrivilegedHelper,
            groupIdentifier: groupIdentifier(for: standardized, in: scope),
            groupTitle: groupTitle(for: standardized, in: scope),
            reason: scope.reason
        )
    }

    private func groupIdentifier(for url: URL, in scope: CleanupScope) -> String {
        let path = url.path
        if path.contains("/.npm/") {
            return "npm"
        }
        if path.contains("/Homebrew/") {
            return "homebrew"
        }
        if path.contains("/Xcode/") || path.contains("/CoreSimulator/") {
            return "xcode"
        }
        if path.contains("/.gradle/") {
            return "gradle"
        }
        if path.contains("/.cargo/") {
            return "cargo"
        }
        if path.contains("/.swiftpm/") {
            return "swiftpm"
        }
        if path.contains("/pip") {
            return "pip"
        }
        return scope.kind.rawValue
    }

    private func groupTitle(for url: URL, in scope: CleanupScope) -> String {
        switch groupIdentifier(for: url, in: scope) {
        case "npm":
            return "npm cache"
        case "homebrew":
            return "Homebrew cache"
        case "xcode":
            return "Xcode and simulator cache"
        case "gradle":
            return "Gradle cache"
        case "cargo":
            return "Cargo cache"
        case "swiftpm":
            return "SwiftPM cache"
        case "pip":
            return "pip cache"
        default:
            return scope.kind.title
        }
    }

    private func isDefaultSelected(by scope: CleanupScope, modifiedAt: Date?, scanDate: Date) -> Bool {
        guard scope.defaultSelected else {
            return false
        }

        guard let defaultSelectionMinimumAge = scope.defaultSelectionMinimumAge else {
            return true
        }

        guard let modifiedAt else {
            return false
        }

        return scanDate.timeIntervalSince(modifiedAt) >= defaultSelectionMinimumAge
    }

    private func allocatedSize(of url: URL) -> Int64 {
        var visitedEntries = 0
        return allocatedSize(path: url.path, visitedEntries: &visitedEntries)
    }

    private func allocatedSize(path: String, visitedEntries: inout Int) -> Int64 {
        guard visitedEntries < policy.maxSizeTraversalEntries else {
            return 0
        }

        var status = stat()
        guard lstat(path, &status) == 0 else {
            return 0
        }

        visitedEntries += 1
        let mode = status.st_mode & S_IFMT
        guard mode != S_IFLNK else {
            return 0
        }

        var total = Int64(status.st_blocks) * 512
        guard mode == S_IFDIR else {
            return total
        }

        guard let directory = opendir(path) else {
            return total
        }
        defer { closedir(directory) }

        while let entry = readdir(directory), visitedEntries < policy.maxSizeTraversalEntries {
            let name = withUnsafePointer(to: &entry.pointee.d_name) { pointer in
                pointer.withMemoryRebound(to: CChar.self, capacity: Int(entry.pointee.d_namlen)) {
                    String(cString: $0)
                }
            }

            guard name != ".", name != "..", !name.hasPrefix(".") else {
                continue
            }

            total += allocatedSize(
                path: URL(fileURLWithPath: path, isDirectory: true).appendingPathComponent(name).path,
                visitedEntries: &visitedEntries
            )
        }

        return total
    }

    private func resourceDate(_ url: URL, key: URLResourceKey) -> Date? {
        try? url.resourceValues(forKeys: [key]).contentModificationDate
    }

    private func directoryExists(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
            && fileManager.isReadableFile(atPath: url.path)
    }

    private func isAllowedCleanupPath(_ url: URL) -> Bool {
        scopes.contains { scope in
            isInside(url.standardizedFileURL, root: scope.root.standardizedFileURL)
        }
    }

    private func isInside(_ url: URL, root: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let rootPath = root.standardizedFileURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard !rootPath.isEmpty else {
            return false
        }

        let normalizedRoot = "/" + rootPath
        return path == normalizedRoot || path.hasPrefix(normalizedRoot + "/")
    }

    private static func developerScope(
        _ home: URL,
        _ relativePath: String,
        defaultSelectionMinimumAge: TimeInterval
    ) -> CleanupScope {
        CleanupScope(
            root: home.appendingPathComponent(relativePath, isDirectory: true),
            kind: .developerCache,
            risk: .manualReview,
            minimumAge: 0,
            defaultSelected: false,
            reason: "Developer cache item",
            defaultSelectionMinimumAge: defaultSelectionMinimumAge
        )
    }

    private static func packageScope(_ home: URL, _ relativePath: String) -> CleanupScope {
        CleanupScope(
            root: home.appendingPathComponent(relativePath, isDirectory: true),
            kind: .packageManagerCache,
            risk: .manualReview,
            minimumAge: 0,
            defaultSelected: false,
            reason: "Package manager cache item"
        )
    }

}

private extension Int {
    var days: TimeInterval { TimeInterval(self) * 86_400 }
}
