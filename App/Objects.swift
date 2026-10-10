import AppKit
import HerdCore

extension Desk {
    var paneTitles: [PaneKey: String] {
        var result: [PaneKey: String] = [:]
        for tab in shellTabs { for (key, _) in tab.layout.rects() { result[key] = paneLabels[key] ?? "Shell" } }
        for device in devices {
            guard let session = sessions[device.id] else { continue }
            for pane in session.panes {
                let space = session.spaces.first { $0.id == pane.workspace }?.label ?? ""
                result[PaneKey(device: device.id, pane: pane.id)] = (pane.agent ?? pane.label) + " · " + space + (device.endpoint.kind == "local" ? "" : " · " + device.displayName)
            }
        }
        return result
    }
    func renameTab(_ id: String) {
        let device = selectedDevice
        let current = device.flatMap { sessions[$0]?.tabs.first { $0.id == id }?.label } ?? shellTabs.first { $0.id == id }?.label
        guard let current else { return }
        let alert = NSAlert(); alert.messageText = L("Rename Tab"); alert.addButton(withTitle: L("Rename")); alert.addButton(withTitle: L("Cancel"))
        let field = NSTextField(string: current); field.frame = NSRect(x: 0, y: 0, width: 300, height: 24); alert.accessoryView = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if let device { objectAction(device: device, method: "tab.rename", params: ["tab_id": .string(id), "label": .string(name)]) }
        else if let index = shellTabs.firstIndex(where: { $0.id == id }) { shellTabs[index].label = name; reindex() }
    }
    func closeTab(_ id: String) {
        if let device = selectedDevice, let tab = sessions[device]?.tabs.first(where: { $0.id == id }) {
            let count = sessions[device]?.panes.filter { $0.tab == id }.count ?? 0
            guard confirmClose("Tab “\(tab.label)”", device: device, count: count) else { return }
            objectAction(device: device, method: "tab.close", params: ["tab_id": .string(id)])
        } else if let tab = shellTabs.first(where: { $0.id == id }) {
            for (key, _) in tab.layout.rects() { terminals.removeValue(forKey: key)?.process.stop(); ended.remove(key) }
            shellTabs.removeAll { $0.id == id }; if selectedTab == id { select(device: nil) }; reindex()
        }
    }
    func closeSpace(device: String, space: Item) {
        guard confirmClose("Space “\(space.label)”", device: device, count: sessions[device]?.panes.filter { $0.workspace == space.id }.count ?? 0) else { return }
        objectAction(device: device, method: "workspace.close", params: ["workspace_id": .string(space.id)])
    }
    func confirmClose(_ object: String, device: String, count: Int) -> Bool {
        let alert = NSAlert(); alert.messageText = "Close \(object)?"
        alert.informativeText = "This terminates \(count) server pane(s) and their processes on \(devices.first { $0.id == device }?.displayName ?? device). Disconnecting only releases the client attachment."
        alert.addButton(withTitle: L("Close")); alert.addButton(withTitle: L("Cancel"))
        return alert.runModal() == .alertFirstButtonReturn
    }
    func objectAction(device: String, method: String, params: [String: JSON]) {
        Task { do { let client = try rpc(device); _ = try await client.call(method, params); try await refresh(device, client: client) } catch { message = error.localizedDescription } }
    }
}

@MainActor
final class ActionMenuItem: NSMenuItem {
    private let invoke: () -> Void
    init(_ title: String, enabled: Bool = true, action: @escaping () -> Void) {
        invoke = action; super.init(title: L(title), action: #selector(run), keyEquivalent: ""); target = self; isEnabled = enabled
    }
    required init(coder: NSCoder) { fatalError() }
    @objc private func run() { invoke() }
}

extension Desk {
    func activate(_ key: PaneKey) {
        if key.device == "shell", let tab = shellTabs.first(where: { $0.layout.rects().contains { $0.0 == key } }) { select(device: nil, tab: tab.id, pane: key) }
        else { jump(key.device + "|" + key.pane) }
    }
    func paneMenu(_ key: PaneKey) -> NSMenu {
        let menu = NSMenu(); menu.autoenablesItems = false
        menu.addItem(ActionMenuItem("Copy", enabled: terminals[key]?.surface?.hasSelection() == true) { [weak self] in _ = self?.terminals[key]?.view.copySelectedTextToPasteboard() })
        menu.addItem(ActionMenuItem("Paste", enabled: NSPasteboard.general.types?.isEmpty == false) { [weak self] in
            guard let self, !pasteAttachment(to: key) else { return }
            if let text = NSPasteboard.general.string(forType: .string) { _ = terminals[key]?.view.paste(text: text) }
        })
        if let url = terminals[key]?.hoverURL {
            menu.addItem(ActionMenuItem("Open Link") { NSWorkspace.shared.open(url) })
            menu.addItem(ActionMenuItem("Copy Link") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(url.absoluteString, forType: .string) })
        }
        menu.addItem(.separator())
        menu.addItem(ActionMenuItem("Attach File…", enabled: sessions[key.device]?.panes.first(where: { $0.id == key.pane })?.agent != nil) { [weak self] in self?.attachFile(to: key) })
        menu.addItem(ActionMenuItem("Rename Pane…") { [weak self] in self?.renamePane(key) })
        menu.addItem(ActionMenuItem("Split Right") { [weak self] in self?.activate(key); self?.split(horizontal: true) })
        menu.addItem(ActionMenuItem("Split Down") { [weak self] in self?.activate(key); self?.split(horizontal: false) })
        menu.addItem(ActionMenuItem(zoomed && focused == key ? "Restore Pane" : "Zoom Pane") { [weak self] in guard let self else { return }; let restore = zoomed && focused == key; activate(key); zoomed = !restore })
        menu.addItem(ActionMenuItem("Move to New Tab") { [weak self] in self?.movePaneToTab(key) })
        menu.addItem(.separator())
        menu.addItem(ActionMenuItem("Close Pane…") { [weak self] in self?.closePane(key) })
        return menu
    }
    func renamePane(_ key: PaneKey) {
        let alert = NSAlert(); alert.messageText = L("Rename Pane"); alert.addButton(withTitle: L("Rename")); alert.addButton(withTitle: L("Cancel"))
        let field = NSTextField(string: paneLabels[key] ?? paneTitles[key] ?? ""); field.frame = NSRect(x: 0, y: 0, width: 300, height: 24); alert.accessoryView = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if key.device == "shell" { paneLabels[key] = text }
        else { objectAction(device: key.device, method: "pane.rename", params: ["pane_id": .string(key.pane), "label": .string(text)]) }
    }
    func movePaneToTab(_ key: PaneKey) {
        if key.device != "shell" {
            objectAction(device: key.device, method: "pane.move", params: ["pane_id": .string(key.pane), "destination": .object(["type": .string("new_tab")]), "focus": .bool(false)])
        } else if let index = shellTabs.firstIndex(where: { $0.layout.rects().contains { $0.0 == key } }) {
            if let rest = shellTabs[index].layout.removing(key) { shellTabs[index].layout = rest } else { shellTabs.remove(at: index) }
            let tab = ShellTab(id: UUID().uuidString, label: paneLabels[key] ?? "Shell", layout: .pane(key)); shellTabs.append(tab); select(device: nil, tab: tab.id); reindex()
        }
    }
}
