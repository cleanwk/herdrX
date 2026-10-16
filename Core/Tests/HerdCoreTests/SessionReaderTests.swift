import XCTest
@testable import HerdCore

/// Script the wire, not RPC.call: EOF and valid NDJSON must take different paths.
private final class ReadScript: @unchecked Sendable {
    struct Step: Sendable {
        let method: String
        var params: [String: JSON] = [:]
        var result: JSON = .object([:])
        var raw: Data?
        var error: String?
    }
    private let lock = NSLock()
    private var remaining: [Step]
    private var seen: [String] = []
    init(_ steps: [Step]) { remaining = steps }
    func respond(_ request: JSON) -> Data {
        lock.lock(); defer { lock.unlock() }
        seen.append(request["method"].string ?? "?")
        guard !remaining.isEmpty else {
            XCTFail("Unexpected request: \(request)")
            return Data("{}\n".utf8)
        }
        let step = remaining.removeFirst()
        XCTAssertEqual(request["method"].string, step.method)
        XCTAssertEqual(request["params"].object, step.params)
        if let raw = step.raw { return raw }
        var response = ["id": request["id"], "result": step.result]
        if let error = step.error { response = ["id": request["id"], "error": .object(["message": .string(error)])] }
        return try! JSONEncoder().encode(JSON.object(response)) + Data([10])
    }
    var methods: [String] { lock.lock(); defer { lock.unlock() }; return seen }
    var isComplete: Bool { lock.lock(); defer { lock.unlock() }; return remaining.isEmpty }
    func server() throws -> TestRPCServer { try TestRPCServer(requests: 100, rawHandler: { self.respond($0) }) }
}

private struct ReadFixture {
    let spaces: [JSON]
    let tabs: [JSON]
    let panes: [JSON]
    let agents: [JSON]
    let layouts: [JSON]
    init() {
        let spaces: [JSON] = (1...2).map { i in .object([
            "workspace_id": .string("w\(i)"), "label": .string("Space \(i)"),
            "pane_count": .number(i == 1 ? 2 : 1), "tab_count": .number(1)
        ]) }
        let tabs: [JSON] = (1...2).map { i in .object([
            "workspace_id": .string("w\(i)"), "tab_id": .string("t\(i)"),
            "pane_count": .number(i == 1 ? 2 : 1)
        ]) }
        let panes: [JSON] = (1...3).map { i in .object([
            "workspace_id": .string(i < 3 ? "w1" : "w2"), "tab_id": .string(i < 3 ? "t1" : "t2"),
            "pane_id": .string("p\(i)"), "terminal_id": .string("term\(i)"),
            "agent": i == 2 ? .null : .string("codex"), "agent_status": .string("working")
        ]) }
        let agents: [JSON] = panes.filter { $0["agent"] != .null }.map { pane in
            var value = pane.object
            value["title"] = .string("Synthetic agent task")
            value["tokens"] = .object(["fixture": .string("synthetic")])
            return .object(value)
        }
        let layouts: [JSON] = tabs.map { tab in .object([
            "workspace_id": tab["workspace_id"], "tab_id": tab["tab_id"],
            "area": .object(["x": .number(20), "y": .number(1), "width": .number(120), "height": .number(40)]),
            "panes": .array(panes.filter { $0["tab_id"] == tab["tab_id"] }.map { pane in .object([
                "pane_id": pane["pane_id"], "rect": .object(["x": .number(20), "y": .number(1), "width": .number(60), "height": .number(40)])
            ]) })
        ]) }
        self.spaces = spaces; self.tabs = tabs; self.panes = panes
        self.agents = agents; self.layouts = layouts
    }
    var snapshot: JSON { .object([
        "workspaces": .array(spaces), "tabs": .array(tabs), "panes": .array(panes),
        "agents": .array(agents), "layouts": .array(layouts)
    ]) }
    static func truncated(_ method: String) -> ReadScript.Step {
        // The reported Herdr 0.9.3 failure: exactly 8192 bytes and no newline.
        .init(method: method, raw: Data(("{\"result\":\"" + String(repeating: "x", count: 9000)).utf8.prefix(8192)))
    }
    func scoped(agentReads: Bool = false, truncateAgents: Bool = false) -> [ReadScript.Step] {
        var steps: [ReadScript.Step] = [
            .init(method: "ping", result: .object(["version": .string("0.9.3"), "protocol": .number(1)])),
            .init(method: "workspace.list", result: .object(["workspaces": .array(spaces)]))
        ]
        for space in spaces {
            let localTabs = tabs.filter { $0["workspace_id"] == space["workspace_id"] }
            let localPanes = panes.filter { $0["workspace_id"] == space["workspace_id"] }
            let params = ["workspace_id": space["workspace_id"]]
            steps.append(.init(method: "tab.list", params: params, result: .object(["tabs": .array(localTabs)])))
            steps.append(.init(method: "pane.list", params: params, result: .object(["panes": .array(localPanes)])))
            steps.append(.init(method: "pane.layout", params: ["pane_id": localPanes[0]["pane_id"]], result: .object(["layout": layouts.first { $0["workspace_id"] == space["workspace_id"] }!])))
        }
        steps.append(.init(method: "pane.current", result: .object(["pane": panes[0]])))
        if truncateAgents { steps.append(Self.truncated("agent.list")) }
        if agentReads {
            for agent in agents { steps.append(.init(method: "agent.get", params: ["target": agent["pane_id"]], result: .object(["agent": agent]))) }
        } else { steps.append(.init(method: "agent.list", result: .object(["agents": .array(agents)]))) }
        steps.append(.init(method: "workspace.list", result: .object(["workspaces": .array(spaces)])))
        return steps
    }
}

final class SessionReaderTests: XCTestCase {
    func testConcurrentRefreshesShareTheFirstTruncationProbe() async throws {
        let fixture = ReadFixture(), reader = SessionReader()
        let script = ReadScript([ReadFixture.truncated("session.snapshot")] + fixture.scoped() + fixture.scoped())
        let server = try script.server(), rpc = RPC(path: server.path)
        async let first = reader.load(rpc)
        async let second = reader.load(rpc)
        let values = try await [first, second]
        XCTAssertEqual(values, [try Session(fixture.snapshot), try Session(fixture.snapshot)])
        XCTAssertEqual(script.methods.filter { $0 == "session.snapshot" }.count, 1)
        XCTAssertTrue(script.isComplete)
    }

    func testCompleteSnapshotKeepsFastPath() async throws {
        let fixture = ReadFixture()
        let script = ReadScript(Array(repeating: .init(method: "session.snapshot", result: .object(["snapshot": fixture.snapshot])), count: 2))
        let server = try script.server(), reader = SessionReader()
        for _ in 0..<2 {
            let value = try await reader.load(RPC(path: server.path))
            XCTAssertEqual(value, try Session(fixture.snapshot))
        }
        XCTAssertTrue(script.isComplete)
    }

    func testTruncatedSnapshotAndAgentsUseStickyScopedReadsAcrossTransportChanges() async throws {
        let fixture = ReadFixture(), reader = SessionReader()
        let first = ReadScript([ReadFixture.truncated("session.snapshot")] + fixture.scoped(agentReads: true, truncateAgents: true))
        let firstServer = try first.server()
        let value = try await reader.load(RPC(path: firstServer.path))
        XCTAssertEqual(value, try Session(fixture.snapshot))
        XCTAssertEqual(value.layouts, .array(fixture.layouts))
        XCTAssertEqual(value.agents.count, 2)
        XCTAssertTrue(first.isComplete)
        let next = ReadScript(fixture.scoped(agentReads: true)), nextServer = try next.server()
        let refreshed = try await reader.load(RPC(path: nextServer.path))
        XCTAssertEqual(value, refreshed)
        XCTAssertFalse(next.methods.contains("session.snapshot"))
        XCTAssertFalse(next.methods.contains("agent.list"))
        XCTAssertTrue(next.isComplete)
        // An independent endpoint starts with its own aggregate probe.
        let independent = ReadScript([.init(method: "session.snapshot", result: .object(["snapshot": fixture.snapshot]))])
        let independentServer = try independent.server()
        _ = try await SessionReader().load(RPC(path: independentServer.path))
        XCTAssertTrue(independent.isComplete)
    }

    func testOnlyEOFWithoutNDJSONTriggersFallback() async throws {
        for step in [
            ReadScript.Step(method: "session.snapshot", error: "Truncated RPC response"),
            .init(method: "session.snapshot", raw: Data("{broken}\n".utf8)),
            .init(method: "session.snapshot", raw: Data("{\"id\":\"wrong\",\"result\":{}}\n".utf8)),
            .init(method: "session.snapshot", result: .object(["snapshot": .object([:])]))
        ] {
            let script = ReadScript([step]), server = try script.server()
            do { _ = try await SessionReader().load(RPC(path: server.path)); XCTFail("Invalid response accepted") }
            catch { XCTAssertFalse(error is RPC.TruncatedResponse) }
            XCTAssertEqual(script.methods, ["session.snapshot"])
        }
        // Even syntactically complete JSON is truncated without its NDJSON LF.
        let fixture = ReadFixture()
        let script = ReadScript([.init(method: "session.snapshot", raw: Data("{}".utf8))] + fixture.scoped())
        let server = try script.server()
        let value = try await Session.load(RPC(path: server.path))
        XCTAssertEqual(value, try Session(fixture.snapshot))
        XCTAssertTrue(script.isComplete)
    }

    func testWorkspaceIDsAndCountsMustStayStableAndFailuresKeepPreviousCache() async throws {
        let fixture = ReadFixture()
        for field in ["workspace_id", "pane_count", "tab_count"] {
            var changed = fixture.spaces[0].object
            changed[field] = field == "workspace_id" ? .string("replacement") : .number(99)
            var failing = fixture.scoped()
            failing[failing.count - 1].result = .object(["workspaces": .array([.object(changed), fixture.spaces[1]])])
            let script = ReadScript([ReadFixture.truncated("session.snapshot")] + fixture.scoped() + failing + fixture.scoped())
            let server = try script.server(), reader = SessionReader()
            var published = try await reader.load(RPC(path: server.path))
            let previous = published
            do { published = try await reader.load(RPC(path: server.path)); XCTFail("Mixed topology published") }
            catch { XCTAssertTrue(error.localizedDescription.contains("topology changed")) }
            XCTAssertEqual(published, previous)
            let recovered = try await reader.load(RPC(path: server.path))
            XCTAssertEqual(recovered, previous)
            XCTAssertEqual(script.methods.filter { $0 == "session.snapshot" }.count, 1)
            XCTAssertTrue(script.isComplete)
        }
    }

    func testIntermediateFailuresDoNotPublishOrForgetScopedMode() async throws {
        let fixture = ReadFixture()
        for method in ["ping", "tab.list", "pane.list", "pane.layout", "pane.current", "agent.list", "agent.get"] {
            let agentReads = method == "agent.get"
            var failing = fixture.scoped(agentReads: agentReads, truncateAgents: agentReads)
            let index = failing.firstIndex { $0.method == method }!
            failing = Array(failing.prefix(index + 1))
            failing[index].error = "Scoped read failed"
            let script = ReadScript([ReadFixture.truncated("session.snapshot")] + failing + fixture.scoped(agentReads: agentReads))
            let server = try script.server(), reader = SessionReader()
            do { _ = try await reader.load(RPC(path: server.path)); XCTFail("Partial session published") }
            catch { XCTAssertEqual(error.localizedDescription, "Scoped read failed") }
            let recovered = try await reader.load(RPC(path: server.path))
            XCTAssertEqual(recovered, try Session(fixture.snapshot))
            XCTAssertTrue(script.isComplete)
        }
    }

    func testWrongScopeLayoutCurrentPaneAndAgentIdentityAreRejected() async throws {
        let fixture = ReadFixture()
        for method in ["tab.list", "pane.list", "pane.layout", "pane.current", "agent.list", "agent.get"] {
            let agentReads = method == "agent.get"
            var steps = fixture.scoped(agentReads: agentReads, truncateAgents: agentReads)
            let index = steps.firstIndex { $0.method == method }!
            var value = steps[index].result.object
            let key = ["tab.list": "tabs", "pane.list": "panes", "pane.layout": "layout", "pane.current": "pane", "agent.list": "agents", "agent.get": "agent"][method]!
            if case .array(var records)? = value[key] {
                var record = records[0].object; record["workspace_id"] = .string("wrong")
                records[0] = .object(record); value[key] = .array(records)
            } else {
                var record = value[key]!.object; record["workspace_id"] = .string("wrong")
                value[key] = .object(record)
            }
            steps[index].result = .object(value)
            let script = ReadScript([ReadFixture.truncated("session.snapshot")] + Array(steps.prefix(index + (method == "tab.list" ? 2 : 1))))
            let server = try script.server()
            do { _ = try await SessionReader().load(RPC(path: server.path)); XCTFail("Mismatched \(method) accepted") }
            catch { XCTAssertTrue(error.localizedDescription.contains("scoped")) }
            XCTAssertTrue(script.isComplete)
        }
    }

    func testEmptySessionSkipsPaneCurrentAndPublishesEmptySnapshot() async throws {
        let empty: JSON = .object(["workspaces": .array([]), "tabs": .array([]), "panes": .array([]), "agents": .array([]), "layouts": .array([])])
        let script = ReadScript([
            ReadFixture.truncated("session.snapshot"), .init(method: "ping"),
            .init(method: "workspace.list", result: .object(["workspaces": .array([])])),
            .init(method: "agent.list", result: .object(["agents": .array([])])),
            .init(method: "workspace.list", result: .object(["workspaces": .array([])]))
        ])
        let server = try script.server()
        let value = try await SessionReader().load(RPC(path: server.path))
        XCTAssertEqual(value, try Session(empty))
        XCTAssertTrue(script.isComplete)
    }

    func testIncompleteScopedListsAndIncorrectCountsAreRejected() async throws {
        let fixture = ReadFixture()
        for result in [JSON.object([:]), .object(["tabs": .array([])]), .object(["tabs": .array(fixture.tabs)])] {
            var steps = fixture.scoped()
            steps[2].result = result
            let script = ReadScript([ReadFixture.truncated("session.snapshot")] + Array(steps.prefix(result["tabs"] == .null ? 3 : 4)))
            let server = try script.server()
            do { _ = try await SessionReader().load(RPC(path: server.path)); XCTFail("Incomplete list accepted") }
            catch { XCTAssertTrue(error.localizedDescription.contains("scoped")) }
            XCTAssertTrue(script.isComplete)
        }
    }
}
