import AdminDocCore
import Foundation

let helperVersion = "0.1.0"
let arguments = Array(CommandLine.arguments.dropFirst())
let command = arguments.first ?? "help"

func writeLine(_ text: String, to handle: FileHandle = .standardOutput) {
    handle.write(Data((text + "\n").utf8))
}

func printUsage() {
    writeLine("""
    AdminDocPrivilegedHelper \(helperVersion)

    Commands:
      scan-cleanup          Read-only scan of all configured cleanup candidates and print JSON.
      scan-system-cleanup   Read-only scan of /Library cleanup candidates and print JSON.
      --version             Print helper version.

    System cleanup deletion is intentionally not implemented in this scaffold.
    The production helper must be signed, installed through SMAppService, and
    expose a narrow audited XPC protocol before deleting privileged paths.
    """)
}

func printJSON(_ snapshot: CleanupSnapshot) throws {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(snapshot)
    FileHandle.standardOutput.write(data)
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

switch command {
case "--version", "version":
    writeLine("AdminDocPrivilegedHelper \(helperVersion)")

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

case "delete", "trash", "move-to-trash":
    writeLine("Deletion is not implemented in this privileged-helper scaffold.", to: .standardError)
    exit(3)

case "help", "--help", "-h":
    printUsage()

default:
    writeLine("Unknown command: \(command)", to: .standardError)
    printUsage()
    exit(2)
}
