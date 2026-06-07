import AdminDoctorCore
import Foundation
import ServiceManagement

enum PrivilegedHelperControllerError: Error, LocalizedError {
    case remoteProxyUnavailable
    case xpcTimedOut
    case xpcFailed(String)

    var errorDescription: String? {
        switch self {
        case .remoteProxyUnavailable:
            return "Privileged helper XPC proxy is unavailable."
        case .xpcTimedOut:
            return "Privileged helper XPC request timed out."
        case .xpcFailed(let message):
            return message
        }
    }
}

final class PrivilegedHelperController: @unchecked Sendable {
    static let launchDaemonPlistName = "\(PrivilegedHelperStatusService.helperLabel).plist"

    private let service = SMAppService.daemon(plistName: launchDaemonPlistName)

    func serviceStatusTitle() -> String {
        switch service.status {
        case .notRegistered:
            return "Not registered"
        case .enabled:
            return "Enabled"
        case .requiresApproval:
            return "Requires approval"
        case .notFound:
            return "LaunchDaemon plist not found"
        @unknown default:
            return "Unknown"
        }
    }

    func register() throws {
        try service.register()
    }

    func unregister() throws {
        try service.unregister()
    }

    func helperVersion(timeout: TimeInterval = 3) throws -> String {
        let connection = NSXPCConnection(
            machServiceName: PrivilegedHelperXPCContract.machServiceName,
            options: .privileged
        )
        connection.remoteObjectInterface = NSXPCInterface(with: AdminDoctorPrivilegedHelperXPC.self)
        connection.resume()
        defer { connection.invalidate() }

        let semaphore = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var response: Result<String, Error> = .failure(PrivilegedHelperControllerError.remoteProxyUnavailable)

        guard
            let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
                lock.lock()
                response = .failure(PrivilegedHelperControllerError.xpcFailed(error.localizedDescription))
                lock.unlock()
                semaphore.signal()
            }) as? AdminDoctorPrivilegedHelperXPC
        else {
            throw PrivilegedHelperControllerError.remoteProxyUnavailable
        }

        proxy.helperVersion { version in
            lock.lock()
            response = .success(version)
            lock.unlock()
            semaphore.signal()
        }

        guard semaphore.wait(timeout: .now() + timeout) == .success else {
            throw PrivilegedHelperControllerError.xpcTimedOut
        }

        lock.lock()
        let finalResponse = response
        lock.unlock()
        return try finalResponse.get()
    }
}
