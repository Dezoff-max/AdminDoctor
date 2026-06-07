import XCTest
@testable import AdminDoctorCore

final class SystemInfoParserTests: XCTestCase {
    func testParsesLoadAverage() {
        let load = SystemInfoParser.parseLoadAverage("{ 2.31 3.69 3.79 }")

        XCTAssertEqual(load?.oneMinute, 2.31)
        XCTAssertEqual(load?.fiveMinutes, 3.69)
        XCTAssertEqual(load?.fifteenMinutes, 3.79)
    }

    func testParsesMemorySnapshot() {
        let vmStat = """
        Mach Virtual Memory Statistics: (page size of 16384 bytes)
        Pages free:                                    100.
        Pages active:                                  300.
        Pages inactive:                                200.
        Pages speculative:                              50.
        Pages wired down:                              150.
        Pages purgeable:                                25.
        Pages occupied by compressor:                   75.
        """

        let snapshot = SystemInfoParser.parseMemorySnapshot(
            vmStatOutput: vmStat,
            totalMemoryBytes: 1_024 * 16_384
        )

        XCTAssertEqual(snapshot?.pageSize, 16_384)
        XCTAssertEqual(snapshot?.availableBytes, 375 * 16_384)
        XCTAssertEqual(snapshot?.compressorPages, 75)
    }

    func testParsesTopProcesses() {
        let output = """
          PID  %CPU %MEM    RSS COMM
          396  39.7  0.8 141440 /System/Library/WindowServer
        51238  17.2  0.9 151488 /Applications/Codex.app/Contents/MacOS/Codex
        """

        let processes = SystemInfoParser.parseTopProcesses(output)

        XCTAssertEqual(processes.count, 2)
        XCTAssertEqual(processes[0].pid, 396)
        XCTAssertEqual(processes[0].cpuPercent, 39.7)
        XCTAssertEqual(processes[0].residentBytes, 141_440 * 1_024)
        XCTAssertEqual(processes[1].displayName, "Codex")
    }
}
