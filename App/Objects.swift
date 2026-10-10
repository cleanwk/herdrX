import AppKit
import HerdCore

extension Desk {
    var paneTitles: [PaneKey: PaneTitle] {
        var result: [PaneKey: PaneTitle] = [:]
        for tab in shellTabs { for (key, _) in tab.layout.rects() { result[key] = PaneTitle(main: paneLabels[key] ?? tab.label, context: L("On This Mac")) } }
        for device in devices {
            guard let session = sessions[device.id] else { continue }
            for pane in session.panes {
                let space = session.spaces.first { $0.id == pane.workspace }?.label ?? ""
                result[PaneKey(device: device.id, pane: pane.id)] = PaneTitle(main: title(device: device.id, pane: pane), context: DisplayTitle.detail([space, device.displayName]))
            }
        }
        return result
    }
    func renameTab(_ id: String) {
        let device = selectedDevice
        guard device.map({ canAct(device: $0, object: "tab|" + id) }) ?? true else { return }
        let current = device.flatMap { sessions[$0]?.tabs.first { $0.id == id }?.label } ?? shellTabs.first { $0.id == id }?.label
        guard let current else { return }
        guard let name = NamePrompt.ask("Rename Tab", current: current) else { return }
        if let device { objectAction(device: device, method: "tab.rename", params: ["tab_id": .string(id), "label": .string(name)]) }
        else if let index = shellTabs.firstIndex(where: { $0.id == id }) { shellTabs[index].label = name; reindex() }
    }
    func closeTab(_ id: String) {
        if let device = selectedDevice, let tab = sessions[device]?.tabs.first(where: { $0.id == id }) {
            guard canAct(device: device, object: "tab|" + id) else { return }
            let count = sessions[device]?.panes.filter { $0.tab == id }.count ?? 0
            guard confirmClose(LF("Tab “%@”", tab.label), device: device, count: count) else { return }
            objectAction(device: device, method: "tab.close", params: ["tab_id": .string(id)])
        } else if let tab = shellTabs.first(where: { $0.id == id }) {
            guard confirmLocalClose(tab.layout.rects().map(\.0)) else { return }
            let index = shellTabs.firstIndex { $0.id == id } ?? 0
            for (key, _) in tab.layout.rects() { terminals.removeValue(forKey: key)?.process.stop(); ended.remove(key) }
            shellTabs.removeAll { $0.id == id }; if selectedTab == id { select(device: nil, tab: shellTabs.isEmpty ? nil : shellTabs[min(index, shellTabs.count - 1)].id) }; reindex()
        }
    }
    func closeSpace(device: String, space: Item) {
        guard canAct(device: device, object: "space|" + space.id) else { return }
        guard confirmClose(LF("Space “%@”", space.label), device: device, count: sessions[device]?.panes.filter { $0.workspace == space.id }.count ?? 0) else { return }
        objectAction(device: device, method: "workspace.close", params: ["workspace_id": .string(space.id)])
    }
    func confirmClose(_ object: String, device: String, count: Int) -> Bool {
        guard canWrite(device) else { return false }
        let alert = NSAlert(); alert.messageText = LF("Close %@?", object)
        alert.informativeText = LF("This terminates %d server pane(s) and their processes on %@. Disconnecting only releases the client attachment.", count, devices.first { $0.id == device }?.displayName ?? device)
        alert.addButton(withTitle: L("Close")); alert.addButton(withTitle: L("Cancel"))
        return alert.runModal() == .alertFirstButtonReturn
    }
    func objectAction(device: String, method: String, params: [String: JSON]) {
        let object = params["pane_id"]?.string.map { "pane|" + $0 } ?? params["tab_id"]?.string.map { "tab|" + $0 } ?? params["workspace_id"]?.string.map { "space|" + $0 } ?? method
        let key = device + "|" + object
        guard begin(key, device: device) else { return }
        Task { defer { busy.remove(key) }; do { let client = try rpc(device); _ = try await client.call(method, params); try await refresh(device, client: client) } catch { message = error.localizedDescription } }
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
            guard let self else { return }
            if let text = NSPasteboard.general.string(forType: .string) { _ = terminals[key]?.view.paste(text: text) }
        })
        if let url = terminals[key]?.hoverURL {
            menu.addItem(ActionMenuItem("Open Link") { NSWorkspace.shared.open(url) })
            menu.addItem(ActionMenuItem("Copy Link") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(url.absoluteString, forType: .string) })
        }
        menu.addItem(.separator())
        menu.addItem(ActionMenuItem("Rename Pane…", enabled: canAct(on: key)) { [weak self] in self?.renamePane(key) })
        menu.addItem(ActionMenuItem("Split Right") { [weak self] in self?.activate(key); self?.split(horizontal: true) })
        menu.addItem(ActionMenuItem("Split Down") { [weak self] in self?.activate(key); self?.split(horizontal: false) })
        menu.addItem(ActionMenuItem(zoomed && focused == key ? "Restore Pane" : "Zoom Pane") { [weak self] in guard let self else { return }; let restore = zoomed && focused == key; activate(key); zoomed = !restore })
        menu.addItem(ActionMenuItem("Move to New Tab", enabled: canAct(on: key)) { [weak self] in self?.movePaneToTab(key) })
        menu.addItem(.separator())
        menu.addItem(ActionMenuItem("Close Pane…", enabled: canAct(on: key)) { [weak self] in self?.closePane(key) })
        return menu
    }
    func renamePane(_ key: PaneKey) {
        guard canAct(on: key), let text = NamePrompt.ask("Rename Pane", current: paneLabels[key] ?? paneTitles[key]?.main ?? "") else { return }
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
