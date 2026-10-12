import XCTest
@testable import HerdCore

private actor RemoteFixture {
    var calls: [[String]] = []
    var responses: [Data]
    init(_ values: [String]) { responses = values.map { Data($0.utf8) } }
    func run(_ args: [String]) throws -> Data {
        calls.append(args)
        guard !responses.isEmpty else { throw Failure("Unexpected remote call") }
        return responses.removeFirst()
    }
}
final class RemoteHerdrTests: XCTestCase {
    let endpoint = Device.Endpoint(kind: "ssh", target: "acc", port: 2200, sshConfig: "/tmp/ssh config", session: "agents")
    func testRunningServerIsResolvedWithoutBootstrap() async throws {
        let fixture = RemoteFixture([#"{"running":true,"socket":"/fresh/herdr.sock"}"#])
        let socket = try await RemoteHerdr.resolve(endpoint) { try await fixture.run($0) }
        let calls = await fixture.calls
        XCTAssertEqual(socket, "/fresh/herdr.sock"); XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(Array(calls[0].prefix(2)), ["-F", "/tmp/ssh config"])
        XCTAssertTrue(calls[0].contains("2200"))
    }
    func testStoppedServerBootstrapsThenWaitsForReadyAndUsesNewSocket() async throws {
        let fixture = RemoteFixture([#"{"running":false,"socket":"/old.sock"}"#, "", #"{"running":true,"socket":"/rebuilt/herdr.sock"}"#])
        let socket = try await RemoteHerdr.resolve(endpoint) { try await fixture.run($0) }
        let calls = await fixture.calls
        XCTAssertEqual(socket, "/rebuilt/herdr.sock"); XCTAssertEqual(calls.count, 3)
        XCTAssertTrue(calls[1].last!.contains("remote-client-bridge"))
        XCTAssertTrue(calls[1].last!.contains("</dev/null"))
    }
    func testMalformedStatusDoesNotStartServerOrTrustSocket() async {
        let fixture = RemoteFixture([#"{"running":false,"socket":"relative"}"#])
        do { _ = try await RemoteHerdr.resolve(endpoint) { try await fixture.run($0) }; XCTFail("Accepted invalid status") } catch {}
        let calls = await fixture.calls; XCTAssertEqual(calls.count, 1)
    }
    func testExplicitSocketNeedsNoSSHProbe() async throws {
        let fixture = RemoteFixture([])
        let socket = try await RemoteHerdr.resolve(.init(kind: "ssh", target: "host", socketPath: "/fixed.sock")) { try await fixture.run($0) }
        let calls = await fixture.calls
        XCTAssertEqual(socket, "/fixed.sock"); XCTAssertTrue(calls.isEmpty)
    }
    func testRebuiltSessionWithSameTerminalIdentityUsesFreshSocket() async throws {
        var endpoint = self.endpoint
        endpoint.socketPath = "/stale-cache.sock"
        let fixture = RemoteFixture([#"{"running":true,"socket":"/before.sock"}"#, #"{"running":true,"socket":"/rebuilt.sock"}"#])
        let first = try await RemoteHerdr.resolve(endpoint) { try await fixture.run($0) }
        let second = try await RemoteHerdr.resolve(endpoint) { try await fixture.run($0) }
        XCTAssertEqual(first, "/before.sock")
        XCTAssertEqual(second, "/rebuilt.sock")
        for mode in [TerminalAttachment.Mode.control, .observe, .takeover] {
            let command = TerminalAttachment.command(endpoint: endpoint, socket: second, terminal: "same-terminal", mode: mode)
            XCTAssertTrue(command.contains("/rebuilt.sock"))
            XCTAssertFalse(command.contains("/before.sock"))
            XCTAssertFalse(command.contains("/stale-cache.sock"))
        }
    }

}
