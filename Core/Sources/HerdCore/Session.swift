import Foundation

public struct Item: Identifiable, Equatable, Sendable {
    public let id: String
    public let customLabel: String?
    public let agentTitle: String?
    public let sessionName: String?
    public let terminalTitle: String?
    public let label: String
    public let workspace: String
    public let tab: String
    public let terminal: String?
    public let agent: String?
    public let status: String
    public let cwd: String?
    public let tokens: [String: JSON]
    public let stateLabel: String
    public init(_ value: JSON, kind: String) throws {
        guard let id = value[kind + "_id"].string else { throw Failure("Missing \(kind) ID") }
        self.id = id; workspace = value["workspace_id"].string ?? id
        tab = value["tab_id"].string ?? ""
        terminal = value["terminal_id"].string; agent = value["agent"].string
        status = value["agent_status"].string ?? "unknown"
        cwd = value["foreground_cwd"].string ?? value["cwd"].string
        customLabel = DisplayTitle.clean(value["label"].string)
        agentTitle = DisplayTitle.clean(value["title"].string)
        sessionName = DisplayTitle.clean(value["name"].string)
        terminalTitle = DisplayTitle.clean(value["terminal_title_stripped"].string)
        label = customLabel ?? agentTitle ?? terminalTitle ?? sessionName ?? agent ?? "Shell"
        tokens = value["tokens"].object
        stateLabel = value["state_labels"][status].string ?? status
    }
}

public struct Session: Equatable, Sendable {
    public let spaces: [Item]
    public let tabs: [Item]
    public let panes: [Item]
    public let agents: [Item]
    public let layouts: JSON
    public init(_ snapshot: JSON) throws {
        guard case .array = snapshot["workspaces"], case .array = snapshot["tabs"], case .array = snapshot["panes"] else { throw Failure("Incomplete session snapshot") }
        spaces = try snapshot["workspaces"].array.map { try Item($0, kind: "workspace") }
        tabs = try snapshot["tabs"].array.map { try Item($0, kind: "tab") }
        panes = try snapshot["panes"].array.map { try Item($0, kind: "pane") }
        if case .array(let records) = snapshot["agents"] {
            let values = Dictionary(snapshot["panes"].array.compactMap { value in value["pane_id"].string.map { ($0, value) } }, uniquingKeysWith: { first, _ in first })
            agents = try records.compactMap { record in
                guard let id = record["pane_id"].string, let pane = values[id],
                      record["terminal_id"] == pane["terminal_id"], record["tab_id"] == pane["tab_id"],
                      record["workspace_id"] == pane["workspace_id"] else { return nil }
                var merged = pane.object
                for (key, value) in record.object { merged[key] = value }
                merged["agent"] = record["agent"]
                if merged["agent"]?.string == nil, let tool = record["agent_session"]["agent"].string {
                    merged["agent"] = .string(tool)
                }
                return try Item(.object(merged), kind: "pane")
            }
        } else {
            agents = panes.filter { $0.agent != nil }
        }
        layouts = snapshot["layouts"]
        try validate()
    }
    private init(spaces: [Item], tabs: [Item], panes: [Item], agents: [Item], layouts: JSON) throws {
        self.spaces = spaces; self.tabs = tabs; self.panes = panes; self.agents = agents; self.layouts = layouts
        try validate()
    }
    private func validate() throws {
        let spaceIDs = Set(spaces.map(\.id))
        let tabKeys = Set(tabs.map { $0.workspace + "|" + $0.id })
        guard Set(spaces.map(\.id)).count == spaces.count, Set(tabs.map(\.id)).count == tabs.count, Set(panes.map(\.id)).count == panes.count, Set(agents.map(\.id)).count == agents.count,
              tabs.allSatisfy({ spaceIDs.contains($0.workspace) }),
              panes.allSatisfy({ pane in tabKeys.contains(pane.workspace + "|" + pane.tab) }) else { throw Failure("Invalid session topology") }
    }
    /// Replace a complete server-read Space without inventing pane IDs or split
    /// geometry. Other Spaces and their enriched Agent records remain untouched.
    public func replacingWorkspace(_ id: String, with scoped: Session) throws -> Session {
        guard scoped.spaces.count <= 1, scoped.spaces.allSatisfy({ $0.id == id }),
              scoped.tabs.allSatisfy({ $0.workspace == id }), scoped.panes.allSatisfy({ $0.workspace == id }),
              scoped.layouts.array.allSatisfy({ $0["workspace_id"].string == id }) else {
            throw Failure("Mismatched scoped workspace")
        }
        func replace<Value>(_ old: [Value], _ new: [Value], matches: (Value) -> Bool) -> [Value] {
            let index = old.firstIndex(where: matches) ?? old.count
            return Array(old[..<index]) + new + old[index...].filter { !matches($0) }
        }
        let scopedAgents = scoped.agents.map { pane in
            // Keep enrichment only when its underlying pane is unchanged.
            // A rename/status/cwd update must be visible in Agent rows as well.
            guard panes.first(where: { $0.id == pane.id }) == pane else { return pane }
            return agents.first { $0.id == pane.id && $0.terminal == pane.terminal && $0.workspace == pane.workspace && $0.tab == pane.tab && $0.agent == pane.agent && $0.status == pane.status } ?? pane
        }
        return try Session(
            spaces: replace(spaces, scoped.spaces, matches: { $0.id == id }),
            tabs: replace(tabs, scoped.tabs, matches: { $0.workspace == id }),
            panes: replace(panes, scoped.panes, matches: { $0.workspace == id }),
            agents: replace(agents, scopedAgents, matches: { $0.workspace == id }),
            layouts: .array(replace(layouts.array, scoped.layouts.array, matches: { $0["workspace_id"].string == id })))
    }
    public static func load(_ rpc: RPC) async throws -> Session {
        try await SessionReader().load(rpc)
    }
}

public struct Search: Sendable {
    public struct Document: Sendable {
        public let id: String
        public let name: String
        public let context: String
        public init(id: String, name: String, context: String = "") { self.id = id; self.name = name; self.context = context }
    }
    private struct Row: Sendable {
        let id: String
        let name: String
        let latin: String
        let compact: String
        let words: [Substring]
        let initials: String
        let context: String
    }
    private var rows: [Row]
    private var source: [String: Document] = [:]
    public init(_ items: [(String, String)]) { self.init(documents: items.map { Document(id: $0.0, name: $0.1) }) }
    public init(documents: [Document]) { rows = []; update(documents: documents) }
    public mutating func update(documents: [Document]) {
        let previous = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
        rows = documents.map { item in
            if let old = source[item.id], old.name == item.name, old.context == item.context, let row = previous[item.id] { return row }
            let latin = Self.latin(item.name)
            // Each keystroke scans every row; keep the derived prefix inputs
            // instead of rebuilding them inside query().
            let name = item.name.lowercased()
            let combined = name + " " + latin
            return Row(id: item.id, name: name, latin: latin,
                       compact: latin.replacingOccurrences(of: " ", with: ""),
                       words: combined.split(separator: " "),
                       initials: latin.split(separator: " ").compactMap(\.first).map(String.init).joined(),
                       context: (item.context + " " + Self.latin(item.context)).lowercased())
        }
        source = Dictionary(uniqueKeysWithValues: documents.map { ($0.id, $0) })
    }
    private static func latin(_ text: String) -> String { (text.applyingTransform(.toLatin, reverse: false)?.applyingTransform(.stripDiacritics, reverse: false) ?? text).lowercased() }
    public func query(_ input: String) -> [String] {
        let text = input.lowercased().trimmingCharacters(in: .whitespaces)
        var buckets = [[String](), [String](), [String](), [String]()]
        for row in rows {
            if text.isEmpty || row.name.hasPrefix(text) || row.latin.hasPrefix(text) || row.compact.hasPrefix(text) || row.initials.hasPrefix(text) { buckets[0].append(row.id) }
            else if row.words.contains(where: { $0.hasPrefix(text) }) { buckets[1].append(row.id) }
            else if row.name.contains(text) || row.latin.contains(text) { buckets[2].append(row.id) }
            else if row.context.contains(text) { buckets[3].append(row.id) }
        }
        return Array(buckets.flatMap { $0 }.prefix(50))
    }
}
