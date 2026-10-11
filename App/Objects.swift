import AppKit
import HerdCore

enum PaneMenuSource { case terminal, title }

extension Desk {
    var paneTitles: [PaneKey: PaneTitle] {
        var result: [PaneKey: PaneTitle] = [:]
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
        guard tabRenameRequest == nil, let device = selectedDevice,
              canAct(device: device, object: "tab|" + id),
              let tab = sessions[device]?.tabs.first(where: { $0.id == id }),
              let endpoint = devices.first(where: { $0.id == device })?.endpoint else { return }
        captureFocus()
        tabRenameRequest = TabRenameRequest(device: device, tab: id, space: tab.workspace, endpoint: endpoint, current: tab.label)
    }
    func submitTabRename(_ request: TabRenameRequest, name: String) async throws {
        guard let name = TabName.changed(name, from: request.current) else { return }
        let operation = tabRenameQueue.enqueue { [self] in
            guard devices.first(where: { $0.id == request.device })?.endpoint == request.endpoint,
                  sessions[request.device]?.tabs.contains(where: { $0.id == request.tab && $0.workspace == request.space }) == true,
                  begin(request.device + "|tab|" + request.tab, device: request.device) else {
                throw Failure(L("The tab is no longer available. Reconnect and try again."))
            }
            defer { busy.remove(request.device + "|tab|" + request.tab) }
            let client = try rpc(request.device)
            _ = try await client.call("tab.rename", ["tab_id": .string(request.tab), "label": .string(name)])
            // Only a server snapshot changes the displayed name. A failed RPC leaves it intact.
            try await refresh(request.device, client: client)
        }
        try await operation.value
    }
    func closeTab(_ id: String) {
        if let device = selectedDevice, let tab = sessions[device]?.tabs.first(where: { $0.id == id }) {
            guard canAct(device: device, object: "tab|" + id) else { return }
            let count = sessions[device]?.panes.filter { $0.tab == id }.count ?? 0
            guard confirmClose(LF("Tab “%@”", tab.label), device: device, count: count) else { return }
            objectAction(device: device, method: "tab.close", params: ["tab_id": .string(id)])
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
        jump(key.device + "|" + key.pane)
    }

    func paneMenu(_ key: PaneKey, source: PaneMenuSource) -> NSMenu {
        let menu = NSMenu(); menu.autoenablesItems = false
        if source == .terminal {
            menu.addItem(ActionMenuItem("Copy", enabled: terminals[key]?.surface?.hasSelection() == true) { [weak self] in _ = self?.terminals[key]?.view.copySelectedTextToPasteboard() })
            menu.addItem(ActionMenuItem("Paste", enabled: !ended.contains(key) && NSPasteboard.general.string(forType: .string)?.isEmpty == false) { [weak self] in
                guard let self, !ended.contains(key), let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else { return }
                _ = terminals[key]?.view.paste(text: text)
            })
            if let url = terminals[key]?.hoverURL {
                menu.addItem(ActionMenuItem("Open Link") { NSWorkspace.shared.open(url) })
                menu.addItem(ActionMenuItem("Copy Link") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(url.absoluteString, forType: .string) })
            }
            menu.addItem(.separator())
        }
        menu.addItem(ActionMenuItem("Rename Pane…", enabled: canAct(on: key)) { [weak self] in self?.renamePane(key) })
        menu.addItem(ActionMenuItem("Split Right", enabled: canSplit(horizontal: true, target: key)) { [weak self] in self?.split(horizontal: true, target: key) })
        menu.addItem(ActionMenuItem("Split Down", enabled: canSplit(horizontal: false, target: key)) { [weak self] in self?.split(horizontal: false, target: key) })
        if canZoom(key) {
            menu.addItem(ActionMenuItem(zoomed && focused == key ? "Restore Pane" : "Zoom Pane") { [weak self] in
                guard let self, canZoom(key) else { return }; let restore = zoomed && focused == key; activate(key); zoomed = !restore
            })
        }
        if let pane = sessions[key.device]?.panes.first(where: { $0.id == key.pane }),
           sessions[key.device]?.panes.filter({ $0.tab == pane.tab }).count ?? 0 > 1 {
            menu.addItem(ActionMenuItem("Move to New Tab", enabled: canAct(on: key)) { [weak self] in self?.movePaneToTab(key) })
        }
        menu.addItem(.separator())
        menu.addItem(ActionMenuItem("Close Pane…", enabled: canAct(on: key)) { [weak self] in self?.closePane(key) })
        return menu
    }
    func renamePane(_ key: PaneKey) {
        guard canAct(on: key), let text = NamePrompt.ask("Rename Pane", current: paneLabels[key] ?? paneTitles[key]?.main ?? "") else { return }
        objectAction(device: key.device, method: "pane.rename", params: ["pane_id": .string(key.pane), "label": .string(text)])
    }
    func movePaneToTab(_ key: PaneKey) {
        objectAction(device: key.device, method: "pane.move", params: ["pane_id": .string(key.pane), "destination": .object(["type": .string("new_tab")]), "focus": .bool(false)])
    }
}
