import AppKit
import HerdCore

struct PaneTitle: Equatable {
    let main: String
    let context: String
    var identity: String? = nil
    var full: String { identity ?? DisplayTitle.detail([main, context]) }
}

extension Desk {
    func title(device: String, pane: Item) -> String {
        if pane.agent == nil { return DisplayTitle.terminal(pane, fallback: L("Terminal")) }
        return DisplayTitle.pane(pane, tab: sessions[device]?.tabs.first { $0.id == pane.tab }, fallback: L("Terminal"))
    }
    func spacePath(device: String, space: String) -> String? {
        let snapshot = sessions[device]
        return snapshot?.spaces.first { $0.id == space }?.cwd ?? snapshot?.panes.first { $0.workspace == space && $0.id == focused?.pane }?.cwd ?? snapshot?.panes.first { $0.workspace == space }?.cwd
    }
    func paneHelp(_ row: AgentRow) -> String {
        let device = devices.first { $0.id == row.device }
        let context = [device?.displayName, device?.endpoint.socketPath, sessions[row.device]?.spaces.first { $0.id == row.pane.workspace }?.label, row.pane.cwd]
        let metadata = ["model", "account", "context", "quota"].compactMap { row.pane.tokens[$0]?.string }
        return ([title(device: row.device, pane: row.pane)] + [row.pane.agent].compactMap { $0 } + context.compactMap { $0 } + metadata).joined(separator: "\n")
    }
    func valid(_ row: JumpRow) -> Bool {
        guard let device = row.device else { return false }
        guard let session = sessions[device], devices.contains(where: { $0.id == device }) else { return false }
        if let pane = row.pane { return session.panes.contains { $0.id == pane && $0.workspace == row.space && $0.tab == row.tab } }
        return session.spaces.contains { $0.id == row.space }
    }
    func reveal(device: String?, space: String?) {
        if let device, !deviceFilter.isEmpty, deviceFilter != device { deviceFilter = "" }
        UserDefaults.standard.set(false, forKey: "sidebarCollapsed." + (device.map { "device-" + $0 } ?? ""))
        sidebarReveal = device.flatMap { id in space.map { id + "|" + $0 } }
    }
    func copyDirectory(_ key: PaneKey) {
        guard let path = sessions[key.device]?.panes.first(where: { $0.id == key.pane })?.cwd else { return }
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(path, forType: .string)
    }
    func canAct(device: String, object: String) -> Bool { canWrite(device) && !busy.contains(device + "|" + object) }
    func canAct(on key: PaneKey) -> Bool { canAct(device: key.device, object: "pane|" + key.pane) }
    func canSplit(horizontal: Bool, target: PaneKey? = nil) -> Bool {
        guard let key = target ?? focused, canAct(on: key),
              let rect = layoutRects.first(where: { $0.0 == key })?.1 else { return false }
        // Use the pane's actual layout slot, even while it is displayed zoomed.
        let scale = terminals[key]?.view.window?.backingScaleFactor ?? 2
        let frame = PaneMetrics.frame(rect, in: canvasSize, scale: scale)
        return PaneMetrics.canSplit(frame.size, horizontal: horizontal, minimum: minimumPaneSize)
    }
    func canZoom(_ key: PaneKey) -> Bool {
        layoutRects.contains(where: { $0.0 == key }) && (zoomed || layoutRects.count > 1)
    }
    var minimumPaneSize: CGSize {
        let font = max(9, UserDefaults.standard.double(forKey: "fontSize") == 0 ? 13.5 : UserDefaults.standard.double(forKey: "fontSize"))
        // Reserve the largest possible gutter inset as well as 24 columns × 6 rows.
        return CGSize(width: max(160, font * 0.65 * 24 + PaneMetrics.horizontalOverhead) + PaneMetrics.splitGap, height: max(100, font * 1.5 * 6 + PaneMetrics.verticalOverhead) + PaneMetrics.splitGap)
    }
    func recoveryLabel(_ key: PaneKey) -> String {
        L(terminals[key]?.observation.isRunning == true ? "Viewing only; history scrolling is unavailable. Reconnect or Take Control to scroll." : "Attachment ended. The server pane may still be running.")
    }
    func reconnect(_ key: PaneKey, takeover: Bool = false) {
        guard let terminal = terminals[key], canWrite(key.device),
              let target = sessions[key.device]?.panes.first(where: { $0.id == key.pane })?.terminal else { return }
        let endpoint = devices.first(where: { $0.id == key.device })?.endpoint
        if takeover {
            let alert = NSAlert(); alert.messageText = L("Take control of this terminal?"); alert.informativeText = L("This takes attachment ownership from any other client. The server process keeps running.")
            alert.addButton(withTitle: L("Take Control")); alert.addButton(withTitle: L("Cancel")); guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        guard canWrite(key.device), terminals[key] === terminal,
              devices.first(where: { $0.id == key.device })?.endpoint == endpoint,
              sessions[key.device]?.panes.contains(where: { $0.id == key.pane && $0.terminal == target }) == true else { return }
        ended.remove(key); exitStatus[key] = nil; terminal.restart(takeover: takeover); requestFocus()
    }
}
