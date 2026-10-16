import XCTest
import Darwin
@testable import HerdCore

final class TransportTests: XCTestCase {
    func testRPCReassemblesLargeFragmentedResponse() async throws {
        let text = String(repeating: "文", count: 30000)
        let server = try TestRPCServer(requests: 1) { request in [.object(["id": request["id"], "result": .object(["text": .string(text)])])] }
        let result = try await RPC(path: server.path).call("test")
        XCTAssertEqual(result["text"].string, text)
    }
    func testResponseIdentityCannotCrossRequests() async throws {
        let server = try TestRPCServer(requests: 1) { _ in [.object(["id": .string("wrong"), "result": .object([:])])] }
        do { _ = try await RPC(path: server.path).call("test"); XCTFail("Mismatched response accepted") } catch { XCTAssertTrue(error.localizedDescription.contains("Mismatched")) }
    }
    func testUnsupportedSnapshotIsNotHiddenByLegacyFallback() async throws {
        let server = try TestRPCServer(requests: 1) { request in
            [.object(["id": request["id"], "error": .object(["message": .string("snapshot unavailable")])])]
        }
        do { _ = try await Session.load(RPC(path: server.path)); XCTFail("Unsupported snapshot accepted") }
        catch { XCTAssertTrue(error.localizedDescription.contains("snapshot unavailable")) }
    }
    func testEventHistoryLossRequiresARefreshAndNewSubscription() async throws {
        let server = try TestRPCServer(requests: 1) { request in [
            .object(["id": request["id"], "result": .object(["type": .string("subscription_started")])]),
            .object(["id": request["id"], "error": .object(["code": .string("events_lost"), "message": .string("Event history lost")])])
        ] }
        let feed = EventFeed(path: server.path, panes: []); defer { feed.stop() }
        do { for try await _ in feed.signals {} ; XCTFail("History loss silently accepted") }
        catch { XCTAssertTrue(error.localizedDescription.contains("history lost")) }
    }
}
