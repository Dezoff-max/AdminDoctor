import Foundation

public struct Command: Equatable, Sendable {
    public var executable: String
    public var arguments: [String]
    public var timeout: TimeInterval

    public init(_ executable: String, arguments: [String] = [], timeout: TimeInterval = 8) {
        self.executable = executable
        self.arguments = arguments
        self.timeout = timeout
    }

    public var displayName: String {
        ([URL(fileURLWithPath: executable).lastPathComponent] + arguments).joined(separator: " ")
    }
}

public struct CommandResult: Equatable, Sendable {
    public var stdout: String
    public var stderr: String
    public var exitCode: Int32

    public init(stdout: String, stderr: String = "", exitCode: Int32 = 0) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
    }

    public var succeeded: Bool { exitCode == 0 }
}

public enum CommandRunnerError: Error, Equatable, LocalizedError {
    case unsafeExecutable(String)
    case launchFailed(String)
    case timedOut(String)

    public var errorDescription: String? {
        switch self {
        case .unsafeExecutable(let executable):
            return "Executable is not on the allow-list: \(executable)"
        case .launchFailed(let message):
            return "Command launch failed: \(message)"
        case .timedOut(let command):
            return "Command timed out: \(command)"
        }
    }
}

public protocol CommandRunning: Sendable {
    func run(_ command: Command) throws -> CommandResult
}

public final class ProcessRunner: CommandRunning, @unchecked Sendable {
    /// Every executable AdminDoctor is allowed to launch. Anything else is refused,
    /// so a new tool has to be added here deliberately and shows up in review.
    /// Shells, interpreters, `env`, `osascript`, and `sudo` must never be listed.
    public static let defaultAllowedExecutables: Set<String> = [
        "/bin/ps",
        "/sbin/ifconfig",
        "/sbin/ping",
        "/sbin/route",
        "/usr/bin/codesign",
        "/usr/bin/csrutil",
        "/usr/bin/curl",
        "/usr/bin/dig",
        "/usr/bin/dscacheutil",
        "/usr/bin/fdesetup",
        "/usr/bin/nc",
        "/usr/bin/profiles",
        "/usr/bin/sw_vers",
        "/usr/bin/uname",
        "/usr/bin/vm_stat",
        "/usr/libexec/ApplicationFirewall/socketfilterfw",
        "/usr/sbin/arp",
        "/usr/sbin/diskutil",
        "/usr/sbin/ioreg",
        "/usr/sbin/netstat",
        "/usr/sbin/networksetup",
        "/usr/sbin/scutil",
        "/usr/sbin/spctl",
        "/usr/sbin/sysctl",
        "/usr/sbin/system_profiler",
        "/usr/sbin/traceroute"
    ]

    private let allowedExecutables: Set<String>

    public init(allowedExecutables: Set<String> = ProcessRunner.defaultAllowedExecutables) {
        self.allowedExecutables = allowedExecutables
    }

    public func run(_ command: Command) throws -> CommandResult {
        try validate(command)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: command.executable)
        process.arguments = command.arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw CommandRunnerError.launchFailed(error.localizedDescription)
        }

        let stdoutBuffer = ProcessOutputBuffer()
        let stderrBuffer = ProcessOutputBuffer()
        let readGroup = DispatchGroup()

        readGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            stdoutBuffer.store(stdoutPipe.fileHandleForReading.readDataToEndOfFile())
            readGroup.leave()
        }

        readGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            stderrBuffer.store(stderrPipe.fileHandleForReading.readDataToEndOfFile())
            readGroup.leave()
        }

        let waitGroup = DispatchGroup()
        waitGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            process.waitUntilExit()
            waitGroup.leave()
        }

        if waitGroup.wait(timeout: .now() + command.timeout) == .timedOut {
            process.terminate()
            _ = waitGroup.wait(timeout: .now() + 1)
            _ = readGroup.wait(timeout: .now() + 1)
            throw CommandRunnerError.timedOut(command.displayName)
        }

        readGroup.wait()

        return CommandResult(
            stdout: stdoutBuffer.stringValue(),
            stderr: stderrBuffer.stringValue(),
            exitCode: process.terminationStatus
        )
    }

    private func validate(_ command: Command) throws {
        // Exact match only: relative paths and spellings such as
        // "/usr/bin/../../bin/sh" are not in the list and are refused.
        guard allowedExecutables.contains(command.executable) else {
            throw CommandRunnerError.unsafeExecutable(command.executable)
        }
    }
}

private final class ProcessOutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func store(_ newData: Data) {
        lock.lock()
        data = newData
        lock.unlock()
    }

    func stringValue() -> String {
        lock.lock()
        let currentData = data
        lock.unlock()
        return String(data: currentData, encoding: .utf8) ?? ""
    }
}
