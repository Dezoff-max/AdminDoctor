import Foundation

public enum PrivilegedHelperInstallState: String, Codable, Equatable, Sendable {
    case notBundled
    case bundledOnly
    case requiresApproval
    case registered
    case installed
}

public struct PrivilegedHelperStatus: Codable, Equatable, Sendable {
    public var label: String
    public var bundledToolPath: String?
    public var installedToolPath: String
    public var launchDaemonPath: String
    public var bundledToolPresent: Bool
    public var installedToolPresent: Bool
    public var launchDaemonPresent: Bool
    public var codeSignatureVerified: Bool?
    public var serviceManagementStatus: String?
    public var xpcVersion: String?
    public var state: PrivilegedHelperInstallState
    public var checkedAt: Date

    public init(
        label: String,
        bundledToolPath: String?,
        installedToolPath: String,
        launchDaemonPath: String,
        bundledToolPresent: Bool,
        installedToolPresent: Bool,
        launchDaemonPresent: Bool,
        codeSignatureVerified: Bool?,
        serviceManagementStatus: String? = nil,
        xpcVersion: String? = nil,
        state: PrivilegedHelperInstallState,
        checkedAt: Date
    ) {
        self.label = label
        self.bundledToolPath = bundledToolPath
        self.installedToolPath = installedToolPath
        self.launchDaemonPath = launchDaemonPath
        self.bundledToolPresent = bundledToolPresent
        self.installedToolPresent = installedToolPresent
        self.launchDaemonPresent = launchDaemonPresent
        self.codeSignatureVerified = codeSignatureVerified
        self.serviceManagementStatus = serviceManagementStatus
        self.xpcVersion = xpcVersion
        self.state = state
        self.checkedAt = checkedAt
    }

    public func withRuntimeStatus(serviceManagementStatus: String?, xpcVersion: String?) -> PrivilegedHelperStatus {
        let resolvedState: PrivilegedHelperInstallState
        switch serviceManagementStatus {
        case "Enabled":
            resolvedState = .registered
        case "Requires approval":
            resolvedState = .requiresApproval
        default:
            resolvedState = state
        }

        return PrivilegedHelperStatus(
            label: label,
            bundledToolPath: bundledToolPath,
            installedToolPath: installedToolPath,
            launchDaemonPath: launchDaemonPath,
            bundledToolPresent: bundledToolPresent,
            installedToolPresent: installedToolPresent,
            launchDaemonPresent: launchDaemonPresent,
            codeSignatureVerified: codeSignatureVerified,
            serviceManagementStatus: serviceManagementStatus,
            xpcVersion: xpcVersion,
            state: resolvedState,
            checkedAt: checkedAt
        )
    }
}

public final class PrivilegedHelperStatusService: @unchecked Sendable {
    public static let helperLabel = "dev.admindoctor.AdminDoctorPrivilegedHelper"
    public static let helperExecutableName = "AdminDoctorPrivilegedHelper"
    public static let installedToolPath = "/Library/PrivilegedHelperTools/\(helperLabel)"
    public static let launchDaemonPath = "/Library/LaunchDaemons/\(helperLabel).plist"

    private let runner: any CommandRunning
    private let now: @Sendable () -> Date
    private let installedToolPath: String
    private let launchDaemonPath: String

    public init(
        runner: any CommandRunning = ProcessRunner(),
        installedToolPath: String = PrivilegedHelperStatusService.installedToolPath,
        launchDaemonPath: String = PrivilegedHelperStatusService.launchDaemonPath,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.runner = runner
        self.installedToolPath = installedToolPath
        self.launchDaemonPath = launchDaemonPath
        self.now = now
    }

    public func status(bundledToolPath: String?) -> PrivilegedHelperStatus {
        let bundledPresent = bundledToolPath.map { FileManager.default.isExecutableFile(atPath: $0) } ?? false
        let installedPresent = FileManager.default.isExecutableFile(atPath: installedToolPath)
        let launchDaemonPresent = FileManager.default.fileExists(atPath: launchDaemonPath)
        let signatureVerified = installedPresent ? verifyCodeSignature(path: installedToolPath) : nil

        let state: PrivilegedHelperInstallState
        if installedPresent, launchDaemonPresent {
            state = .installed
        } else if bundledPresent {
            state = .bundledOnly
        } else {
            state = .notBundled
        }

        return PrivilegedHelperStatus(
            label: Self.helperLabel,
            bundledToolPath: bundledToolPath,
            installedToolPath: installedToolPath,
            launchDaemonPath: launchDaemonPath,
            bundledToolPresent: bundledPresent,
            installedToolPresent: installedPresent,
            launchDaemonPresent: launchDaemonPresent,
            codeSignatureVerified: signatureVerified,
            state: state,
            checkedAt: now()
        )
    }

    private func verifyCodeSignature(path: String) -> Bool {
        guard let result = try? runner.run(Command("/usr/bin/codesign", arguments: ["--verify", "--strict", path], timeout: 8)) else {
            return false
        }
        return result.succeeded
    }
}
