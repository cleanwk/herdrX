import AppKit
import HerdCore

enum PaneMenuSource { case terminal, title }

extension Desk {
    var paneTitles: [PaneKey: PaneTitle] {
        let language = UserDefaults.standard.string(forKey: "language") ?? "system"
        if paneTitlesCacheRevision == paneTitlesRevision && paneTitlesCacheLanguage == language { return paneTitlesCache }
        var result: [PaneKey: PaneTitle] = [:]
        for device in devices {
            guard let session = sessions[device.id] else { continue }
            let spacesByID = Dictionary(uniqueKeysWithValues: session.spaces.map { ($0.id, $0) })
            let tabsByID = Dictionary(uniqueKeysWithValues: session.tabs.map { ($0.id, $0) })
            let terminalLabel = L("Terminal")
            for pane in session.panes {
                let space = spacesByID[pane.workspace]?.label ?? ""
                let main = pane.agent == nil
                    ? DisplayTitle.terminal(pane, fallback: terminalLabel)
                    : DisplayTitle.pane(pane, tab: tabsByID[pane.tab], fallback: terminalLabel)
                let context = DisplayTitle.detail([space == main ? nil : space, devices.count > 1 ? device.displayName : nil])
                var identity: [String] = []
                for part in [main, pane.terminalTitle, pane.cwd, space, device.displayName].compactMap({ $0 }) where !part.isEmpty && !identity.contains(part) { identity.append(part) }
                result[PaneKey(device: device.id, pane: pane.id)] = PaneTitle(main: main, context: context, identity: identity.joined(separator: "\n"))
            }
        }
        paneTitlesCache = result
        paneTitlesCacheRevision = paneTitlesRevision
        paneTitlesCacheLanguage = language
        return result
    }
    func renameTab(_ id: String) {
        guard let device = selectedDevice, let tab = sessions[device]?.tabs.first(where: { $0.id == id }) else { return }
        requestRename(device: device, target: .tab(id: id, space: tab.workspace), current: tab.label)
    }
    func requestRename(device: String, target: RenameTarget, current: String) {
        guard renameRequest == nil, target.exists(in: sessions[device]),
              canAct(device: device, object: target.kind + "|" + target.id),
              let endpoint = devices.first(where: { $0.id == device })?.endpoint else { return }
        captureFocus()
        renameRequest = RenameRequest(device: device, target: target, endpoint: endpoint, current: current)
    }
    func submitRename(_ request: RenameRequest, name: String) async throws {
        guard let name = TabName.changed(name, from: request.current) else { return }
        let operation = renameQueue.enqueue { [self] in
            let key = request.device + "|" + request.target.kind + "|" + request.target.id
            guard devices.first(where: { $0.id == request.device })?.endpoint == request.endpoint,
                  request.target.exists(in: sessions[request.device]), begin(key, device: request.device) else {
                throw Failure(L("This item is no longer available. Reconnect and try again."))
            }
            defer { busy.remove(key) }
            let client = try rpc(request.device)
            let workspace: String
            switch request.target {
            case .space(let id): workspace = id
            case .tab(_, let space), .pane(_, _, let space): workspace = space
            }
            _ = try await client.call(request.target.method, request.target.parameters(name: name))
            // Only a server snapshot changes the displayed name. A failed RPC leaves it intact.
            try await refreshAfterAction(request.device, workspace: workspace, client: client)
        }
        try await operation.value
    }
    func closeTab(_ id: String) {
        if let device = selectedDevice, let tab = sessions[device]?.tabs.first(where: { $0.id == id }) {
            guard canAct(device: device, object: "tab|" + id) else { return }
            let count = sessions[device]?.panes.filter { $0.tab == id }.count ?? 0
            guard confirmClose(LF("Tab “%@”", tab.label), device: device, count: count, action: "Close Tab") else { return }
            objectAction(device: device, method: "tab.close", params: ["tab_id": .string(id)])
        }
    }

    func closeSpace(device: String, space: Item) {
        guard canAct(device: device, object: "space|" + space.id) else { return }
        guard confirmClose(LF("Space “%@”", space.label), device: device, count: sessions[device]?.panes.filter { $0.workspace == space.id }.count ?? 0, action: "Close Space") else { return }
        objectAction(device: device, method: "workspace.close", params: ["workspace_id": .string(space.id)])
    }
    func confirmClose(_ object: String, device: String, count: Int, action: String) -> Bool {
        guard canWrite(device) else { return false }
        let alert = NSAlert(); alert.messageText = LF("Close %@?", object)
        let name = devices.first { $0.id == device }?.displayName ?? device
        alert.informativeText = count == 1 ? LF("This stops the pane and its running processes on %@.", name) : LF("This stops %d panes and their running processes on %@.", count, name)
        alert.addButton(withTitle: L(action)); alert.addButton(withTitle: L("Cancel"))
        return alert.runModal() == .alertFirstButtonReturn
    }
    func objectAction(device: String, method: String, params: [String: JSON]) {
        let object = params["pane_id"]?.string.map { "pane|" + $0 } ?? params["tab_id"]?.string.map { "tab|" + $0 } ?? params["workspace_id"]?.string.map { "space|" + $0 } ?? method
        let key = device + "|" + object
        let workspace = params["workspace_id"]?.string
            ?? sessions[device]?.tabs.first { $0.id == params["tab_id"]?.string }?.workspace
            ?? sessions[device]?.panes.first { $0.id == params["pane_id"]?.string }?.workspace
        let closing: PaneKey? = (method == "pane.close" ? params["pane_id"]?.string.map { PaneKey(device: device, pane: $0) } : nil)
        guard let endpoint = devices.first(where: { $0.id == device })?.endpoint,
              let client = try? rpc(device), begin(key, device: device) else { return }
        let transport = transportIdentity(device)
        // Close: drop the local surface before the server reply so attach exit
        // text cannot flash, and expand survivors from Layout.removing.
        if let closing { detachClosedPane(closing) }
        Task { defer { busy.remove(key) }; do {
            guard canWrite(device), devices.contains(where: { $0.id == device && $0.endpoint == endpoint }),
                  transportIdentity(device) == transport else { throw CancellationError() }
            _ = try await client.call(method, params)
            guard transportIdentity(device) == transport else { throw CancellationError() }
            if let workspace, method != "workspace.move" {
                try await refreshAfterAction(device, workspace: workspace, client: client)
            } else { try await refresh(device, client: client) }
        } catch is CancellationError {
            if let closing { restoreDetachedPane(closing) }
        } catch {
            if let closing { restoreDetachedPane(closing) }
            message = error.localizedDescription
        } }
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
        guard let pane = sessions[key.device]?.panes.first(where: { $0.id == key.pane }) else { return }
        requestRename(device: key.device, target: .pane(id: key.pane, tab: pane.tab, space: pane.workspace), current: title(device: key.device, pane: pane))
    }
    func movePaneToTab(_ key: PaneKey) {
        objectAction(device: key.device, method: "pane.move", params: ["pane_id": .string(key.pane), "destination": .object(["type": .string("new_tab")]), "focus": .bool(false)])
    }
}
