import AdminDoctorCore
import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case en
    case ru

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .en:
            return "EN"
        case .ru:
            return "RUS"
        }
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    static var systemDefault: AppLanguage {
        Locale.current.language.languageCode?.identifier == "ru" ? .ru : .en
    }
}

enum L10n {
    static let languagePreferenceKey = "appLanguage"

    static var currentLanguage: AppLanguage {
        if
            let value = UserDefaults.standard.string(forKey: languagePreferenceKey),
            let language = AppLanguage(rawValue: value)
        {
            return language
        }

        return .systemDefault
    }

    static var currentLocale: Locale {
        currentLanguage.locale
    }

    static func string(_ key: String) -> String {
        string(key, language: currentLanguage)
    }

    static func string(_ key: String, language: AppLanguage) -> String {
        localizedBundle(for: language).localizedString(forKey: key, value: key, table: nil)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: currentLocale, arguments: arguments)
    }

    private static func localizedBundle(for language: AppLanguage) -> Bundle {
        guard
            let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else {
            return .main
        }

        return bundle
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

extension Date {
    func localizedShortTimeString() -> String {
        formatted(.dateTime.hour().minute().locale(L10n.currentLocale))
    }

    func localizedShortDateTimeString() -> String {
        formatted(.dateTime.year().month(.abbreviated).day().hour().minute().locale(L10n.currentLocale))
    }
}
