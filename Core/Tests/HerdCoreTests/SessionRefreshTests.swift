import XCTest
@testable import HerdCore

/// Synthetic 9-Space / 37-pane / 23-Agent session. Delayed, concurrent Unix
/// sockets exercise the actual RPC transport, scoped fallback and response order.
private final class LargeSessionWire: @unchecked Sendable {
    private let lock = NSLock()
    private var active = 0
    private(set) var maximum = 0
    private var broken = false
    let spaces: [JSON], tabs: [JSON], panes: [JSON], agents: [JSON], layouts: [JSON]
    init() {
        var spaces: [JSON] = [], tabs: [JSON] = [], panes: [JSON] = [], layouts: [JSON] = []
        for w in 1...9 {
            let count = w == 1 ? 5 : 4
            spaces.append(.object(["workspace_id": .string("w\(w)"), "label": .string("Synthetic \(w)"), "tab_count": .number(2), "pane_count": .number(Double(count))]))
            for t in 1...2 {
                let members = t == 1 ? 2 : count - 2
                let tab = "w\(w)-t\(t)"
                tabs.append(.object(["workspace_id": .string("w\(w)"), "tab_id": .string(tab), "pane_count": .number(Double(members))]))
                var rectangles: [JSON] = []
                for _ in 0..<members {
                    let n = panes.count + 1, pane = "p\(panes.count + 1)"
                    panes.append(.object(["workspace_id": .string("w\(w)"), "tab_id": .string(tab), "pane_id": .string(pane), "terminal_id": .string("term\(n)"), "agent": n <= 23 ? .string("codex") : .null]))
                    rectangles.append(.object(["pane_id": .string(pane), "rect": .object(["x": .number(0), "y": .number(0), "width": .number(40), "height": .number(20)])]))
                }
                layouts.append(.object(["workspace_id": .string("w\(w)"), "tab_id": .string(tab), "area": .object(["x": .number(0), "y": .number(0), "width": .number(120), "height": .number(40)]), "panes": .array(rectangles)]))
            }
        }
        self.spaces = spaces; self.tabs = tabs; self.panes = panes; self.layouts = layouts
        agents = panes.filter { $0["agent"].string != nil }
    }
    func breakLayout(_ value: Bool) { lock.lock(); broken = value; lock.unlock() }
    func respond(_ request: JSON) -> Data {
        lock.lock(); active += 1; maximum = max(maximum, active); let broken = broken; lock.unlock()
        defer { lock.lock(); active -= 1; lock.unlock() }
        // Different delays intentionally finish later spaces before earlier ones.
        Thread.sleep(forTimeInterval: request["params"]["workspace_id"] == .string("w1") ? 0.04 : 0.02)
        let params = request["params"], method = request["method"].string!
        let result: JSON
        switch method {
        case "session.snapshot", "agent.list": return Data(String(repeating: "x", count: 8192).utf8)
        case "ping": result = .object([:])
        case "workspace.list": result = .object(["workspaces": .array(spaces)])
        case "tab.list": result = .object(["tabs": .array(tabs.filter { $0["workspace_id"] == params["workspace_id"] })])
        case "pane.list": result = .object(["panes": .array(panes.filter { $0["workspace_id"] == params["workspace_id"] })])
        case "pane.layout":
            let pane = panes.first { $0["pane_id"] == params["pane_id"] }!
            var layout = layouts.first { $0["tab_id"] == pane["tab_id"] }!.object
            if broken && pane["workspace_id"] == .string("w3") { layout["tab_id"] = .string("stale") }
            result = .object(["layout": .object(layout)])
        case "pane.current": result = .object(["pane": panes[0]])
        case "agent.get": result = .object(["agent": agents.first { $0["pane_id"] == params["target"] }!])
        default: XCTFail("Unexpected method: \(method)"); result = .object([:])
        }
        return try! JSONEncoder().encode(JSON.object(["id": request["id"], "result": result])) + Data([10])
    }
    var snapshot: JSON { .object(["workspaces": .array(spaces), "tabs": .array(tabs), "panes": .array(panes), "agents": .array(agents), "layouts": .array(layouts)]) }
}

private final class RefreshWire: @unchecked Sendable {
    private let lock = NSLock()
    private var requests = 0
    let first = DispatchSemaphore(value: 0)
    let second = DispatchSemaphore(value: 0)
    var count: Int { lock.lock(); defer { lock.unlock() }; return requests }
    func respond(_ request: JSON) -> Data {
        lock.lock(); requests += 1; let number = requests; lock.unlock()
        if number <= 2 {
            let gate = number == 1 ? first : second
            XCTAssertEqual(gate.wait(timeout: .now() + 10), .success, "Test did not release snapshot")
        }
        let snapshot: JSON = .object(["workspaces": .array([.object(["workspace_id": .string("w"), "label": .string("Revision \(number)")])]), "tabs": .array([]), "panes": .array([])])
        return try! JSONEncoder().encode(JSON.object(["id": request["id"], "result": .object(["snapshot": snapshot])])) + Data([10])
    }
}

final class SessionRefreshTests: XCTestCase {
    func testLargeSessionReadsConcurrentlyWithinLimitAndPreservesOrder() async throws {
        let serialWire = LargeSessionWire(), parallelWire = LargeSessionWire()
        let serialServer = try TestRPCServer(requests: 200, concurrent: true, rawHandler: serialWire.respond)
        let parallelServer = try TestRPCServer(requests: 300, concurrent: true, rawHandler: parallelWire.respond)
        let start = Date()
        let serial = try await SessionReader(concurrency: 1).load(RPC(path: serialServer.path))
        let serialTime = Date().timeIntervalSince(start)
        let parallelStart = Date(), reader = SessionReader()
        var published = try await reader.load(RPC(path: parallelServer.path))
        let parallelTime = Date().timeIntervalSince(parallelStart)
        XCTAssertEqual(published, serial)
        XCTAssertEqual(published, try Session(parallelWire.snapshot))
        XCTAssertEqual(published.panes.count, 37); XCTAssertEqual(published.agents.count, 23)
        XCTAssertGreaterThan(parallelWire.maximum, 1); XCTAssertLessThanOrEqual(parallelWire.maximum, 4)
        XCTAssertEqual(serialWire.maximum, 1)
        XCTAssertLessThan(parallelTime, serialTime * 0.8, "Scoped reads still accumulate every round trip")
        print("PERF synthetic 9/37/23, 20–40ms injected latency: serial=\(serialTime)s parallel=\(parallelTime)s maxSockets=\(parallelWire.maximum)")
        let previous = published
        parallelWire.breakLayout(true)
        do { published = try await reader.load(RPC(path: parallelServer.path)); XCTFail("Partial parallel snapshot published") }
        catch { XCTAssertTrue(error.localizedDescription.contains("layout changed")) }
        XCTAssertEqual(published, previous)
        parallelWire.breakLayout(false)
        let recovered = try await reader.load(RPC(path: parallelServer.path))
        XCTAssertEqual(recovered, previous)
    }

    func testRefreshBurstKeepsCompletedResultAndReadsAgainAfterMutation() async throws {
        let wire = RefreshWire(), reader = SessionReader()
        let server = try TestRPCServer(requests: 50, rawHandler: wire.respond), rpc = RPC(path: server.path)
        defer { wire.first.signal(); wire.second.signal() }
        let first = Task { try await reader.loadSnapshot(rpc) }
        try await waitForRequests(1, wire: wire)
        // These callers arrived after the first read started (including a
        // completed mutation), so they require exactly one subsequent read.
        let queued = (0..<12).map { _ in Task { try await reader.loadSnapshot(rpc) } }
        try await Task.sleep(for: .milliseconds(150))
        queued[0].cancel()
        wire.first.signal()
        let completed = try await first.value
        try await waitForRequests(2, wire: wire)
        XCTAssertEqual(completed.revision, 1)
        XCTAssertEqual(completed.session.spaces.first?.label, "Revision 1")
        // A background refresh is pending; the completed result is still usable
        // immediately, rather than being discarded by a latest-request token.
        XCTAssertEqual(wire.count, 2)
        wire.second.signal()
        do { _ = try await queued[0].value; XCTFail("Cancelled waiter succeeded") } catch is CancellationError {} catch { XCTFail("Unexpected cancellation: \(error)") }
        for task in queued.dropFirst() {
            let updated = try await task.value
            XCTAssertEqual(updated.revision, 2)
            XCTAssertEqual(updated.session.spaces.first?.label, "Revision 2")
        }
        XCTAssertEqual(wire.count, 2, "Burst queued redundant full refreshes")
        let later = try await reader.loadSnapshot(rpc)
        XCTAssertEqual(later.revision, 3, "A later mutation reused an already-started read")
    }

    private func waitForRequests(_ count: Int, wire: RefreshWire) async throws {
        let deadline = Date().addingTimeInterval(3)
        while wire.count < count, Date() < deadline { try await Task.sleep(for: .milliseconds(5)) }
        XCTAssertEqual(wire.count, count)
    }
}
