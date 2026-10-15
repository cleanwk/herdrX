import Foundation

/// Client-only state. A first snapshot establishes history, never unread results.
public struct Attention: Sendable {
    public private(set) var unread: Set<PaneKey> = []
    public init() {}
    public mutating func update(device: String, old: Session?, new: Session) {
        let valid = Set(new.panes.filter { $0.agent != nil && $0.status == "done" }.map { PaneKey(device: device, pane: $0.id) })
        unread = unread.filter { $0.device != device || valid.contains($0) }
        guard let old else { return }
        let previous = Dictionary(uniqueKeysWithValues: old.panes.filter { $0.agent != nil }.map { ($0.id, $0.status) })
        for pane in new.panes where pane.agent != nil && pane.status == "done" {
            if let status = previous[pane.id], status != "done" { unread.insert(PaneKey(device: device, pane: pane.id)) }
        }
    }
    public mutating func leave(_ key: PaneKey?) { if let key { unread.remove(key) } }
    public mutating func remove(device: String) { unread = unread.filter { $0.device != device } }
    public static func rank(_ status: String) -> Int {
        switch status { case "blocked": return 0; case "working": return 1; case "done": return 2; case "idle": return 3; default: return 4 }
    }
    public func sidebarRank(_ key: PaneKey, status: String) -> Int {
        if status == "done" && unread.contains(key) { return 2 }
        let rank = Self.rank(status)
        return rank >= 2 ? rank + 1 : rank
    }
    public func needsAttention(_ key: PaneKey, status: String) -> Bool { status == "blocked" || (status == "done" && unread.contains(key)) }
    public func summary(device: String, panes: [Item]) -> String? {
        let agents = panes.filter { $0.agent != nil }
        if agents.contains(where: { $0.status == "blocked" }) { return "blocked" }
        if agents.contains(where: { $0.status == "done" && unread.contains(PaneKey(device: device, pane: $0.id)) }) { return "unread" }
        return agents.contains(where: { $0.status == "working" }) ? "working" : nil
    }
}
