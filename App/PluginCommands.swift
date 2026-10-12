import Foundation
import HerdCore

struct PluginCommand: Identifiable, Equatable {
    let device: String
    let plugin: String
    let entry: JSON
    let pane: Bool
    let label: String
    let detail: String
    var entryID: String { entry["id"].string ?? "" }
    var id: String { "plugin|" + ((try? JSONEncoder().encode([device, plugin, pane ? "pane" : "action", entryID])) ?? Data()).base64EncodedString() }
}

extension Desk {
    var pluginCommands: [PluginCommand] {
        devices.flatMap { device in
            (pluginCatalogs[device.id] ?? []).filter(\.enabled).flatMap { plugin in
                plugin.actions.compactMap { entry -> PluginCommand? in
                    guard entry["id"].string != nil else { return nil }
                    return PluginCommand(device: device.id, plugin: plugin.id, entry: entry, pane: false, label: entry["title"].string ?? entry["id"].string!, detail: plugin.name + " · " + device.displayName)
                } + plugin.panes.compactMap { entry -> PluginCommand? in
                    guard entry["id"].string != nil else { return nil }
                    return PluginCommand(device: device.id, plugin: plugin.id, entry: entry, pane: true, label: entry["title"].string ?? entry["id"].string!, detail: plugin.name + " · " + device.displayName)
                }
            }
        }
    }
    var commandRows: [JumpRow] {
        herdrConfig.popups.map { JumpRow(id: $0.id, device: nil, space: nil, tab: nil, pane: nil, label: $0.title, detail: DisplayTitle.detail([L("Herdr command"), $0.key])) }
        + pluginCommands.map { JumpRow(id: $0.id, device: $0.device, space: nil, tab: nil, pane: nil, label: $0.label, detail: $0.detail) }
    }
    func isCommand(_ id: String) -> Bool { id.hasPrefix("config-popup-") || id.hasPrefix("plugin|") }
    func pluginContext(_ device: String) -> [String: JSON] {
        var value: [String: JSON] = ["invocation_source": .string("gui")]
        if selectedDevice == device {
            if let space = selectedSpace { value["workspace_id"] = .string(space) }
            if !selectedTab.isEmpty { value["tab_id"] = .string(selectedTab) }
            if let pane = currentPane {
                value["focused_pane_id"] = .string(pane.id)
                value["focused_pane_cwd"] = pane.cwd.map(JSON.string) ?? .null
                value["focused_pane_agent"] = pane.agent.map(JSON.string) ?? .null
            }
        }
        return value
    }
    func commandAvailable(_ id: String) -> Bool {
        if herdrConfig.popups.contains(where: { $0.id == id }) { return true }
        guard let command = pluginCommands.first(where: { $0.id == id }), canWrite(command.device), !busy.contains(id) else { return false }
        if command.pane { return !(sessions[command.device]?.spaces.isEmpty ?? true) }
        let scopes = command.entry["contexts"].array.compactMap(\.string), context = pluginContext(command.device)
        return scopes.isEmpty || scopes.contains("global") || (scopes.contains("workspace") && context["workspace_id"] != nil) || (scopes.contains("tab") && context["tab_id"] != nil) || (scopes.contains("pane") && context["focused_pane_id"] != nil)
    }
    func invalidatePlugins(_ id: String) {
        pluginTasks.removeValue(forKey: id)?.cancel(); pluginRequests[id] = nil
        pluginCatalogs[id] = nil; pluginErrors[id] = nil
        for (key, window) in Array(floatingPanes) where key.device == id { floatingTerminals[window]?.finish() }
    }
    func refreshPluginCatalogs() { for device in devices where canWrite(device.id) { refreshPluginCatalog(device.id) } }
    func refreshPluginCatalog(_ id: String) {
        guard pluginTasks[id] == nil, canWrite(id), let client = try? rpc(id) else { return }
        let token = UUID(); pluginRequests[id] = token
        pluginTasks[id] = Task { [weak self] in
            guard let self else { return }
            defer { if pluginRequests[id] == token { pluginTasks[id] = nil } }
            do {
                let plugins = try await Extensions.list(client)
                try Task.checkCancellation()
                guard pluginRequests[id] == token, (try? rpc(id).path) == client.path, canWrite(id) else { return }
                pluginCatalogs[id] = plugins; pluginErrors[id] = nil; reindex()
            } catch {
                guard !Task.isCancelled, pluginRequests[id] == token else { return }
                pluginCatalogs[id] = nil; pluginErrors[id] = error.localizedDescription; reindex()
            }
        }
    }
    func runCommand(_ id: String) {
        guard commandAvailable(id) else { return }
        if let popup = herdrConfig.popups.first(where: { $0.id == id }) { openConfigPopup(popup); return }
        guard let command = pluginCommands.first(where: { $0.id == id }), let device = devices.first(where: { $0.id == command.device }), let client = try? rpc(device.id) else { return }
        let context = pluginContext(device.id), request = pluginRequests[device.id], socket = attachmentSocket(device), transport = transportIdentity(device.id)
        busy.insert(id)
        Task {
            defer { busy.remove(id) }
            @MainActor func current() -> Bool { transportIdentity(device.id) == transport && canWrite(device.id) && (try? rpc(device.id).path) == client.path && devices.contains(where: { $0.id == device.id && $0.endpoint == device.endpoint }) }
            do {
                guard current() else { return }
                if command.pane {
                    // A tab placement accepts an explicit workspace and returns
                    // an attachable terminal. Popup placement exposes no pane ID.
                    let workspace = context["workspace_id"]?.string ?? sessions[device.id]?.spaces.first?.id
                    let result = try await Extensions.open(client, plugin: command.plugin, entry: command.entryID, workspace: workspace)
                    guard current() else { return }
                    let pane = result["plugin_pane"]["pane"] == .null ? result["pane"] : result["plugin_pane"]["pane"]
                    guard let paneID = pane["pane_id"].string, let terminalID = pane["terminal_id"].string else { throw Failure("Herdr did not return an attachable plugin pane.") }
                    let key = PaneKey(device: device.id, pane: paneID)
                    let attachment = TerminalAttachment.command(endpoint: device.endpoint, socket: socket, terminal: terminalID, mode: .control)
                    let window = FloatingTerminal(title: command.label + " · " + device.displayName, command: attachment)
                    window.exited = { [weak self] status in
                        if status != 0 { self?.message = L("Plugin terminal disconnected. Its Herdr tab is available to reconnect.") }
                    }
                    window.userClosed = { [weak self] in
                        guard let self, transportIdentity(device.id) == transport, canWrite(device.id), (try? rpc(device.id).path) == client.path else { return }
                        Task {
                            do {
                                let existing = try await client.call("pane.get", ["pane_id": .string(paneID)])["pane"]
                                guard self.transportIdentity(device.id) == transport, existing["terminal_id"].string == terminalID, (try? self.rpc(device.id).path) == client.path else { return }
                                _ = try await client.call("plugin.pane.close", ["pane_id": .string(paneID)])
                            } catch { if (try? self.rpc(device.id).path) == client.path { self.message = error.localizedDescription } }
                        }
                    }
                    present(window, pane: key)
                    try await refresh(device.id, client: client)
                } else { _ = try await Extensions.invoke(client, plugin: command.plugin, action: command.entryID, context: context) }
                if current(), pluginRequests[device.id] == request { refreshPluginCatalog(device.id) }
            } catch { if current() { message = error.localizedDescription } }
        }
    }
}
