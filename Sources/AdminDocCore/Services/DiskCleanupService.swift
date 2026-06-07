import Foundation

public struct CleanupScope: Equatable, Sendable {
    public var root: URL
    public var kind: CleanupCandidateKind
    public var minimumAge: TimeInterval
    public var defaultSelected: Bool
    public var defaultSelectionMinimumAge: TimeInterval?
    public var reason: String
    public var allowedExtensions: Set<String>?
    public var includeDirectories: Bool
    public var includeRegularFiles: Bool

    public init(
        root: URL,
        kind: CleanupCandidateKind,
        minimumAge: TimeInterval,
        defaultSelected: Bool,
        reason: String,
        allowedExtensions: Set<String>? = nil,
        defaultSelectionMinimumAge: TimeInterval? = nil,
        includeDirectories: Bool = true,
        includeRegularFiles: Bool = true
    ) {
        self.root = root
        self.kind = kind
        self.minimumAge = minimumAge
        self.defaultSelected = defaultSelected
        self.defaultSelectionMinimumAge = defaultSelectionMinimumAge
        self.reason = reason
        self.allowedExtensions = allowedExtensions.map { Set($0.map { $0.lowercased() }) }
        self.includeDirectories = includeDirectories
        self.includeRegularFiles = includeRegularFiles
    }
}

public struct CleanupPolicy: Equatable, Sendable {
    public var maxCandidateCount: Int

    public init(maxCandidateCount: Int = 2_000) {
        self.maxCandidateCount = maxCandidateCount
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
                minimumAge: 0,
                defaultSelected: true,
                reason: "User cache item",
                defaultSelectionMinimumAge: 7.days
            ),
            CleanupScope(
                root: URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true),
                kind: .temporaryFile,
                minimumAge: 0,
                defaultSelected: true,
                reason: "Temporary item",
                defaultSelectionMinimumAge: 1.days
            ),
            CleanupScope(
                root: home.appendingPathComponent("Library/Logs", isDirectory: true),
                kind: .userLog,
                minimumAge: 0,
                defaultSelected: false,
                reason: "User log item"
            ),
            CleanupScope(
                root: home.appendingPathComponent("Downloads", isDirectory: true),
                kind: .downloadedInstaller,
                minimumAge: 0,
                defaultSelected: false,
                reason: "Downloaded installer or archive",
                allowedExtensions: downloadsExtensions,
                includeDirectories: false
            )
        ]

        scopes.append(contentsOf: nestedContainerScopes(
            fileManager: fileManager,
            parent: home.appendingPathComponent("Library/Containers", isDirectory: true),
            relativeCachePath: "Data/Library/Caches",
            kind: .appContainerCache
        ))

        scopes.append(contentsOf: nestedContainerScopes(
            fileManager: fileManager,
            parent: home.appendingPathComponent("Library/Group Containers", isDirectory: true),
            relativeCachePath: "Library/Caches",
            kind: .appContainerCache
        ))

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
                let urls = try fileManager.contentsOfDirectory(
                    at: root,
                    includingPropertiesForKeys: [
                        .isDirectoryKey,
                        .isRegularFileKey,
                        .isSymbolicLinkKey,
                        .contentModificationDateKey,
                        .fileAllocatedSizeKey,
                        .totalFileAllocatedSizeKey
                    ],
                    options: [.skipsHiddenFiles]
                )

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

    public func moveToTrash(_ candidates: [CleanupCandidate]) -> CleanupExecutionSummary {
        var trashed: [CleanupCandidate] = []
        var failures: [CleanupFailure] = []

        for candidate in candidates {
            let url = URL(fileURLWithPath: candidate.path).standardizedFileURL
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
            path: standardized.path,
            displayName: standardized.lastPathComponent,
            byteCount: byteCount,
            modifiedAt: modifiedAt,
            defaultSelected: defaultSelected,
            reason: scope.reason
        )
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
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else {
            return 0
        }

        if values.isSymbolicLink == true || values.isDirectory != true {
            return Int64(resourceInt(url, keys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]) ?? 0)
        }

        var total: Int64 = 0
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [
                .isDirectoryKey,
                .isSymbolicLinkKey,
                .fileAllocatedSizeKey,
                .totalFileAllocatedSizeKey
            ],
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) else {
            return 0
        }

        for case let item as URL in enumerator {
            let isSymbolicLink = (try? item.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true
            if isSymbolicLink {
                enumerator.skipDescendants()
            }
            total += Int64(resourceInt(item, keys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]) ?? 0)
        }

        return total
    }

    private func resourceDate(_ url: URL, key: URLResourceKey) -> Date? {
        try? url.resourceValues(forKeys: [key]).contentModificationDate
    }

    private func resourceInt(_ url: URL, keys: [URLResourceKey]) -> Int? {
        guard let values = try? url.resourceValues(forKeys: Set(keys)) else {
            return nil
        }

        for key in keys {
            switch key {
            case .totalFileAllocatedSizeKey:
                if let value = values.totalFileAllocatedSize {
                    return value
                }
            case .fileAllocatedSizeKey:
                if let value = values.fileAllocatedSize {
                    return value
                }
            default:
                continue
            }
        }

        return nil
    }

    private func directoryExists(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
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
            minimumAge: 0,
            defaultSelected: false,
            reason: "Package manager cache item"
        )
    }

    private static func nestedContainerScopes(
        fileManager: FileManager,
        parent: URL,
        relativeCachePath: String,
        kind: CleanupCandidateKind
    ) -> [CleanupScope] {
        guard
            let containers = try? fileManager.contentsOfDirectory(
                at: parent,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        else {
            return []
        }

        return containers.compactMap { container -> CleanupScope? in
            guard
                ((try? container.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true)
            else {
                return nil
            }

            return CleanupScope(
                root: container.appendingPathComponent(relativeCachePath, isDirectory: true),
                kind: kind,
                minimumAge: 0,
                defaultSelected: true,
                reason: "Container cache item",
                defaultSelectionMinimumAge: 7.days
            )
        }
    }
}

private extension Int {
    var days: TimeInterval { TimeInterval(self) * 86_400 }
}
