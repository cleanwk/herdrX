import XCTest
@testable import HerdCore

final class CommandProcessTests: XCTestCase {
    func testCancellingRunningDiscoveryCommandStopsItWithoutAResult() async throws {
        let marker = FileManager.default.temporaryDirectory.appendingPathComponent("herdrx-cancel-test-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: marker) }
        // The helper replaces itself with sleep; cancellation only targets this test process.
        let task = Task {
            try await CommandProcess.run("/bin/sh", ["-c", "printf started > \"$1\"; exec /bin/sleep 30", "herdrx-cancel-test", marker.path], input: Data())
        }
        defer { task.cancel() }
        let deadline = Date().addingTimeInterval(3)
        while !FileManager.default.fileExists(atPath: marker.path), Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        let started = FileManager.default.fileExists(atPath: marker.path)
        task.cancel()
        do { _ = try await task.value; XCTFail("A cancelled discovery command returned a result") }
        catch is CancellationError {}
        catch { XCTFail("Cancellation returned an unrelated error: \(error)") }
        XCTAssertTrue(started, "The helper never started; this must exercise in-flight cancellation")
    }
}
