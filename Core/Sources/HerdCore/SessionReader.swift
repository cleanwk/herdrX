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
    private var pending: (revision: UInt64, path: String, timeout: Int, task: Task<Snapshot, Error>)?
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
            revision += 1
            let revision = revision
            task = Task {
                await previous?.value
                if self.pending?.revision == revision { self.pending = nil }
                return Snapshot(revision: revision, session: try await self.read(rpc, timeout: timeout))
            }
            pending = (revision, rpc.path, timeout, task)
            tail = Task { _ = await task.result }
        }
        // One cancelled waiter must not cancel a read needed by other callers.
        let snapshot = try await task.value
        try Task.checkCancellation()
        return snapshot
    }

    /// Bound socket pressure and preserve server order, regardless of reply order.
    private func batch<Input: Sendable, Output: Sendable>(_ inputs: [Input],
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
    private static func workspace(_ space: JSON, rpc: RPC, timeout: Int) async throws -> Workspace {
        func call(_ method: String, _ params: [String: JSON]) async throws -> JSON {
            try Task.checkCancellation()
            let value = try await rpc.call(method, params, timeout: timeout)
            try Task.checkCancellation()
            return value
        }
        let params = ["workspace_id": space["workspace_id"]]
        let tabs = try records(try await call("tab.list", params), "tabs")
        let panes = try records(try await call("pane.list", params), "panes")
        guard tabs.allSatisfy({ $0["workspace_id"] == space["workspace_id"] }),
              panes.allSatisfy({ $0["workspace_id"] == space["workspace_id"] }),
              space["tab_count"] == .number(Double(tabs.count)),
              space["pane_count"] == .number(Double(panes.count)) else {
            throw Failure("Session topology changed during scoped read")
        }
        var layouts: [JSON] = []
        for tab in tabs {
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
            layouts.append(layout)
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
        let workspaces = try await batch(spaces) { space in
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
            agents = try await batch(panes.filter { $0["agent"].string != nil }) { pane in
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
