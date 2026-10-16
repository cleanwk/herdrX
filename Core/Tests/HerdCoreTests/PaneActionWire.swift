import Foundation
import HerdCore

/// Synthetic metadata only. Full reads deliberately take two seconds; scoped
/// RPCs take 20ms. Shared by Core regressions and the real Desk/native canvas test.
final class PaneActionWire: @unchecked Sendable {
    private let lock = NSLock()
    private var ids = ["left", "right"]
    private var next = 3
    private var reads = 0
    private var invalidLayout = false
    private var workspaceError: String?
    private var timings: [(String, Date, TimeInterval)] = []
    let stopEvents = DispatchSemaphore(value: 0)
    var fullReads: Int { lock.lock(); defer { lock.unlock() }; return reads }
    func breakLayout(_ broken: Bool) { lock.lock(); invalidLayout = broken; lock.unlock() }
    func rejectWorkspace(_ code: String?) { lock.lock(); workspaceError = code; lock.unlock() }
    var snapshot: JSON { lock.lock(); defer { lock.unlock() }; return makeSnapshot() }
    func trace(since start: Date) {
        lock.lock(); let records = timings; lock.unlock()
        for (method, date, elapsed) in records where date >= start {
            print("ACTION WIRE \(method): start=\(date.timeIntervalSince(start))s handler=\(elapsed)s")
        }
    }
    private func makeSnapshot() -> JSON {
        let area: JSON = .object(["x": .number(0), "y": .number(0), "width": .number(120), "height": .number(40)])
        func pane(_ id: String, space: String, tab: String) -> JSON {
            .object(["pane_id": .string(id), "terminal_id": .string("term-" + id), "workspace_id": .string(space), "tab_id": .string(tab), "cwd": .string("/tmp")])
        }
        let spaces: [JSON] = (ids.isEmpty ? [] : [.object(["workspace_id": .string("w"), "label": .string("Synthetic action"), "tab_count": .number(1), "pane_count": .number(Double(ids.count))])])
            + [.object(["workspace_id": .string("other"), "tab_count": .number(1), "pane_count": .number(1)])]
        let tabs: [JSON] = (ids.isEmpty ? [] : [.object(["workspace_id": .string("w"), "tab_id": .string("t"), "pane_count": .number(Double(ids.count))])])
            + [.object(["workspace_id": .string("other"), "tab_id": .string("other-t"), "pane_count": .number(1)])]
        let panes = ids.map { pane($0, space: "w", tab: "t") } + [pane("other-p", space: "other", tab: "other-t")]
        let rectangles: [JSON] = ids.enumerated().map { index, id in
            .object(["pane_id": .string(id), "rect": .object(["x": .number(Double(index) * 120 / Double(ids.count)), "y": .number(0), "width": .number(120 / Double(ids.count)), "height": .number(40)])])
        }
        let layouts: [JSON] = (ids.isEmpty ? [] : [.object(["workspace_id": .string("w"), "tab_id": .string(invalidLayout ? "wrong" : "t"), "area": area, "panes": .array(rectangles)])])
            + [.object(["workspace_id": .string("other"), "tab_id": .string("other-t"), "area": area, "panes": .array([.object(["pane_id": .string("other-p"), "rect": area])])])]
        return .object(["workspaces": .array(spaces), "tabs": .array(tabs), "panes": .array(panes), "layouts": .array(layouts)])
    }
    func respond(_ request: JSON) -> Data {
        let method = request["method"].string!, params = request["params"]
        let start = Date()
        defer { lock.lock(); timings.append((method, start, Date().timeIntervalSince(start))); lock.unlock() }
        lock.lock()
        if method == "pane.close" { ids.removeAll { $0 == params["pane_id"].string } }
        if method == "pane.split" { ids.append("new-\(next)"); next += 1 }
        if method == "session.snapshot" { reads += 1 }
        let snapshot = makeSnapshot(), created = ids.last, workspaceError = workspaceError
        lock.unlock()
        if method == "events.subscribe" { _ = stopEvents.wait(timeout: .now() + 15) }
        Thread.sleep(forTimeInterval: method == "session.snapshot" ? 2 : 0.02)
        let result: JSON
        switch method {
        case "session.snapshot": result = .object(["snapshot": snapshot])
        case "workspace.list": result = .object(["workspaces": snapshot["workspaces"]])
        case "workspace.get":
            if let workspaceError {
                return try! JSONEncoder().encode(JSON.object(["id": request["id"], "error": .object(["code": .string(workspaceError), "message": .string("workspace not found")])])) + Data([10])
            }
            guard let space = snapshot["workspaces"].array.first(where: { $0["workspace_id"] == params["workspace_id"] }) else {
                return try! JSONEncoder().encode(JSON.object(["id": request["id"], "error": .object(["code": .string("workspace_not_found"), "message": .string("workspace not found")])])) + Data([10])
            }
            result = .object(["workspace": space])
        case "tab.list": result = .object(["tabs": .array(snapshot["tabs"].array.filter { $0["workspace_id"] == params["workspace_id"] })])
        case "pane.list": result = .object(["panes": .array(snapshot["panes"].array.filter { $0["workspace_id"] == params["workspace_id"] })])
        case "pane.layout":
            let pane = snapshot["panes"].array.first { $0["pane_id"] == params["pane_id"] }
            result = .object(["layout": snapshot["layouts"].array.first { $0["workspace_id"] == pane?["workspace_id"] } ?? .null])
        case "pane.get": result = .object(["pane": snapshot["panes"].array.first { $0["pane_id"] == params["pane_id"] } ?? .null])
        case "pane.split": result = .object(["pane": snapshot["panes"].array.first { $0["pane_id"].string == created } ?? .null])
        case "pane.close": result = .object([:])
        case "plugin.list": result = .object(["plugins": .array([])])
        case "events.subscribe": result = .object(["type": .string("subscription_started")])
        default: return try! JSONEncoder().encode(JSON.object(["id": request["id"], "error": .object(["message": .string("Unsupported fixture RPC " + method)])])) + Data([10])
        }
        return try! JSONEncoder().encode(JSON.object(["id": request["id"], "result": result])) + Data([10])
    }
}
