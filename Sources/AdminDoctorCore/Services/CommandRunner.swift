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
            return "Unsafe executable is not allowed: \(executable)"
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
    private let deniedExecutables: Set<String> = [
        "/bin/bash",
        "/bin/sh",
        "/bin/zsh",
        "/usr/bin/osascript",
        "/usr/bin/sudo"
    ]

    public init() {}

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
        guard command.executable.hasPrefix("/") else {
            throw CommandRunnerError.unsafeExecutable(command.executable)
        }

        guard !deniedExecutables.contains(command.executable) else {
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
