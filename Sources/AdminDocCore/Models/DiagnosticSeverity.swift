import Foundation

public enum DiagnosticSeverity: String, CaseIterable, Codable, Identifiable, Sendable {
    case pass
    case warning
    case fail
    case info

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .pass:
            return "Pass"
        case .warning:
            return "Warning"
        case .fail:
            return "Fail"
        case .info:
            return "Info"
        }
    }

    public var sortPriority: Int {
        switch self {
        case .fail:
            return 0
        case .warning:
            return 1
        case .pass:
            return 2
        case .info:
            return 3
        }
    }
}

public enum BinaryStatus: Equatable, Sendable {
    case enabled
    case disabled
    case unavailable
}

public enum SeverityMapping {
    public static func requiredControl(_ status: BinaryStatus) -> DiagnosticSeverity {
        switch status {
        case .enabled:
            return .pass
        case .disabled:
            return .fail
        case .unavailable:
            return .info
        }
    }

    public static func recommendedControl(_ status: BinaryStatus) -> DiagnosticSeverity {
        switch status {
        case .enabled:
            return .pass
        case .disabled:
            return .warning
        case .unavailable:
            return .info
        }
    }

    public static func requiredSignal(isPresent: Bool) -> DiagnosticSeverity {
        isPresent ? .pass : .warning
    }
}
