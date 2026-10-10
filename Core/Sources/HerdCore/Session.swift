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
    public let layouts: JSON
    public init(_ snapshot: JSON) throws {
        guard case .array = snapshot["workspaces"], case .array = snapshot["tabs"], case .array = snapshot["panes"] else { throw Failure("Incomplete session snapshot") }
        spaces = try snapshot["workspaces"].array.map { try Item($0, kind: "workspace") }
        tabs = try snapshot["tabs"].array.map { try Item($0, kind: "tab") }
        panes = try snapshot["panes"].array.map { try Item($0, kind: "pane") }
        layouts = snapshot["layouts"]
        let spaceIDs = Set(spaces.map(\.id))
        let tabKeys = Set(tabs.map { $0.workspace + "|" + $0.id })
        guard Set(spaces.map(\.id)).count == spaces.count, Set(tabs.map(\.id)).count == tabs.count, Set(panes.map(\.id)).count == panes.count,
              tabs.allSatisfy({ spaceIDs.contains($0.workspace) }),
              panes.allSatisfy({ pane in tabKeys.contains(pane.workspace + "|" + pane.tab) }) else { throw Failure("Invalid session topology") }
    }
    public static func load(_ rpc: RPC) async throws -> Session {
        return try Session(try await rpc.call("session.snapshot")["snapshot"])
    }
}

public struct Search: Sendable {
    public struct Document: Sendable {
        public let id: String
        public let name: String
        public let context: String
        public init(id: String, name: String, context: String = "") { self.id = id; self.name = name; self.context = context }
    }
    private struct Row: Sendable { let id: String; let name: String; let latin: String; let initials: String; let context: String }
    private var rows: [Row]
    private var source: [String: Document] = [:]
    public init(_ items: [(String, String)]) { self.init(documents: items.map { Document(id: $0.0, name: $0.1) }) }
    public init(documents: [Document]) { rows = []; update(documents: documents) }
    public mutating func update(documents: [Document]) {
        let previous = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
        rows = documents.map { item in
            if let old = source[item.id], old.name == item.name, old.context == item.context, let row = previous[item.id] { return row }
            let latin = Self.latin(item.name)
            return Row(id: item.id, name: item.name.lowercased(), latin: latin, initials: latin.split(separator: " ").compactMap(\.first).map(String.init).joined(), context: (item.context + " " + Self.latin(item.context)).lowercased())
        }
        source = Dictionary(uniqueKeysWithValues: documents.map { ($0.id, $0) })
    }
    private static func latin(_ text: String) -> String { (text.applyingTransform(.toLatin, reverse: false)?.applyingTransform(.stripDiacritics, reverse: false) ?? text).lowercased() }
    public func query(_ input: String) -> [String] {
        let text = input.lowercased().trimmingCharacters(in: .whitespaces)
        var buckets = [[String](), [String](), [String](), [String]()]
        for row in rows {
            if text.isEmpty || row.name.hasPrefix(text) || row.latin.hasPrefix(text) || row.latin.replacingOccurrences(of: " ", with: "").hasPrefix(text) || row.initials.hasPrefix(text) { buckets[0].append(row.id) }
            else if (row.name + " " + row.latin).split(separator: " ").contains(where: { $0.hasPrefix(text) }) { buckets[1].append(row.id) }
            else if row.name.contains(text) || row.latin.contains(text) { buckets[2].append(row.id) }
            else if row.context.contains(text) { buckets[3].append(row.id) }
        }
        return Array(buckets.flatMap { $0 }.prefix(50))
    }
}
