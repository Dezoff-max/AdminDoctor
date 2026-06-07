import AdminDoctorCore
import Foundation

let helperVersionString = "0.1.0"
let arguments = Array(CommandLine.arguments.dropFirst())
let command = arguments.first ?? "xpc"

func writeLine(_ text: String, to handle: FileHandle = .standardOutput) {
    handle.write(Data((text + "\n").utf8))
}

func printUsage() {
    writeLine("""
    AdminDoctorPrivilegedHelper \(helperVersionString)

    Commands:
      scan-cleanup          Read-only scan of all configured cleanup candidates and print JSON.
      scan-system-cleanup   Read-only scan of /Library cleanup candidates and print JSON.
      plan-system-cleanup   Dry-run privileged cleanup for --path entries and print JSON.
      quarantine-system-cleanup
                            Move allow-listed --path entries to AdminDoctor quarantine.
      --version             Print helper version.

    Privileged cleanup is allow-listed, audited, and moves items to quarantine.
    """)
}

func encodedJSON<T: Encodable>(_ value: T) throws -> Data {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(value)
}

func printJSON<T: Encodable>(_ value: T) throws {
    FileHandle.standardOutput.write(try encodedJSON(value))
    writeLine("")
}

func scan(scopes: [CleanupScope], verbose: Bool) throws -> CleanupSnapshot {
    var candidates: [CleanupCandidate] = []
    var skippedPaths: [String] = []
    let scannedAt = Date()

    for scope in scopes {
        if verbose {
            writeLine("scanning \(scope.root.path)", to: .standardError)
        }

        let snapshot = try DiskCleanupService(scopes: [scope]).scan()
        candidates.append(contentsOf: snapshot.candidates)
        skippedPaths.append(contentsOf: snapshot.skippedPaths)
    }

    return CleanupSnapshot(scannedAt: scannedAt, candidates: candidates, skippedPaths: skippedPaths)
}

final class AdminDoctorPrivilegedHelperService: NSObject, AdminDoctorPrivilegedHelperXPC {
    private let cleanupService = PrivilegedCleanupService()

    func helperVersion(withReply reply: @escaping (String) -> Void) {
        reply(helperVersionString)
    }

    func scanSystemCleanup(withReply reply: @escaping (Data?, String?) -> Void) {
        do {
            let snapshot = try scan(scopes: DiskCleanupService.systemCleanupScopes(), verbose: false)
            reply(try encodedJSON(snapshot), nil)
        } catch {
            reply(nil, error.localizedDescription)
        }
    }

    func planSystemCleanup(paths: [String], withReply reply: @escaping (Data?, String?) -> Void) {
        do {
            reply(try encodedJSON(cleanupService.plan(paths: paths)), nil)
        } catch {
            reply(nil, error.localizedDescription)
        }
    }

    func quarantineSystemCleanup(paths: [String], withReply reply: @escaping (Data?, String?) -> Void) {
        do {
            reply(try encodedJSON(cleanupService.quarantine(paths: paths)), nil)
        } catch {
            reply(nil, error.localizedDescription)
        }
    }
}

final class AdminDoctorPrivilegedHelperDelegate: NSObject, NSXPCListenerDelegate {
    private let service = AdminDoctorPrivilegedHelperService()

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: AdminDoctorPrivilegedHelperXPC.self)
        connection.exportedObject = service
        connection.resume()
        return true
    }
}

func runXPCService() -> Never {
    let delegate = AdminDoctorPrivilegedHelperDelegate()
    let listener = NSXPCListener(machServiceName: PrivilegedHelperXPCContract.machServiceName)
    listener.delegate = delegate
    listener.resume()
    RunLoop.current.run()
    fatalError("XPC listener unexpectedly returned")
}

switch command {
case "xpc", "--xpc":
    runXPCService()

case "--version", "version":
    writeLine("AdminDoctorPrivilegedHelper \(helperVersionString)")

case "scan-cleanup":
    do {
        let snapshot = try scan(
            scopes: DiskCleanupService.defaultScopes(),
            verbose: arguments.contains("--verbose")
        )
        try printJSON(snapshot)
    } catch {
        writeLine("scan-cleanup failed: \(error.localizedDescription)", to: .standardError)
        exit(1)
    }

case "scan-system-cleanup":
    do {
        let snapshot = try scan(
            scopes: DiskCleanupService.systemCleanupScopes(),
            verbose: arguments.contains("--verbose")
        )
        try printJSON(snapshot)
    } catch {
        writeLine("scan-system-cleanup failed: \(error.localizedDescription)", to: .standardError)
        exit(1)
    }

case "plan-system-cleanup":
    let paths = pathArguments(from: arguments)
    let plan = PrivilegedCleanupService().plan(paths: paths)
    do {
        try printJSON(plan)
    } catch {
        writeLine("plan-system-cleanup failed: \(error.localizedDescription)", to: .standardError)
        exit(1)
    }

case "quarantine-system-cleanup":
    let paths = pathArguments(from: arguments)
    let result = PrivilegedCleanupService().quarantine(paths: paths)
    do {
        try printJSON(result)
    } catch {
        writeLine("quarantine-system-cleanup failed: \(error.localizedDescription)", to: .standardError)
        exit(1)
    }

case "delete", "trash", "move-to-trash":
    writeLine("Use quarantine-system-cleanup --path <path>. Irreversible deletion is not implemented.", to: .standardError)
    exit(3)

case "help", "--help", "-h":
    printUsage()

default:
    writeLine("Unknown command: \(command)", to: .standardError)
    printUsage()
    exit(2)
}

func pathArguments(from arguments: [String]) -> [String] {
    var paths: [String] = []
    var iterator = arguments.dropFirst().makeIterator()
    while let argument = iterator.next() {
        if argument == "--path", let path = iterator.next() {
            paths.append(path)
        }
    }
    return paths
}
