import AppKit
import HerdCore

struct PaneTitle: Equatable { let main: String; let context: String; var full: String { DisplayTitle.detail([main, context]) } }

extension Desk {
    func title(device: String, pane: Item) -> String { DisplayTitle.pane(pane, tab: sessions[device]?.tabs.first { $0.id == pane.tab }, fallback: L("Terminal")) }
    func spacePath(device: String, space: String) -> String? {
        let snapshot = sessions[device]
        return snapshot?.spaces.first { $0.id == space }?.cwd ?? snapshot?.panes.first { $0.workspace == space && $0.id == focused?.pane }?.cwd ?? snapshot?.panes.first { $0.workspace == space }?.cwd
    }
    func paneHelp(_ row: AgentRow) -> String {
        let device = devices.first { $0.id == row.device }
        let context = [device?.displayName, device?.endpoint.socketPath, sessions[row.device]?.spaces.first { $0.id == row.pane.workspace }?.label, row.pane.cwd]
        let metadata = ["model", "account", "context", "quota"].compactMap { row.pane.tokens[$0]?.string }
        return ([title(device: row.device, pane: row.pane)] + context.compactMap { $0 } + metadata).joined(separator: "\n")
    }
    func valid(_ row: JumpRow) -> Bool {
        guard let device = row.device else { return shellTabs.contains { $0.id == row.tab } }
        guard let session = sessions[device], devices.contains(where: { $0.id == device }) else { return false }
        if let pane = row.pane { return session.panes.contains { $0.id == pane && $0.workspace == row.space && $0.tab == row.tab } }
        return session.spaces.contains { $0.id == row.space }
    }
    func reveal(device: String?, space: String?) {
        if let device, !deviceFilter.isEmpty, deviceFilter != device { deviceFilter = "" }
        UserDefaults.standard.set(false, forKey: "sidebarCollapsed." + (device.map { "device-" + $0 } ?? "shells"))
        sidebarReveal = device.flatMap { id in space.map { id + "|" + $0 } }
    }
    func copyDirectory(_ key: PaneKey) {
        guard let path = sessions[key.device]?.panes.first(where: { $0.id == key.pane })?.cwd else { return }
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(path, forType: .string)
    }
    func canAct(device: String, object: String) -> Bool { canWrite(device) && !busy.contains(device + "|" + object) }
    func canAct(on key: PaneKey) -> Bool { canAct(device: key.device, object: "pane|" + key.pane) }
    func canSplit(horizontal: Bool) -> Bool {
        guard let key = focused, canAct(on: key), let rect = activeRects.first(where: { $0.0 == key })?.1 else { return false }
        let size = terminals[key]?.view.frame.size ?? .zero
        let minimum = minimumPaneSize
        return horizontal ? size.width >= minimum.width * 2 + 8 && rect.width > 0 : size.height >= minimum.height * 2 + 18 && rect.height > 0
    }
    var minimumPaneSize: CGSize {
        let font = max(9, UserDefaults.standard.double(forKey: "fontSize") == 0 ? 13 : UserDefaults.standard.double(forKey: "fontSize"))
        // Keep at least 24 columns × 6 rows; preserve the user's type size.
        return CGSize(width: max(160, font * 0.65 * 24 + 8), height: max(100, font * 1.5 * 6 + 18))
    }
    func confirmLocalClose(_ keys: [PaneKey]) -> Bool {
        let uncertain = keys.filter { !ended.contains($0) && terminals[$0]?.process.foregroundActivity() != .idle }
        guard !uncertain.isEmpty else { return true }
        let alert = NSAlert(); alert.messageText = L("Close running shell tasks?")
        alert.informativeText = LF("%d pane(s) may have a foreground task. Closing sends a termination signal. Cancel keeps them running.", uncertain.count)
        alert.addButton(withTitle: L("Close")); alert.addButton(withTitle: L("Cancel"))
        return alert.runModal() == .alertFirstButtonReturn
    }
    func recoveryLabel(_ key: PaneKey) -> String {
        guard key.device == "shell" else { return L("Attachment ended. The server pane may still be running.") }
        guard let status = exitStatus[key] else { return L("Shell launch failed.") }
        if status == 0 { return L("Shell exited normally.") }
        return LF("Shell exited with status %@.", (status & 0x7f) == 0 ? String(status >> 8) : LF("signal %d", status & 0x7f))
    }
    func reconnect(_ key: PaneKey) {
        guard terminals[key] != nil, key.device == "shell" || (canWrite(key.device) && sessions[key.device]?.panes.contains(where: { $0.id == key.pane }) == true) else { return }
        if key.device != "shell" {
            let alert = NSAlert(); alert.messageText = L("Reconnect to this pane?"); alert.informativeText = L("This takes attachment ownership from any other client. The server process keeps running.")
            alert.addButton(withTitle: L("Reconnect")); alert.addButton(withTitle: L("Cancel")); guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        ended.remove(key); exitStatus[key] = nil; terminals[key]?.restart(); requestFocus()
    }
}

/// Validation stays inside the native rename dialog; Enter cannot submit whitespace.
@MainActor
final class NamePrompt: NSObject, NSTextFieldDelegate {
    let alert = NSAlert()
    let field = NSTextField()
    let error = NSTextField(labelWithString: L("Enter a name."))
    func controlTextDidChange(_ notification: Notification) { validate() }
    func validate() { let valid = DisplayTitle.clean(field.stringValue) != nil; alert.buttons.first?.isEnabled = valid; error.isHidden = valid }
    static func ask(_ title: String, current: String) -> String? {
        let prompt = NamePrompt(); prompt.alert.messageText = L(title)
        prompt.alert.addButton(withTitle: L("Rename")); prompt.alert.addButton(withTitle: L("Cancel"))
        prompt.field.stringValue = current; prompt.field.delegate = prompt; prompt.field.setAccessibilityLabel(L("Name"))
        prompt.error.textColor = .secondaryLabelColor; prompt.error.font = .systemFont(ofSize: 11)
        let stack = NSStackView(views: [prompt.field, prompt.error]); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 6; stack.frame = NSRect(x: 0, y: 0, width: 320, height: 48)
        prompt.field.widthAnchor.constraint(equalToConstant: 320).isActive = true
        prompt.alert.accessoryView = stack; prompt.alert.window.initialFirstResponder = prompt.field; prompt.validate()
        guard prompt.alert.runModal() == .alertFirstButtonReturn else { return nil }
        return DisplayTitle.clean(prompt.field.stringValue)
    }
}
