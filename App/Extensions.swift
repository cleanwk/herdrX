import SwiftUI
import HerdCore

struct ExtensionSettings: View {
    @EnvironmentObject var desk: Desk
    @State private var deviceID = ""
    @State private var installed: [ExtensionInfo] = []
    @State private var selected: String?
    @State private var logs: [JSON] = []
    @State private var error: String?
    @State private var busy = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Picker("Device", selection: $deviceID) { Text("Select device").tag(""); ForEach(desk.devices) { Text($0.displayName).tag($0.id) } }.disabled(busy)
                Button("Refresh") { Task { await refresh() } }.disabled(busy)
                if busy { ProgressView().controlSize(.small) }
            }
            if let error { Text(error).font(.caption).foregroundStyle(.secondary) }
            HSplitView {
                List(selection: $selected) { ForEach(installed) { plugin in VStack(alignment: .leading) { Text(plugin.name); Text(LocalizedStringKey(plugin.enabled ? "Enabled" : "Disabled")).font(.caption).foregroundStyle(.secondary) }.tag(plugin.id) } }.frame(minWidth: 170, maxWidth: 210)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let plugin = installed.first(where: { $0.id == selected }) {
                            Text(plugin.name).font(.title3); Text(plugin.version + " · " + plugin.description).font(.caption).foregroundStyle(.secondary)
                            ForEach(plugin.warnings, id: \.self) { Text($0).font(.caption).foregroundStyle(.orange) }
                            Toggle("Enabled in Herdr", isOn: Binding(get: { plugin.enabled }, set: { enabled in run { try await Extensions.setEnabled($0, plugin: plugin.id, enabled: enabled) } })).disabled(busy)
                            if !plugin.actions.isEmpty { Text("Actions").font(.headline) }
                            ForEach(plugin.actions, id: \.self) { action in
                                Button(action["title"].string ?? action["id"].string ?? L("Action")) { let capturedContext = context; run { rpc in
                                    _ = try await Extensions.invoke(rpc, plugin: plugin.id, action: action["id"].string ?? "", context: capturedContext)
                                } }.disabled(!plugin.enabled || busy || !available(action))
                            }
                            if !plugin.panes.isEmpty { Text("Terminal panels").font(.headline) }
                            ForEach(plugin.panes, id: \.self) { pane in
                                HStack { Text(pane["title"].string ?? L("Panel")); Spacer(); Button("Open in Tab") {
                                    let target = deviceID, workspace = desk.selectedDevice == deviceID ? desk.selectedSpace : nil, revision = desk.focusRevision
                                    run { rpc in
                                    let result = try await Extensions.open(rpc, plugin: plugin.id, entry: pane["id"].string ?? "", workspace: workspace)
                                    try await desk.refresh(target, client: rpc)
                                    guard let session = desk.sessions[target] else { return }
                                    let id = result["pane"]["pane_id"].string ?? result["plugin_pane"]["pane"]["pane_id"].string
                                    if revision == desk.focusRevision, let pane = session.panes.first(where: { $0.id == id }) { desk.select(device: target, space: pane.workspace, tab: pane.tab) }
                                    desk.reindex()
                                } }.disabled(!plugin.enabled || busy) }
                            }
                            Divider(); Text("Recent execution").font(.headline)
                            ForEach(logs, id: \.self) { log in
                                VStack(alignment: .leading, spacing: 4) { Text((log["action_id"].string ?? log["event"].string ?? "Command") + " · " + (log["status"].string ?? "")).font(.callout); if let error = log["error"].string { Text(error).font(.caption) }; if let text = log["stdout"].string, !text.isEmpty { Text(String(text.prefix(4000))).font(.system(.caption, design: .monospaced)).textSelection(.enabled) } }
                            }
                        } else { Text(LocalizedStringKey(busy ? "Loading plugins…" : deviceID.isEmpty ? "Select a device to inspect its plugins." : error != nil ? "Could not load plugins. Retry when the device is connected." : installed.isEmpty ? "No plugins found on this device. Install with herdr plugin install, then refresh." : "Choose a Herdr plugin.")).foregroundStyle(.secondary) }
                    }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Text("Herdr runs and manages extensions. HerdrX displays their actions, logs and terminal panels.").font(.caption).foregroundStyle(.secondary)
        }.padding(20).onAppear { if deviceID.isEmpty { deviceID = desk.selectedDevice ?? desk.devices.first?.id ?? "" } }
        .task(id: deviceID) { installed = []; logs = []; selected = nil; await refresh() }
        .task(id: selected) {
            await refreshLogs()
            guard selected != nil else { return }
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
                await refreshLogs()
            }
        }
    }
    var context: [String: JSON] {
        var context: [String: JSON] = ["invocation_source": .string("gui")]
        if desk.selectedDevice == deviceID {
            if let workspace = desk.selectedSpace { context["workspace_id"] = .string(workspace) }
            if !desk.selectedTab.isEmpty { context["tab_id"] = .string(desk.selectedTab) }
            if let pane = desk.currentPane { context["focused_pane_id"] = .string(pane.id); context["focused_pane_cwd"] = pane.cwd.map(JSON.string) ?? .null; context["focused_pane_agent"] = pane.agent.map(JSON.string) ?? .null }
        }
        return context
    }
    func available(_ action: JSON) -> Bool {
        let scopes = action["contexts"].array.compactMap(\.string)
        return scopes.isEmpty || scopes.contains("global") || (desk.selectedDevice == deviceID && ((scopes.contains("workspace") && desk.selectedSpace != nil) || (scopes.contains("tab") && !desk.selectedTab.isEmpty) || (scopes.contains("pane") && desk.currentPane != nil)))
    }
    func run(_ action: @escaping (RPC) async throws -> Void) {
        guard !busy, desk.canWrite(deviceID) else { return }; let id = deviceID; busy = true; error = nil
        Task { defer { busy = false }; do { try await action(desk.rpc(id)); await refresh() } catch { self.error = error.localizedDescription } }
    }
    func refresh() async {
        let id = deviceID; guard !id.isEmpty else { return }; busy = true
        do {
            let values = try await Extensions.list(desk.rpc(id))
            guard deviceID == id, !Task.isCancelled else { return }
            installed = values; error = nil; await refreshLogs()
        } catch { if deviceID == id, !Task.isCancelled { self.error = L("Plugin API unavailable on this device:") + " " + error.localizedDescription } }
        if deviceID == id { busy = false }
    }
    func refreshLogs() async {
        guard let plugin = selected else { logs = []; return }; let id = deviceID
        do {
            let values = try await desk.rpc(id).call("plugin.log.list", ["plugin_id": .string(plugin), "limit": .number(20)])["logs"].array
            if deviceID == id, selected == plugin, !Task.isCancelled { logs = values }
        } catch { if deviceID == id, selected == plugin, !Task.isCancelled { self.error = error.localizedDescription } }
    }
}
