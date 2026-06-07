import Foundation

public enum SystemInfoParser {
    public struct LoadAverage: Equatable, Sendable {
        public var oneMinute: Double
        public var fiveMinutes: Double
        public var fifteenMinutes: Double
    }

    public struct MemorySnapshot: Equatable, Sendable {
        public var totalBytes: Int64
        public var pageSize: Int64
        public var freePages: Int64
        public var activePages: Int64
        public var inactivePages: Int64
        public var speculativePages: Int64
        public var wiredPages: Int64
        public var purgeablePages: Int64
        public var compressorPages: Int64

        public var availableBytes: Int64 {
            max(0, freePages + inactivePages + speculativePages + purgeablePages) * pageSize
        }

        public var usedBytes: Int64 {
            max(0, totalBytes - availableBytes)
        }

        public var usedPercent: Double {
            guard totalBytes > 0 else {
                return 0
            }
            return Double(usedBytes) / Double(totalBytes)
        }
    }

    public struct ProcessSnapshot: Equatable, Sendable {
        public var pid: Int
        public var cpuPercent: Double
        public var memoryPercent: Double
        public var residentBytes: Int64
        public var command: String

        public var displayName: String {
            let url = URL(fileURLWithPath: command)
            let lastComponent = url.lastPathComponent
            return lastComponent.isEmpty ? command : lastComponent
        }
    }

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

    public static func parseLoadAverage(_ output: String) -> LoadAverage? {
        let values = ParserHelpers.captures(in: output, pattern: #"([0-9]+(?:\.[0-9]+)?)"#)
            .compactMap(Double.init)
        guard values.count >= 3 else {
            return nil
        }
        return LoadAverage(oneMinute: values[0], fiveMinutes: values[1], fifteenMinutes: values[2])
    }

    public static func parseMemorySnapshot(vmStatOutput: String, totalMemoryBytes: Int64) -> MemorySnapshot? {
        guard
            let pageSizeText = ParserHelpers.firstCapture(in: vmStatOutput, pattern: #"page size of\s+(\d+)\s+bytes"#),
            let pageSize = Int64(pageSizeText)
        else {
            return nil
        }

        return MemorySnapshot(
            totalBytes: totalMemoryBytes,
            pageSize: pageSize,
            freePages: pageCount("Pages free", in: vmStatOutput),
            activePages: pageCount("Pages active", in: vmStatOutput),
            inactivePages: pageCount("Pages inactive", in: vmStatOutput),
            speculativePages: pageCount("Pages speculative", in: vmStatOutput),
            wiredPages: pageCount("Pages wired down", in: vmStatOutput),
            purgeablePages: pageCount("Pages purgeable", in: vmStatOutput),
            compressorPages: pageCount("Pages occupied by compressor", in: vmStatOutput)
        )
    }

    public static func parseTopProcesses(_ output: String, limit: Int = 5) -> [ProcessSnapshot] {
        ParserHelpers.trimmedNonEmptyLines(output)
            .compactMap(parseProcessLine)
            .prefix(limit)
            .map { $0 }
    }

    private static func parseProcessLine(_ line: String) -> ProcessSnapshot? {
        guard !line.localizedCaseInsensitiveContains("PID") else {
            return nil
        }

        guard let regex = try? NSRegularExpression(
            pattern: #"^\s*(\d+)\s+([0-9]+(?:\.[0-9]+)?)\s+([0-9]+(?:\.[0-9]+)?)\s+(\d+)\s+(.+)$"#
        ) else {
            return nil
        }

        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard
            let match = regex.firstMatch(in: line, options: [], range: range),
            let pidRange = Range(match.range(at: 1), in: line),
            let cpuRange = Range(match.range(at: 2), in: line),
            let memoryRange = Range(match.range(at: 3), in: line),
            let rssRange = Range(match.range(at: 4), in: line),
            let commandRange = Range(match.range(at: 5), in: line),
            let pid = Int(line[pidRange]),
            let cpu = Double(line[cpuRange]),
            let memory = Double(line[memoryRange]),
            let rssKilobytes = Int64(line[rssRange])
        else {
            return nil
        }

        return ProcessSnapshot(
            pid: pid,
            cpuPercent: cpu,
            memoryPercent: memory,
            residentBytes: rssKilobytes * 1_024,
            command: String(line[commandRange])
        )
    }

    private static func pageCount(_ label: String, in output: String) -> Int64 {
        let escaped = NSRegularExpression.escapedPattern(for: label)
        guard
            let value = ParserHelpers.firstCapture(in: output, pattern: #"\#(escaped):\s+(\d+)\."#),
            let count = Int64(value)
        else {
            return 0
        }
        return count
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
            kernelVersionResult(),
            uptimeResult(),
            hardwareModelResult(),
            architectureResult(),
            cpuLoadResult(),
            memoryResult(),
            topProcessesResult()
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

    private func kernelVersionResult() -> DiagnosticResult {
        guard let kernel = output(Command("/usr/sbin/sysctl", arguments: ["-n", "kern.version"])) else {
            return DiagnosticResult(
                category: .system,
                severity: .info,
                title: "Kernel version",
                summary: "Unable to read kernel version.",
                source: "sysctl kern.version"
            )
        }

        return DiagnosticResult(
            category: .system,
            severity: .info,
            title: "Kernel version",
            summary: kernel.components(separatedBy: ";").first ?? kernel,
            details: [DiagnosticDetail(key: "Kernel", value: kernel)],
            source: "sysctl kern.version"
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

    private func cpuLoadResult() -> DiagnosticResult {
        guard
            let loadOutput = output(Command("/usr/sbin/sysctl", arguments: ["-n", "vm.loadavg"])),
            let load = SystemInfoParser.parseLoadAverage(loadOutput)
        else {
            return DiagnosticResult(
                category: .system,
                severity: .info,
                title: "CPU load",
                summary: "Unable to read CPU load average.",
                source: "sysctl vm.loadavg"
            )
        }

        let logicalCPU = output(Command("/usr/sbin/sysctl", arguments: ["-n", "hw.logicalcpu"]))
            .flatMap(Int.init)
        let severity: DiagnosticSeverity
        if let logicalCPU, load.fiveMinutes > Double(logicalCPU) * 1.25 {
            severity = .warning
        } else {
            severity = .pass
        }

        var details = [
            DiagnosticDetail(key: "1 min", value: String(format: "%.2f", load.oneMinute)),
            DiagnosticDetail(key: "5 min", value: String(format: "%.2f", load.fiveMinutes)),
            DiagnosticDetail(key: "15 min", value: String(format: "%.2f", load.fifteenMinutes))
        ]
        if let logicalCPU {
            details.append(DiagnosticDetail(key: "Logical CPUs", value: "\(logicalCPU)"))
        }

        return DiagnosticResult(
            category: .system,
            severity: severity,
            title: "CPU load",
            summary: "5-minute load average \(String(format: "%.2f", load.fiveMinutes))",
            details: details,
            remediation: severity == .warning ? "Review CPU-heavy processes and recent workload changes." : nil,
            source: "sysctl vm.loadavg"
        )
    }

    private func memoryResult() -> DiagnosticResult {
        guard
            let memoryOutput = output(Command("/usr/sbin/sysctl", arguments: ["-n", "hw.memsize"])),
            let totalMemory = Int64(memoryOutput),
            let vmStat = output(Command("/usr/bin/vm_stat")),
            let snapshot = SystemInfoParser.parseMemorySnapshot(vmStatOutput: vmStat, totalMemoryBytes: totalMemory)
        else {
            return DiagnosticResult(
                category: .system,
                severity: .info,
                title: "Memory",
                summary: "Unable to read memory pressure snapshot.",
                source: "sysctl hw.memsize; vm_stat"
            )
        }

        let usedPercent = snapshot.usedPercent
        let severity: DiagnosticSeverity
        if usedPercent >= 0.95 {
            severity = .fail
        } else if usedPercent >= 0.85 {
            severity = .warning
        } else {
            severity = .pass
        }

        return DiagnosticResult(
            category: .system,
            severity: severity,
            title: "Memory",
            summary: "\(ByteCountFormatter.adminDocString(totalMemory)) RAM, estimated \(Int(usedPercent * 100))% used",
            details: [
                DiagnosticDetail(key: "Total", value: ByteCountFormatter.adminDocString(snapshot.totalBytes)),
                DiagnosticDetail(key: "Estimated used", value: ByteCountFormatter.adminDocString(snapshot.usedBytes)),
                DiagnosticDetail(key: "Estimated available", value: ByteCountFormatter.adminDocString(snapshot.availableBytes)),
                DiagnosticDetail(key: "Compressor", value: ByteCountFormatter.adminDocString(snapshot.compressorPages * snapshot.pageSize)),
                DiagnosticDetail(key: "Page size", value: ByteCountFormatter.adminDocString(snapshot.pageSize))
            ],
            remediation: severity == .pass ? nil : "Review memory-heavy processes, browser tabs, virtualization, and background agents.",
            source: "sysctl hw.memsize; vm_stat"
        )
    }

    private func topProcessesResult() -> DiagnosticResult {
        guard let output = output(Command("/bin/ps", arguments: ["-axo", "pid,pcpu,pmem,rss,comm", "-r"], timeout: 5)) else {
            return DiagnosticResult(
                category: .system,
                severity: .info,
                title: "Top processes",
                summary: "Unable to read process snapshot.",
                source: "ps -axo pid,pcpu,pmem,rss,comm -r"
            )
        }

        let processes = SystemInfoParser.parseTopProcesses(output, limit: 5)
        return DiagnosticResult(
            category: .system,
            severity: .info,
            title: "Top processes",
            summary: processes.isEmpty ? "No process rows parsed." : "\(processes.count) highest CPU process(es) captured.",
            details: processes.enumerated().map { index, process in
                DiagnosticDetail(
                    key: "\(index + 1). \(process.displayName)",
                    value: "PID \(process.pid), CPU \(String(format: "%.1f", process.cpuPercent))%, RAM \(String(format: "%.1f", process.memoryPercent))%, RSS \(ByteCountFormatter.adminDocString(process.residentBytes))"
                )
            },
            source: "ps -axo pid,pcpu,pmem,rss,comm -r"
        )
    }

    private func output(_ command: Command) -> String? {
        guard let result = try? runner.run(command), result.succeeded else {
            return nil
        }
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
