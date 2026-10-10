import Foundation

public struct Item: Identifiable, Equatable, Sendable {
    public let id: String
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
        label = value["title"].string ?? value["label"].string ?? value["terminal_title_stripped"].string ?? value["name"].string ?? agent ?? "Shell"
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
    private let rows: [(id: String, title: String, text: String, initials: String)]
    public init(_ items: [(String, String)]) {
        rows = items.map { id, title in
            let latin = title.applyingTransform(.toLatin, reverse: false)?.applyingTransform(.stripDiacritics, reverse: false) ?? title
            return (id, title, (title + " " + latin).lowercased(), latin.split(separator: " ").compactMap(\.first).map(String.init).joined().lowercased())
        }
    }
    public func query(_ input: String) -> [String] {
        let text = input.lowercased().trimmingCharacters(in: .whitespaces)
        var buckets = [[String](), [String](), [String]()]
        for row in rows {
            if text.isEmpty || row.text.hasPrefix(text) || row.initials.hasPrefix(text) { buckets[0].append(row.id) }
            else if row.text.split(separator: " ").contains(where: { $0.hasPrefix(text) }) { buckets[1].append(row.id) }
            else if row.text.contains(text) { buckets[2].append(row.id) }
        }
        return Array(buckets.flatMap { $0 }.prefix(50))
    }
}
