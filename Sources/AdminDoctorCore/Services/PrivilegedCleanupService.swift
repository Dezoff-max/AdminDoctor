import Foundation

public enum PrivilegedCleanupError: Error, Equatable, LocalizedError {
    case unsafeQuarantineDirectory(String, String)

    public var errorDescription: String? {
        switch self {
        case .unsafeQuarantineDirectory(let path, let reason):
            return "Quarantine directory \(path) is not trusted: \(reason)."
        }
    }
}

public final class PrivilegedCleanupService: @unchecked Sendable {
    /// Quarantine lives under /Library so that only root can create or replace it.
    /// A user-writable location such as /Users/Shared would let any local user plant
    /// a symbolic link and redirect files moved by the root helper.
    public static let defaultQuarantineBase = URL(
        fileURLWithPath: "/Library/Application Support/AdminDoctor/Quarantine",
        isDirectory: true
    )

    private let fileManager: FileManager
    private let scopes: [CleanupScope]
    private let quarantineBase: URL
    private let auditLogURL: URL
    private let now: @Sendable () -> Date

    public init(
        fileManager: FileManager = .default,
        scopes: [CleanupScope] = DiskCleanupService.systemCleanupScopes(),
        quarantineBase: URL = PrivilegedCleanupService.defaultQuarantineBase,
        auditLogURL: URL = URL(fileURLWithPath: "/Library/Logs/AdminDoctor/privileged-helper-audit.jsonl"),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.fileManager = fileManager
        self.scopes = scopes
        self.quarantineBase = quarantineBase
        self.auditLogURL = auditLogURL
        self.now = now
    }

    public func plan(paths requestedPaths: [String]) -> PrivilegedCleanupPlan {
        let generatedAt = now()
        let normalizedPaths = normalize(paths: requestedPaths)
        let eligibility = eligibleCandidates(for: normalizedPaths, timestamp: generatedAt, action: .dryRun)
        var rejected = eligibility.rejected

        if let auditFailure = appendAuditEvents(eligibility.auditEvents) {
            rejected.append(auditFailure)
        }

        return PrivilegedCleanupPlan(
            generatedAt: generatedAt,
            requestedPaths: normalizedPaths,
            eligibleCandidates: eligibility.candidates,
            rejected: rejected,
            auditEvents: eligibility.auditEvents
        )
    }

    public func quarantine(paths requestedPaths: [String]) -> PrivilegedCleanupQuarantineResult {
        let executedAt = now()
        let normalizedPaths = normalize(paths: requestedPaths)
        let eligibility = eligibleCandidates(for: normalizedPaths, timestamp: executedAt, action: .quarantine)
        var failures = eligibility.rejected
        var auditEvents = eligibility.auditEvents
        var moved: [CleanupCandidate] = []
        let quarantineRoot = sessionQuarantineRoot(for: executedAt)

        do {
            try prepareQuarantineRoot(quarantineRoot)
        } catch {
            let failure = CleanupFailure(path: quarantineRoot.path, message: "Could not create quarantine directory: \(error.localizedDescription)")
            failures.append(failure)
            auditEvents.append(auditEvent(timestamp: executedAt, action: .quarantine, path: quarantineRoot.path, result: "failed", message: failure.message))
            _ = appendAuditEvents(auditEvents)
            return PrivilegedCleanupQuarantineResult(
                executedAt: executedAt,
                quarantineRoot: quarantineRoot.path,
                moved: moved,
                failures: failures,
                auditEvents: auditEvents
            )
        }

        for candidate in eligibility.candidates {
            let source = URL(fileURLWithPath: candidate.path).standardizedFileURL
            guard fileManager.fileExists(atPath: source.path) else {
                let failure = CleanupFailure(path: candidate.path, message: "Item no longer exists.")
                failures.append(failure)
                auditEvents.append(auditEvent(timestamp: executedAt, action: .quarantine, path: candidate.path, result: "failed", message: failure.message))
                continue
            }

            let destination = uniqueDestination(for: source, in: quarantineRoot)
            do {
                try fileManager.moveItem(at: source, to: destination)
                moved.append(candidate)
                auditEvents.append(auditEvent(timestamp: executedAt, action: .quarantine, path: candidate.path, result: "moved", message: "Moved to \(destination.path)."))
            } catch {
                let failure = CleanupFailure(path: candidate.path, message: error.localizedDescription)
                failures.append(failure)
                auditEvents.append(auditEvent(timestamp: executedAt, action: .quarantine, path: candidate.path, result: "failed", message: error.localizedDescription))
            }
        }

        if let auditFailure = appendAuditEvents(auditEvents) {
            failures.append(auditFailure)
        }

        return PrivilegedCleanupQuarantineResult(
            executedAt: executedAt,
            quarantineRoot: quarantineRoot.path,
            moved: moved,
            failures: failures,
            auditEvents: auditEvents
        )
    }

    private func eligibleCandidates(
        for requestedPaths: [String],
        timestamp: Date,
        action: PrivilegedCleanupAction
    ) -> (candidates: [CleanupCandidate], rejected: [CleanupFailure], auditEvents: [PrivilegedCleanupAuditEvent]) {
        let snapshot = (try? DiskCleanupService(fileManager: fileManager, scopes: scopes).scan()) ?? CleanupSnapshot(scannedAt: timestamp, candidates: [])
        let candidateByPath = Dictionary(uniqueKeysWithValues: snapshot.candidates.map { ($0.path, $0) })
        var candidates: [CleanupCandidate] = []
        var rejected: [CleanupFailure] = []
        var auditEvents: [PrivilegedCleanupAuditEvent] = []

        for path in requestedPaths {
            let url = URL(fileURLWithPath: path).standardizedFileURL
            guard isInsideAllowedScope(url) else {
                let message = "Path is outside privileged cleanup allow-list."
                rejected.append(CleanupFailure(path: path, message: message))
                auditEvents.append(auditEvent(timestamp: timestamp, action: action, path: path, result: "rejected", message: message))
                continue
            }

            guard let candidate = candidateByPath[url.path], candidate.requiresPrivilegedHelper else {
                let message = "Path is not an active privileged cleanup candidate."
                rejected.append(CleanupFailure(path: path, message: message))
                auditEvents.append(auditEvent(timestamp: timestamp, action: action, path: path, result: "rejected", message: message))
                continue
            }

            guard !isSymbolicLink(url) else {
                let message = "Symbolic links are not eligible for privileged cleanup."
                rejected.append(CleanupFailure(path: path, message: message))
                auditEvents.append(auditEvent(timestamp: timestamp, action: action, path: path, result: "rejected", message: message))
                continue
            }

            candidates.append(candidate)
            auditEvents.append(auditEvent(timestamp: timestamp, action: action, path: path, result: "eligible", message: "\(candidate.byteCountLabel) eligible."))
        }

        return (candidates, rejected, auditEvents)
    }

    private func normalize(paths: [String]) -> [String] {
        Array(Set(paths.map { URL(fileURLWithPath: $0).standardizedFileURL.path })).sorted()
    }

    private func isInsideAllowedScope(_ url: URL) -> Bool {
        scopes.contains { scope in
            let path = url.standardizedFileURL.path
            let root = scope.root.standardizedFileURL.path
            return path == root || path.hasPrefix(root + "/")
        }
    }

    private func isSymbolicLink(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey]) else {
            return false
        }
        return values.isSymbolicLink == true
    }

    private func prepareQuarantineRoot(_ quarantineRoot: URL) throws {
        let ownerOnly: [FileAttributeKey: Any] = [.posixPermissions: 0o700]
        let container = quarantineBase.deletingLastPathComponent()

        try fileManager.createDirectory(at: quarantineBase, withIntermediateDirectories: true, attributes: ownerOnly)
        try validateQuarantineDirectory(container)
        try validateQuarantineDirectory(quarantineBase)
        try fileManager.setAttributes(ownerOnly, ofItemAtPath: quarantineBase.path)

        if !fileManager.fileExists(atPath: quarantineRoot.path) {
            try fileManager.createDirectory(at: quarantineRoot, withIntermediateDirectories: false, attributes: ownerOnly)
        }
        try validateQuarantineDirectory(quarantineRoot)
    }

    /// Refuses quarantine directories that another user could have planted or can modify.
    private func validateQuarantineDirectory(_ url: URL) throws {
        // attributesOfItem does not follow a trailing symbolic link.
        let attributes = try fileManager.attributesOfItem(atPath: url.path)

        guard attributes[.type] as? FileAttributeType == .typeDirectory else {
            throw PrivilegedCleanupError.unsafeQuarantineDirectory(url.path, "it is not a real directory")
        }

        let owner = (attributes[.ownerAccountID] as? NSNumber)?.uint32Value
        guard owner == geteuid() else {
            throw PrivilegedCleanupError.unsafeQuarantineDirectory(url.path, "it is owned by another user")
        }

        let permissions = (attributes[.posixPermissions] as? NSNumber)?.intValue ?? 0o777
        guard permissions & 0o022 == 0 else {
            throw PrivilegedCleanupError.unsafeQuarantineDirectory(url.path, "it is writable by other users")
        }
    }

    private func sessionQuarantineRoot(for date: Date) -> URL {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let safeTimestamp = formatter.string(from: date)
            .replacingOccurrences(of: ":", with: "-")
        return quarantineBase.appendingPathComponent(safeTimestamp, isDirectory: true)
    }

    private func uniqueDestination(for source: URL, in root: URL) -> URL {
        let base = root.appendingPathComponent(source.lastPathComponent)
        guard fileManager.fileExists(atPath: base.path) else {
            return base
        }

        let suffix = UUID().uuidString.prefix(8)
        let stem = source.deletingPathExtension().lastPathComponent
        let fileName = source.pathExtension.isEmpty ? "\(stem)-\(suffix)" : "\(stem)-\(suffix).\(source.pathExtension)"
        return root.appendingPathComponent(fileName)
    }

    private func auditEvent(
        timestamp: Date,
        action: PrivilegedCleanupAction,
        path: String,
        result: String,
        message: String
    ) -> PrivilegedCleanupAuditEvent {
        PrivilegedCleanupAuditEvent(timestamp: timestamp, action: action, path: path, result: result, message: message)
    }

    private func appendAuditEvents(_ events: [PrivilegedCleanupAuditEvent]) -> CleanupFailure? {
        guard !events.isEmpty else {
            return nil
        }

        do {
            try fileManager.createDirectory(
                at: auditLogURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let lines = try events.map { event -> String in
                let data = try encoder.encode(event)
                return String(data: data, encoding: .utf8) ?? "{}"
            }.joined(separator: "\n") + "\n"

            if fileManager.fileExists(atPath: auditLogURL.path) {
                let handle = try FileHandle(forWritingTo: auditLogURL)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: Data(lines.utf8))
            } else {
                try Data(lines.utf8).write(to: auditLogURL, options: [.atomic])
            }
            return nil
        } catch {
            return CleanupFailure(path: auditLogURL.path, message: "Audit log write failed: \(error.localizedDescription)")
        }
    }
}
