import Foundation

/// Captured identity for the existing Herdr rename methods, including parent scope.
public enum RenameTarget: Equatable, Sendable {
    case space(id: String)
    case tab(id: String, space: String)
    case pane(id: String, tab: String, space: String)

    public var id: String {
        switch self { case .space(let id), .tab(let id, _), .pane(let id, _, _): id }
    }
    public var kind: String {
        switch self { case .space: "space"; case .tab: "tab"; case .pane: "pane" }
    }
    public var method: String { (kind == "space" ? "workspace" : kind) + ".rename" }
    public func parameters(name: String) -> [String: JSON] {
        [(kind == "space" ? "workspace" : kind) + "_id": .string(id), "label": .string(name)]
    }
    public func exists(in session: Session?) -> Bool {
        guard let session else { return false }
        switch self {
        case .space(let id): return session.spaces.contains { $0.id == id }
        case .tab(let id, let space): return session.tabs.contains { $0.id == id && $0.workspace == space }
        case .pane(let id, let tab, let space): return session.panes.contains { $0.id == id && $0.tab == tab && $0.workspace == space }
        }
    }
}
