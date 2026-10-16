import Foundation

/// One reader per configured device endpoint. Keep it across reconnects, including
/// SSH tunnel path changes, so a known truncated aggregate is not polled again.
public actor SessionReader {
    private var scoped = false
    private var scopedAgents = false
    private var tail: Task<Void, Never>?
    public init() {}

    public func load(_ rpc: RPC, timeout: Int = 15) async throws -> Session {
        let previous = tail
        let task = Task {
            await previous?.value
            try Task.checkCancellation()
            return try await self.read(rpc, timeout: timeout)
        }
        tail = Task { _ = await task.result }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: { task.cancel() }
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
        var tabs: [JSON] = [], panes: [JSON] = [], layouts: [JSON] = []
        for space in spaces {
            let params = ["workspace_id": space["workspace_id"]]
            let scopedTabs = try Self.records(try await call("tab.list", params), "tabs")
            let scopedPanes = try Self.records(try await call("pane.list", params), "panes")
            guard scopedTabs.allSatisfy({ $0["workspace_id"] == space["workspace_id"] }),
                  scopedPanes.allSatisfy({ $0["workspace_id"] == space["workspace_id"] }),
                  space["tab_count"] == .number(Double(scopedTabs.count)),
                  space["pane_count"] == .number(Double(scopedPanes.count)) else {
                throw Failure("Session topology changed during scoped read")
            }
            for tab in scopedTabs {
                let members = scopedPanes.filter { $0["tab_id"] == tab["tab_id"] }
                guard tab["pane_count"] == .number(Double(members.count)), let first = members.first else {
                    throw Failure("Incomplete scoped tab")
                }
                // pane.layout returns the same rectangles as session.snapshot.
                let layout = try await call("pane.layout", ["pane_id": first["pane_id"]])["layout"]
                let rectangles = try Self.records(layout, "panes")
                guard layout["workspace_id"] == space["workspace_id"], layout["tab_id"] == tab["tab_id"],
                      rectangles.count == members.count,
                      Set(rectangles.map { $0["pane_id"] }) == Set(members.map { $0["pane_id"] }) else {
                    throw Failure("Session layout changed during scoped read")
                }
                layouts.append(layout)
            }
            tabs += scopedTabs; panes += scopedPanes
        }
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
            for pane in panes where pane["agent"].string != nil {
                let agent = try await call("agent.get", ["target": pane["pane_id"]])["agent"]
                guard Self.samePane(pane, agent) else { throw Failure("Agent changed during scoped read") }
                agents.append(agent)
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
