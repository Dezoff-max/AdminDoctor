import Foundation

public enum CleanupCandidateKind: String, CaseIterable, Codable, Sendable {
    case userCache
    case appContainerCache
    case systemCache
    case temporaryFile
    case userLog
    case systemLog
    case downloadedInstaller
    case developerCache
    case packageManagerCache

    public var title: String {
        switch self {
        case .userCache:
            return "User cache"
        case .appContainerCache:
            return "App container cache"
        case .systemCache:
            return "System cache"
        case .temporaryFile:
            return "Temporary file"
        case .userLog:
            return "User log"
        case .systemLog:
            return "System log"
        case .downloadedInstaller:
            return "Downloaded installer"
        case .developerCache:
            return "Developer cache"
        case .packageManagerCache:
            return "Package manager cache"
        }
    }

    public var symbolName: String {
        switch self {
        case .userCache:
            return "externaldrive.badge.timemachine"
        case .appContainerCache:
            return "app.badge"
        case .systemCache:
            return "lock.badge.clock"
        case .temporaryFile:
            return "clock.arrow.circlepath"
        case .userLog:
            return "doc.text"
        case .systemLog:
            return "doc.badge.gearshape"
        case .downloadedInstaller:
            return "shippingbox"
        case .developerCache:
            return "hammer"
        case .packageManagerCache:
            return "archivebox"
        }
    }
}

public enum CleanupRisk: String, CaseIterable, Codable, Identifiable, Sendable {
    case safe
    case caution
    case manualReview
    case requiresHelper

    public var id: String { rawValue }
}

public struct CleanupCandidate: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var kind: CleanupCandidateKind
    public var risk: CleanupRisk
    public var path: String
    public var displayName: String
    public var byteCount: Int64
    public var modifiedAt: Date?
    public var defaultSelected: Bool
    public var requiresPrivilegedHelper: Bool
    public var groupIdentifier: String
    public var groupTitle: String
    public var reason: String

    public init(
        id: UUID = UUID(),
        kind: CleanupCandidateKind,
        risk: CleanupRisk = .manualReview,
        path: String,
        displayName: String,
        byteCount: Int64,
        modifiedAt: Date?,
        defaultSelected: Bool,
        requiresPrivilegedHelper: Bool = false,
        groupIdentifier: String? = nil,
        groupTitle: String? = nil,
        reason: String
    ) {
        self.id = id
        self.kind = kind
        self.risk = risk
        self.path = path
        self.displayName = displayName
        self.byteCount = byteCount
        self.modifiedAt = modifiedAt
        self.defaultSelected = defaultSelected
        self.requiresPrivilegedHelper = requiresPrivilegedHelper
        self.groupIdentifier = groupIdentifier ?? kind.rawValue
        self.groupTitle = groupTitle ?? kind.title
        self.reason = reason
    }

    public var byteCountLabel: String {
        ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
    }
}

public struct CleanupSnapshot: Codable, Equatable, Sendable {
    public var scannedAt: Date
    public var candidates: [CleanupCandidate]
    public var skippedPaths: [String]

    public init(scannedAt: Date, candidates: [CleanupCandidate], skippedPaths: [String] = []) {
        self.scannedAt = scannedAt
        self.candidates = candidates
        self.skippedPaths = skippedPaths
    }

    public var totalBytes: Int64 {
        candidates.reduce(0) { $0 + $1.byteCount }
    }

    public var defaultSelectedBytes: Int64 {
        candidates
            .filter { $0.defaultSelected && !$0.requiresPrivilegedHelper }
            .reduce(0) { $0 + $1.byteCount }
    }

    public var totalBytesLabel: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }
}

public struct CleanupFailure: Codable, Equatable, Sendable {
    public var path: String
    public var message: String

    public init(path: String, message: String) {
        self.path = path
        self.message = message
    }
}

public struct CleanupExecutionSummary: Codable, Equatable, Sendable {
    public var trashed: [CleanupCandidate]
    public var failures: [CleanupFailure]

    public init(trashed: [CleanupCandidate], failures: [CleanupFailure]) {
        self.trashed = trashed
        self.failures = failures
    }

    public var reclaimedBytes: Int64 {
        trashed.reduce(0) { $0 + $1.byteCount }
    }

    public var reclaimedBytesLabel: String {
        ByteCountFormatter.string(fromByteCount: reclaimedBytes, countStyle: .file)
    }
}
