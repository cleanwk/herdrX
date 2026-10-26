import XCTest
@testable import HerdCore

final class TerminalScrollTargetTests: XCTestCase {
    private func server(foreground: Bool = false, valid: Bool = true, terminal: String = "term", positionDelay: Double = 0.25) throws -> TestRPCServer {
        try TestRPCServer(requests: 2, concurrent: true, fragmentSize: 65536, rawHandler: { request in
            let method = request["method"].string
            TestRPCServer.delay(method == "pane.get" ? positionDelay : 0.25)
            let result: JSON
            if method == "pane.process_info" {
                let pid = foreground ? 20 : 10
                result = .object(["process_info": .object([
                    "pane_id": .string(valid ? "p" : "stale"), "shell_pid": .number(10), "foreground_process_group_id": .number(Double(pid)),
                    "foreground_processes": .array([.object(["pid": .number(Double(pid)), "name": .string(foreground ? "vim" : "zsh")])])
                ])])
            } else {
                XCTAssertEqual(method, "pane.get", "Preflight must never mutate the session")
                result = .object(["pane": .object(["pane_id": .string("p"), "terminal_id": .string(terminal),
                    "scroll": .object(["offset_from_bottom": .number(5), "max_offset_from_bottom": .number(500)])])])
            }
            return try! JSONEncoder().encode(JSON.object(["id": request["id"], "result": result])) + Data([10])
        })
    }
    func testShellPreflightOverlapsIndependentReads() async throws {
        let server = try server()
        let start = ContinuousClock.now
        let result = try await TerminalScrollTarget.read(RPC(path: server.path), pane: "p", terminal: "term")
        let elapsed = start.duration(to: .now)
        XCTAssertEqual(result, .history(offset: 5, maximum: 500))
        XCTAssertLessThan(elapsed, .milliseconds(450), "Two 250ms reads should overlap")
        print("SCROLL PREFLIGHT: two 250ms reads completed in \(elapsed)")
        withExtendedLifetime(server) {}
    }
    func testForegroundDoesNotWaitForSlowHistoryRead() async throws {
        let server = try server(foreground: true, positionDelay: 1)
        let start = ContinuousClock.now
        let result = try await TerminalScrollTarget.read(RPC(path: server.path), pane: "p", terminal: "term")
        XCTAssertEqual(result, .foreground)
        XCTAssertLessThan(start.duration(to: .now), .milliseconds(700))
        withExtendedLifetime(server) {}
    }
    func testMissingProcessIdentityAndChangedTerminalRejectScrolling() async throws {
        for (valid, terminal) in [(false, "term"), (true, "replaced")] {
            let server = try server(valid: valid, terminal: terminal)
            do {
                _ = try await TerminalScrollTarget.read(RPC(path: server.path), pane: "p", terminal: "term")
                XCTFail("Unverified scroll target accepted")
            } catch { XCTAssertTrue(error is Failure) }
            withExtendedLifetime(server) {}
        }
    }
    func testCancelledPreflightCannotReturnInputRoute() async throws {
        let server = try server()
        let client = RPC(path: server.path)
        let task = Task { try await TerminalScrollTarget.read(client, pane: "p", terminal: "term") }
        try await Task.sleep(for: .milliseconds(30))
        task.cancel()
        do { _ = try await task.value; XCTFail("Canceled scroll returned a route") }
        catch { XCTAssertTrue(error is CancellationError) }
        withExtendedLifetime(server) {}
    }
}
