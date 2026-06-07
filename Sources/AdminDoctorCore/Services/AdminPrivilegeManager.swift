import Foundation
import Security

public enum AdminPrivilegeStatus: String, Codable, Equatable, Sendable {
    case notRequested
    case requesting
    case authorized
    case denied
    case canceled
    case unavailable
}

public struct AdminPrivilegeState: Codable, Equatable, Sendable {
    public var status: AdminPrivilegeStatus
    public var requestedAt: Date?
    public var message: String

    public init(status: AdminPrivilegeStatus, requestedAt: Date? = nil, message: String) {
        self.status = status
        self.requestedAt = requestedAt
        self.message = message
    }

    public static let notRequested = AdminPrivilegeState(
        status: .notRequested,
        message: "Admin privileges have not been requested."
    )
}

public final class AdminPrivilegeManager: @unchecked Sendable {
    private static let adminRightName = "system.privilege.admin"

    private let now: @Sendable () -> Date
    private let lock = NSLock()
    private var authorization: AuthorizationRef?

    public init(now: @escaping @Sendable () -> Date = { Date() }) {
        self.now = now
    }

    deinit {
        lock.lock()
        let authorization = self.authorization
        self.authorization = nil
        lock.unlock()

        if let authorization {
            AuthorizationFree(authorization, [.destroyRights])
        }
    }

    public func requestAdminRights(prompt: String = "AdminDoctor needs administrator privileges for admin utility actions.") -> AdminPrivilegeState {
        lock.lock()
        if authorization != nil {
            lock.unlock()
            return AdminPrivilegeState(
                status: .authorized,
                requestedAt: now(),
                message: "Administrator privileges are already authorized for this session."
            )
        }
        lock.unlock()

        var authRef: AuthorizationRef?
        let flags: AuthorizationFlags = [
            .interactionAllowed,
            .extendRights,
            .preAuthorize
        ]

        let status = Self.adminRightName.withCString { rightName in
            kAuthorizationEnvironmentPrompt.withCString { promptName in
                prompt.withCString { promptValue in
                    var right = AuthorizationItem(
                        name: rightName,
                        valueLength: 0,
                        value: nil,
                        flags: 0
                    )

                    var promptItem = AuthorizationItem(
                        name: promptName,
                        valueLength: strlen(promptValue),
                        value: UnsafeMutableRawPointer(mutating: promptValue),
                        flags: 0
                    )

                    return withUnsafeMutablePointer(to: &right) { rightPointer in
                        var rights = AuthorizationRights(count: 1, items: rightPointer)
                        return withUnsafeMutablePointer(to: &promptItem) { promptPointer in
                            var environment = AuthorizationEnvironment(count: 1, items: promptPointer)
                            return AuthorizationCreate(&rights, &environment, flags, &authRef)
                        }
                    }
                }
            }
        }

        guard status == errAuthorizationSuccess, let authRef else {
            return state(for: status)
        }

        lock.lock()
        authorization = authRef
        lock.unlock()

        return AdminPrivilegeState(
            status: .authorized,
            requestedAt: now(),
            message: "Administrator privileges authorized for this app session."
        )
    }

    public func hasAuthorization() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return authorization != nil
    }

    private func state(for status: OSStatus) -> AdminPrivilegeState {
        let requestedAt = now()
        switch status {
        case errAuthorizationCanceled:
            return AdminPrivilegeState(
                status: .canceled,
                requestedAt: requestedAt,
                message: "Administrator authorization was canceled."
            )
        case errAuthorizationDenied:
            return AdminPrivilegeState(
                status: .denied,
                requestedAt: requestedAt,
                message: "Administrator authorization was denied."
            )
        default:
            return AdminPrivilegeState(
                status: .unavailable,
                requestedAt: requestedAt,
                message: "Administrator authorization failed with status \(status)."
            )
        }
    }
}
