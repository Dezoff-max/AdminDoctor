import Foundation

public enum DiagnosticCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case system
    case storage
    case security
    case network
    case profiles
    case launchServices
    case logs

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .system:
            return "System"
        case .storage:
            return "Storage"
        case .security:
            return "Security"
        case .network:
            return "Network"
        case .profiles:
            return "MDM & Profiles"
        case .launchServices:
            return "Launch Services"
        case .logs:
            return "Logs"
        }
    }

    public var symbolName: String {
        switch self {
        case .system:
            return "desktopcomputer"
        case .storage:
            return "internaldrive"
        case .security:
            return "lock.shield"
        case .network:
            return "network"
        case .profiles:
            return "person.crop.rectangle.stack"
        case .launchServices:
            return "gearshape.2"
        case .logs:
            return "doc.text.magnifyingglass"
        }
    }
}
