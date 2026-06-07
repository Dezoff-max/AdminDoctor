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
