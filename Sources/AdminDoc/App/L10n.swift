import AdminDocCore
import Foundation

enum L10n {
    static func string(_ key: String) -> String {
        NSLocalizedString(key, bundle: .main, value: key, comment: "")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: Locale.current, arguments: arguments)
    }
}

extension DiagnosticCategory {
    var localizedTitle: String {
        L10n.string("category.\(rawValue)")
    }
}

extension DiagnosticSeverity {
    var localizedTitle: String {
        L10n.string("severity.\(rawValue)")
    }
}

extension CleanupCandidateKind {
    var localizedTitle: String {
        L10n.string("cleanup.kind.\(rawValue)")
    }
}

extension CleanupRisk {
    var localizedTitle: String {
        L10n.string("cleanup.risk.\(rawValue)")
    }
}

extension AdminPrivilegeStatus {
    var localizedTitle: String {
        L10n.string("admin.status.\(rawValue)")
    }

    var localizedMessage: String {
        L10n.string("admin.message.\(rawValue)")
    }
}

func localizedCleanupReason(_ reason: String) -> String {
    switch reason {
    case "User cache item":
        return L10n.string("cleanup.reason.userCache")
    case "Older user cache item":
        return L10n.string("cleanup.reason.userCache")
    case "Container cache item":
        return L10n.string("cleanup.reason.appContainerCache")
    case "Temporary item":
        return L10n.string("cleanup.reason.temporaryFile")
    case "Older temporary item":
        return L10n.string("cleanup.reason.temporaryFile")
    case "User log item":
        return L10n.string("cleanup.reason.userLog")
    case "Older user log item":
        return L10n.string("cleanup.reason.userLog")
    case "System cache item":
        return L10n.string("cleanup.reason.systemCache")
    case "System log item":
        return L10n.string("cleanup.reason.systemLog")
    case "Downloaded installer or archive":
        return L10n.string("cleanup.reason.downloadedInstaller")
    case "Older downloaded installer or archive":
        return L10n.string("cleanup.reason.downloadedInstaller")
    case "Developer cache item":
        return L10n.string("cleanup.reason.developerCache")
    case "Package manager cache item":
        return L10n.string("cleanup.reason.packageManagerCache")
    default:
        return reason
    }
}

func localizedCleanupGroupTitle(identifier: String, fallback: String) -> String {
    switch identifier {
    case "npm":
        return L10n.string("cleanup.group.npm")
    case "homebrew":
        return L10n.string("cleanup.group.homebrew")
    case "xcode":
        return L10n.string("cleanup.group.xcode")
    case "gradle":
        return L10n.string("cleanup.group.gradle")
    case "cargo":
        return L10n.string("cleanup.group.cargo")
    case "swiftpm":
        return L10n.string("cleanup.group.swiftpm")
    case "pip":
        return L10n.string("cleanup.group.pip")
    default:
        if CleanupCandidateKind(rawValue: identifier) != nil {
            return L10n.string("cleanup.kind.\(identifier)")
        }
        return fallback
    }
}
