import Foundation

/// One reader per configured device endpoint. Keep it across reconnects, including
/// SSH tunnel path changes, so a known truncated aggregate is not polled again.
public actor SessionReader {
    public struct Snapshot: Sendable {
        public let revision: UInt64
        public let session: Session
    }
    private var scoped = false
    private var scopedAgents = false
    private var tail: Task<Void, Never>?
    private var actionTail: Task<Void, Never>?
    private var pending: (id: UUID, path: String, timeout: Int, task: Task<Snapshot, Error>)?
    private var revision: UInt64 = 0
    private let concurrency: Int
    public init() { concurrency = 4 }
    // Serial mode keeps the existing fault-at-each-step wire regressions deterministic.
    init(concurrency: Int) { self.concurrency = max(1, concurrency) }

    public func load(_ rpc: RPC, timeout: Int = 15) async throws -> Session {
        try await loadSnapshot(rpc, timeout: timeout).session
    }

    /// Join only a read that has not started. A mutation must never reuse a
    /// snapshot that began before it completed. Bursts need at most one next read.
    public func loadSnapshot(_ rpc: RPC, timeout: Int = 15) async throws -> Snapshot {
        try Task.checkCancellation()
        let task: Task<Snapshot, Error>
        if let pending, pending.path == rpc.path, pending.timeout == timeout {
            task = pending.task
        } else {
            let previous = tail
            let id = UUID()
            task = Task {
                await previous?.value
                if self.pending?.id == id { self.pending = nil }
                self.revision += 1
                let revision = self.revision
                return Snapshot(revision: revision, session: try await self.read(rpc, timeout: timeout))
            }
            pending = (id, rpc.path, timeout, task)
            tail = Task { _ = await task.result }
        }
        // One cancelled waiter must not cancel a read needed by other callers.
        let snapshot = try await task.value
        try Task.checkCancellation()
        return snapshot
    }

    /// Mutations read only their Space, independently of an outstanding full read.
    /// Serialize these short reads so patches for different Spaces cannot overtake
    /// each other. Full and scoped reads share revisions allocated when they start.
    public func loadWorkspace(_ id: String, _ rpc: RPC, timeout: Int = 5) async throws -> Snapshot {
        try Task.checkCancellation()
        let previous = actionTail
        let task = Task {
            await previous?.value
            self.revision += 1
            let revision = self.revision
            let params = ["workspace_id": JSON.string(id)]
            let space: JSON
            do { space = try await rpc.call("workspace.get", params, timeout: timeout)["workspace"] }
            catch let error as RPC.RemoteError where error.code == "workspace_not_found" {
                return Snapshot(revision: revision, session: try Session(.object([
                    "workspaces": .array([]), "tabs": .array([]), "panes": .array([]), "layouts": .array([])
                ])))
            }
            guard space["workspace_id"].string == id else { throw Failure("Mismatched scoped workspace") }
            let before = try Self.topology([space])
            let contents = try await Self.workspace(space, rpc: rpc, timeout: timeout, concurrency: 4)
            let after = try await rpc.call("workspace.get", params, timeout: timeout)["workspace"]
            guard after["workspace_id"].string == id, before == (try Self.topology([after])) else {
                throw Failure("Session topology changed during scoped read")
            }
            return Snapshot(revision: revision, session: try Session(.object([
                "workspaces": .array([space]), "tabs": .array(contents.tabs),
                "panes": .array(contents.panes), "layouts": .array(contents.layouts)
            ])))
        }
        actionTail = Task { _ = await task.result }
        let snapshot = try await task.value
        try Task.checkCancellation()
        return snapshot
    }

    /// Bound socket pressure and preserve server order, regardless of reply order.
    private static func batch<Input: Sendable, Output: Sendable>(_ inputs: [Input], concurrency: Int,
        operation: @escaping @Sendable (Input) async throws -> Output) async throws -> [Output] {
        try await withThrowingTaskGroup(of: (Int, Output).self) { group in
            var next = 0
            var values = Array<Output?>(repeating: nil, count: inputs.count)
            func submit(_ index: Int) {
                let input = inputs[index]
                group.addTask {
                    try Task.checkCancellation()
                    return (index, try await operation(input))
                }
            }
            while next < min(concurrency, inputs.count) { submit(next); next += 1 }
            while let (index, value) = try await group.next() {
                values[index] = value
                if next < inputs.count { submit(next); next += 1 }
            }
            return values.map { $0! }
        }
    }

    private struct Workspace: Sendable {
        let tabs: [JSON]
        let panes: [JSON]
        let layouts: [JSON]
    }
    private static func workspace(_ space: JSON, rpc: RPC, timeout: Int, concurrency: Int = 1) async throws -> Workspace {
        @Sendable func call(_ method: String, _ params: [String: JSON]) async throws -> JSON {
            try Task.checkCancellation()
            let value = try await rpc.call(method, params, timeout: timeout)
            try Task.checkCancellation()
            return value
        }
        let params = ["workspace_id": space["workspace_id"]]
        let tabs: [JSON], panes: [JSON]
        if concurrency > 1 {
            async let tabList = call("tab.list", params)
            async let paneList = call("pane.list", params)
            let lists = try await (tabList, paneList)
            tabs = try records(lists.0, "tabs"); panes = try records(lists.1, "panes")
        } else {
            tabs = try records(try await call("tab.list", params), "tabs")
            panes = try records(try await call("pane.list", params), "panes")
        }
        guard tabs.allSatisfy({ $0["workspace_id"] == space["workspace_id"] }),
              panes.allSatisfy({ $0["workspace_id"] == space["workspace_id"] }),
              space["tab_count"] == .number(Double(tabs.count)),
              space["pane_count"] == .number(Double(panes.count)) else {
            throw Failure("Session topology changed during scoped read")
        }
        let layouts = try await batch(tabs, concurrency: concurrency) { tab in
            let members = panes.filter { $0["tab_id"] == tab["tab_id"] }
            guard tab["pane_count"] == .number(Double(members.count)), let first = members.first else {
                throw Failure("Incomplete scoped tab")
            }
            let layout = try await call("pane.layout", ["pane_id": first["pane_id"]])["layout"]
            let rectangles = try records(layout, "panes")
            guard layout["workspace_id"] == space["workspace_id"], layout["tab_id"] == tab["tab_id"],
                  rectangles.count == members.count,
                  Set(rectangles.map { $0["pane_id"] }) == Set(members.map { $0["pane_id"] }) else {
                throw Failure("Session layout changed during scoped read")
            }
            return layout
        }
        return Workspace(tabs: tabs, panes: panes, layouts: layouts)
    }

    private func read(_ rpc: RPC, timeout: Int) async throws -> Session {
        func call(_ method: String, _ params: [String: JSON] = [:]) async throws -> JSON {
            try Task.checkCancellation()
            let value = try await rpc.call(method, params, timeout: timeout)
            try Task.checkCancellation()
            return value
        }
        if !scoped {
            do { return try Session(try await call("session.snapshot")["snapshot"]) }
            catch is RPC.TruncatedResponse { scoped = true }
        }

        let ping = try await call("ping")
        let spaces = try Self.records(try await call("workspace.list"), "workspaces")
        let before = try Self.topology(spaces)
        let workspaces = try await Self.batch(spaces, concurrency: concurrency) { space in
            try await Self.workspace(space, rpc: rpc, timeout: timeout)
        }
        let tabs = workspaces.flatMap(\.tabs), panes = workspaces.flatMap(\.panes), layouts = workspaces.flatMap(\.layouts)
        // Herdr returns pane_not_found for an empty session, which is valid.
        var current: JSON = .null
        if !panes.isEmpty {
            current = try await call("pane.current")["pane"]
            guard panes.contains(where: { Self.samePane($0, current) }) else {
                throw Failure("Current pane changed during scoped read")
            }
        }

        var agents: [JSON] = []
        if !scopedAgents {
            do { agents = try Self.records(try await call("agent.list"), "agents") }
            catch is RPC.TruncatedResponse { scopedAgents = true }
        }
        if scopedAgents {
            agents = try await Self.batch(panes.filter { $0["agent"].string != nil }, concurrency: concurrency) { pane in
                let agent = try await rpc.call("agent.get", ["target": pane["pane_id"]], timeout: timeout)["agent"]
                guard Self.samePane(pane, agent) else { throw Failure("Agent changed during scoped read") }
                return agent
            }
        }
        guard agents.allSatisfy({ agent in panes.contains { Self.samePane($0, agent) } }) else {
            throw Failure("Agent topology changed during scoped read")
        }
        let after = try Self.records(try await call("workspace.list"), "workspaces")
        guard before == (try Self.topology(after)) else {
            throw Failure("Session topology changed during scoped read")
        }
        // No partial Session escapes. Desk retains its previous cache on any error.
        return try Session(.object([
            "version": ping["version"], "protocol": ping["protocol"],
            "workspaces": .array(spaces), "tabs": .array(tabs), "panes": .array(panes),
            "agents": .array(agents), "layouts": .array(layouts),
            "focused_workspace_id": current["workspace_id"], "focused_tab_id": current["tab_id"],
            "focused_pane_id": current["pane_id"]
        ]))
    }

    private static func records(_ value: JSON, _ key: String) throws -> [JSON] {
        guard case .array(let records) = value[key] else { throw Failure("Incomplete scoped \(key)") }
        return records
    }
    private static func samePane(_ a: JSON, _ b: JSON) -> Bool {
        ["pane_id", "workspace_id", "tab_id", "terminal_id"].allSatisfy { a[$0].string != nil && a[$0] == b[$0] }
    }
    private static func topology(_ spaces: [JSON]) throws -> [String: [JSON]] {
        var result: [String: [JSON]] = [:]
        for space in spaces {
            guard let id = space["workspace_id"].string, result[id] == nil,
                  case .number(let panes) = space["pane_count"], panes >= 0, panes.rounded() == panes,
                  case .number(let tabs) = space["tab_count"], tabs >= 0, tabs.rounded() == tabs else {
                throw Failure("Invalid scoped workspace topology")
            }
            result[id] = [space["pane_count"], space["tab_count"]]
        }
        return result
    }
}
