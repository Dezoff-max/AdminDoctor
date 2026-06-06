import Foundation

public enum SystemInfoParser {
    public static func parseBootSeconds(_ output: String) -> TimeInterval? {
        guard let seconds = ParserHelpers.firstCapture(in: output, pattern: #"sec\s*=\s*(\d+)"#) else {
            return nil
        }
        return TimeInterval(seconds)
    }

    public static func parseSerialNumber(_ output: String) -> String? {
        ParserHelpers.firstCapture(in: output, pattern: #""IOPlatformSerialNumber"\s*=\s*"([^"]+)""#)
            ?? ParserHelpers.firstCapture(in: output, pattern: #"Serial Number \(system\):\s*(\S+)"#)
    }

    public static func uptimeSummary(bootSeconds: TimeInterval, now: Date = Date()) -> String {
        let bootDate = Date(timeIntervalSince1970: bootSeconds)
        let interval = max(0, now.timeIntervalSince(bootDate))
        let days = Int(interval / 86_400)
        let hours = Int(interval.truncatingRemainder(dividingBy: 86_400) / 3_600)

        if days > 0 {
            return "\(days)d \(hours)h"
        }
        return "\(hours)h"
    }
}

public struct SystemInfoProvider: DiagnosticProvider {
    public let category: DiagnosticCategory = .system

    private let runner: any CommandRunning

    public init(runner: any CommandRunning) {
        self.runner = runner
    }

    public func collect() -> [DiagnosticResult] {
        [
            macOSVersionResult(),
            uptimeResult(),
            hardwareModelResult(),
            architectureResult()
        ]
    }

    private func macOSVersionResult() -> DiagnosticResult {
        let version = output(Command("/usr/bin/sw_vers", arguments: ["-productVersion"]))
        let build = output(Command("/usr/bin/sw_vers", arguments: ["-buildVersion"]))

        guard let version, let build else {
            return DiagnosticResult(
                category: .system,
                severity: .warning,
                title: "macOS version",
                summary: "Unable to read macOS version.",
                remediation: "Run sw_vers locally and check whether command execution is restricted.",
                source: "sw_vers"
            )
        }

        return DiagnosticResult(
            category: .system,
            severity: .info,
            title: "macOS version",
            summary: "\(version) build \(build)",
            details: [
                DiagnosticDetail(key: "Version", value: version),
                DiagnosticDetail(key: "Build", value: build)
            ],
            source: "sw_vers"
        )
    }

    private func uptimeResult() -> DiagnosticResult {
        guard
            let output = output(Command("/usr/sbin/sysctl", arguments: ["-n", "kern.boottime"])),
            let bootSeconds = SystemInfoParser.parseBootSeconds(output)
        else {
            return DiagnosticResult(
                category: .system,
                severity: .info,
                title: "Uptime",
                summary: "Unable to parse boot time.",
                source: "sysctl kern.boottime"
            )
        }

        let bootDate = Date(timeIntervalSince1970: bootSeconds)
        return DiagnosticResult(
            category: .system,
            severity: .info,
            title: "Uptime",
            summary: "Up for \(SystemInfoParser.uptimeSummary(bootSeconds: bootSeconds))",
            details: [
                DiagnosticDetail(key: "Boot time", value: ISO8601DateFormatter().string(from: bootDate))
            ],
            source: "sysctl kern.boottime"
        )
    }

    private func hardwareModelResult() -> DiagnosticResult {
        guard let model = output(Command("/usr/sbin/sysctl", arguments: ["-n", "hw.model"])) else {
            return DiagnosticResult(
                category: .system,
                severity: .info,
                title: "Hardware model",
                summary: "Unable to read hardware model.",
                source: "sysctl hw.model"
            )
        }

        return DiagnosticResult(
            category: .system,
            severity: .info,
            title: "Hardware model",
            summary: model,
            details: [DiagnosticDetail(key: "Model", value: model)],
            source: "sysctl hw.model"
        )
    }

    private func architectureResult() -> DiagnosticResult {
        guard let architecture = output(Command("/usr/bin/uname", arguments: ["-m"])) else {
            return DiagnosticResult(
                category: .system,
                severity: .info,
                title: "Architecture",
                summary: "Unable to read CPU architecture.",
                source: "uname -m"
            )
        }

        let knownArchitecture = ["arm64", "x86_64"].contains(architecture)
        return DiagnosticResult(
            category: .system,
            severity: knownArchitecture ? .pass : .warning,
            title: "Architecture",
            summary: architecture,
            details: [DiagnosticDetail(key: "Machine", value: architecture)],
            remediation: knownArchitecture ? nil : "Review tool compatibility for this architecture.",
            source: "uname -m"
        )
    }

    private func output(_ command: Command) -> String? {
        guard let result = try? runner.run(command), result.succeeded else {
            return nil
        }
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
