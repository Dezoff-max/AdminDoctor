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
        try withHelperProxy(timeout: timeout) { proxy, finish in
            proxy.helperVersion { version in
                finish(.success(version))
            }
        }
    }

    func planSystemCleanup(paths: [String], timeout: TimeInterval = 10) throws -> PrivilegedCleanupPlan {
        let data = try withHelperProxy(timeout: timeout) { proxy, finish in
            proxy.planSystemCleanup(paths: paths) { data, error in
                finish(Self.dataResult(data: data, error: error))
            }
        }
        return try JSONDecoder.adminDoctor.decode(PrivilegedCleanupPlan.self, from: data)
    }

    func quarantineSystemCleanup(paths: [String], timeout: TimeInterval = 30) throws -> PrivilegedCleanupQuarantineResult {
        let data = try withHelperProxy(timeout: timeout) { proxy, finish in
            proxy.quarantineSystemCleanup(paths: paths) { data, error in
                finish(Self.dataResult(data: data, error: error))
            }
        }
        return try JSONDecoder.adminDoctor.decode(PrivilegedCleanupQuarantineResult.self, from: data)
    }

    private func withHelperProxy<T>(
        timeout: TimeInterval,
        call: (AdminDoctorPrivilegedHelperXPC, @escaping (Result<T, Error>) -> Void) -> Void
    ) throws -> T {
        let connection = NSXPCConnection(
            machServiceName: PrivilegedHelperXPCContract.machServiceName,
            options: .privileged
        )
        connection.remoteObjectInterface = NSXPCInterface(with: AdminDoctorPrivilegedHelperXPC.self)
        connection.resume()
        defer { connection.invalidate() }

        let semaphore = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var response: Result<T, Error> = .failure(PrivilegedHelperControllerError.remoteProxyUnavailable)

        let finish: (Result<T, Error>) -> Void = { result in
            lock.lock()
            response = result
            lock.unlock()
            semaphore.signal()
        }

        guard
            let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
                finish(.failure(PrivilegedHelperControllerError.xpcFailed(error.localizedDescription)))
            }) as? AdminDoctorPrivilegedHelperXPC
        else {
            throw PrivilegedHelperControllerError.remoteProxyUnavailable
        }

        call(proxy, finish)

        guard semaphore.wait(timeout: .now() + timeout) == .success else {
            throw PrivilegedHelperControllerError.xpcTimedOut
        }

        lock.lock()
        let finalResponse = response
        lock.unlock()
        return try finalResponse.get()
    }

    private static func dataResult(data: Data?, error: String?) -> Result<Data, Error> {
        if let error {
            return .failure(PrivilegedHelperControllerError.xpcFailed(error))
        }
        guard let data else {
            return .failure(PrivilegedHelperControllerError.remoteProxyUnavailable)
        }
        return .success(data)
    }
}

private extension JSONDecoder {
    static var adminDoctor: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
