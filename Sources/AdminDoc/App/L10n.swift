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
    case "Older user cache item":
        return L10n.string("cleanup.reason.userCache")
    case "Older temporary item":
        return L10n.string("cleanup.reason.temporaryFile")
    case "Older user log item":
        return L10n.string("cleanup.reason.userLog")
    case "Older downloaded installer or archive":
        return L10n.string("cleanup.reason.downloadedInstaller")
    default:
        return reason
    }
}
