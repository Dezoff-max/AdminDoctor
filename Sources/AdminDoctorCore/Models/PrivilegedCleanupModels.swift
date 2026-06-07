import Foundation

public enum PrivilegedCleanupAction: String, Codable, Sendable {
    case dryRun
    case quarantine
}

public struct PrivilegedCleanupAuditEvent: Codable, Equatable, Sendable {
    public var id: UUID
    public var timestamp: Date
    public var action: PrivilegedCleanupAction
    public var path: String
    public var result: String
    public var message: String

    public init(
        id: UUID = UUID(),
        timestamp: Date,
        action: PrivilegedCleanupAction,
        path: String,
        result: String,
        message: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.action = action
        self.path = path
        self.result = result
        self.message = message
    }
}
public struct PrivilegedCleanupPlan: Codable, Equatable, Sendable {
    public var generatedAt: Date
    public var requestedPaths: [String]
    public var eligibleCandidates: [CleanupCandidate]
    public var rejected: [CleanupFailure]
    public var auditEvents: [PrivilegedCleanupAuditEvent]

    public init(
        generatedAt: Date,
        requestedPaths: [String],
        eligibleCandidates: [CleanupCandidate],
        rejected: [CleanupFailure],
        auditEvents: [PrivilegedCleanupAuditEvent]
    ) {
        self.generatedAt = generatedAt
        self.requestedPaths = requestedPaths
        self.eligibleCandidates = eligibleCandidates
        self.rejected = rejected
        self.auditEvents = auditEvents
    }

    public var eligibleBytes: Int64 {
        eligibleCandidates.reduce(0) { $0 + $1.byteCount }
    }

    public var eligibleBytesLabel: String {
        ByteCountFormatter.string(fromByteCount: eligibleBytes, countStyle: .file)
    }
}

public struct PrivilegedCleanupQuarantineResult: Codable, Equatable, Sendable {
    public var executedAt: Date
    public var quarantineRoot: String
    public var moved: [CleanupCandidate]
    public var failures: [CleanupFailure]
    public var auditEvents: [PrivilegedCleanupAuditEvent]

    public init(
        executedAt: Date,
        quarantineRoot: String,
        moved: [CleanupCandidate],
        failures: [CleanupFailure],
        auditEvents: [PrivilegedCleanupAuditEvent]
    ) {
        self.executedAt = executedAt
        self.quarantineRoot = quarantineRoot
        self.moved = moved
        self.failures = failures
        self.auditEvents = auditEvents
    }

    public var movedBytes: Int64 {
        moved.reduce(0) { $0 + $1.byteCount }
    }

    public var movedBytesLabel: String {
        ByteCountFormatter.string(fromByteCount: movedBytes, countStyle: .file)
    }
}
