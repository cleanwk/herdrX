import XCTest
import Darwin
@testable import HerdCore

/// A real Unix socket exercises framing, snapshot validation and event recovery.
private final class Server {
    let path = "/tmp/hxt-" + UUID().uuidString.prefix(10) + ".sock"
    let fd: Int32
    init(requests: Int, handler: @escaping @Sendable (JSON) -> [JSON]) throws {
        fd = socket(AF_UNIX, SOCK_STREAM, 0)
        var address = sockaddr_un(); address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: bytes) }
        let bound = withUnsafePointer(to: &address) { p in p.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) } }
        guard bound == 0, listen(fd, 8) == 0 else { close(fd); throw Failure("Test socket failed") }
        let fd = self.fd
        DispatchQueue.global().async {
            for _ in 0..<requests {
                let peer = accept(fd, nil, nil); guard peer >= 0 else { break }
                var noPipe: Int32 = 1; setsockopt(peer, SOL_SOCKET, SO_NOSIGPIPE, &noPipe, 4)
                var data = Data(), bytes = [UInt8](repeating: 0, count: 4096)
                while !data.contains(10) { let count = read(peer, &bytes, bytes.count); if count <= 0 { break }; data.append(contentsOf: bytes.prefix(count)) }
                if let end = data.firstIndex(of: 10), let request = try? JSONDecoder().decode(JSON.self, from: data[..<end]) {
                    for response in handler(request) {
                        guard let encoded = try? JSONEncoder().encode(response) else { continue }
                        let output = encoded + Data([10])
                        output.withUnsafeBytes { raw in
                            var offset = 0
                            while offset < raw.count { let count = write(peer, raw.baseAddress!.advanced(by: offset), min(17, raw.count - offset)); if count <= 0 { break }; offset += count }
                        }
                    }
                }
                close(peer)
            }
        }
    }
    deinit { shutdown(fd, SHUT_RDWR); close(fd); try? FileManager.default.removeItem(atPath: path) }
}

final class TransportTests: XCTestCase {
    func testRPCReassemblesLargeFragmentedResponse() async throws {
        let text = String(repeating: "文", count: 30000)
        let server = try Server(requests: 1) { request in [.object(["id": request["id"], "result": .object(["text": .string(text)])])] }
        let result = try await RPC(path: server.path).call("test")
        XCTAssertEqual(result["text"].string, text)
    }
    func testResponseIdentityCannotCrossRequests() async throws {
        let server = try Server(requests: 1) { _ in [.object(["id": .string("wrong"), "result": .object([:])])] }
        do { _ = try await RPC(path: server.path).call("test"); XCTFail("Mismatched response accepted") } catch { XCTAssertTrue(error.localizedDescription.contains("Mismatched")) }
    }
    func testUnsupportedSnapshotIsNotHiddenByLegacyFallback() async throws {
        let server = try Server(requests: 1) { request in
            [.object(["id": request["id"], "error": .object(["message": .string("snapshot unavailable")])])]
        }
        do { _ = try await Session.load(RPC(path: server.path)); XCTFail("Unsupported snapshot accepted") }
        catch { XCTAssertTrue(error.localizedDescription.contains("snapshot unavailable")) }
    }
    func testArgumentsPreserveBoundariesWithoutShellEvaluation() throws {
        XCTAssertEqual(try Arguments.parse("--model 'my model' \"\" path\\ with\\ spaces $(whoami)"), ["--model", "my model", "", "path with spaces", "$(whoami)"])
        XCTAssertThrowsError(try Arguments.parse("--model 'unfinished"))
        XCTAssertThrowsError(try Arguments.parse("unfinished\\"))
    }
    func testEventHistoryLossRequiresARefreshAndNewSubscription() async throws {
        let server = try Server(requests: 1) { request in [
            .object(["id": request["id"], "result": .object(["type": .string("subscription_started")])]),
            .object(["id": request["id"], "error": .object(["code": .string("events_lost"), "message": .string("Event history lost")])])
        ] }
        let feed = EventFeed(path: server.path, panes: []); defer { feed.stop() }
        do { for try await _ in feed.signals {} ; XCTFail("History loss silently accepted") }
        catch { XCTAssertTrue(error.localizedDescription.contains("history lost")) }
    }
}
