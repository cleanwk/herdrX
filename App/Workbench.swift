import SwiftUI
import AppKit
import HerdCore

private struct ScopedSpace: Identifiable { let id: String; let item: Item }

struct Workbench: View {
    @EnvironmentObject var desk: Desk
    @Environment(\.locale) private var locale
    @AppStorage("sidebarWidth") private var sidebar = 260.0
    @State private var newAgent = false
    @State private var newSpace = false
    @State private var showFiles = false
    @State private var showFileManager = false
    @AppStorage("filesWidth") private var filesWidth = 320.0
    @AppStorage("showSidebar") private var showSidebar = true
    var body: some View {
        HStack(spacing: 0) {
            if showSidebar {
                VStack(spacing: 0) {
                    HStack { Spacer(); Button { showSidebar = false } label: { Image(systemName: "sidebar.left") }.help("Toggle Sidebar · ⌘B") }
                        .buttonStyle(.borderless).padding(.leading, 78).padding(.trailing, 12).frame(height: 28)
                    HStack(spacing: 12) {
                        Menu { Button("New Agent…") { newAgent = true }; Button("New Terminal") { desk.create() }; Button("Independent Shell") { desk.newShell() }; Divider(); Button("New Space…") { newSpace = true } } label: { Label("New", systemImage: "plus") }
                        Spacer()
                        Button { desk.quickSpace() } label: { Image(systemName: "square.stack.3d.up.badge.a") }.disabled(desk.creatingSpace).help("Quick New Space · ⌘⇧N")
                        Button { desk.reindex(); desk.showSearch = true } label: { Image(systemName: "magnifyingglass") }.help("Search · ⌘K")
                    }.buttonStyle(.borderless).padding(.horizontal, 16).frame(height: 40)
                    sidebarView
                    Divider()
                    HStack {
                        Circle().fill(desk.currentDevice.map { desk.connections[$0.id] == "Connected" ? Color.green : Color.orange } ?? .green).frame(width: 6, height: 6)
                        Picker("Devices", selection: $desk.deviceFilter) { Text("All Devices").tag(""); ForEach(desk.devices) { Text($0.displayName).tag($0.id) } }.labelsHidden().help("Filter devices; manage connections in Settings")
                        SettingsLink { Image(systemName: "gearshape") }.help("Settings · ⌘,")
                    }.buttonStyle(.borderless).padding(.horizontal, 12).frame(height: 40)
                }.frame(width: sidebar)
                Rectangle().fill(Color(nsColor: .separatorColor)).frame(width: 1)
            }
            VStack(spacing: 0) {
                HStack(spacing: 4) {
                    if !showSidebar { Button { showSidebar = true } label: { Image(systemName: "sidebar.left") }.padding(.leading, 78).help("Show Sidebar · ⌘B") }
                    Tabs(scope: (desk.selectedDevice ?? "shell") + "|" + (desk.selectedSpace ?? ""), entries: tabs, selected: desk.selectedTab, select: { id in desk.select(device: desk.selectedDevice, space: desk.selectedSpace, tab: id) }, move: reorder, rename: { desk.renameTab($0) }, close: { desk.closeTab($0) })
                    Button { desk.create() } label: { Image(systemName: "plus") }.help("New Tab · ⌘⌥T")
                    Menu {
                        Button("Browse Files") { showFiles.toggle() }
                        Button("File Manager…") { showFileManager = true }
                        Divider()
                        Button("Split Right") { desk.split(horizontal: true) }.disabled(desk.focused == nil)
                        Button("Split Down") { desk.split(horizontal: false) }.disabled(desk.focused == nil)
                        Button(LocalizedStringKey(desk.zoomed ? "Restore Pane" : "Zoom Pane")) { desk.zoomed.toggle() }.disabled(desk.focused == nil)
                    } label: { Image(systemName: "rectangle.split.2x1") }.frame(width: 28)
                }.buttonStyle(.borderless).padding(.trailing, 8).frame(height: 28).zIndex(1)
                Divider()
                GeometryReader { detail in
                HStack(spacing: 0) {
                ZStack(alignment: .bottom) {
                    TerminalCanvas(terminals: desk.canvas, focused: desk.focused, dividers: desk.dividers, setRatio: desk.setRatio, previewRatio: desk.previewRatio, titles: desk.paneTitles, close: { desk.closePane($0) }, zoomed: desk.zoomed, restore: { desk.zoomed = false })
                    if let key = desk.focused, desk.ended.contains(key) {
                        HStack { Text("Terminal detached or exited"); Button("Reconnect") { desk.ended.remove(key); desk.terminals[key]?.restart() } }.padding(12).background(.regularMaterial).clipShape(RoundedRectangle(cornerRadius: 8)).padding(20)
                    }
                    if desk.activeRects.isEmpty {
                        ContentUnavailableView { Label("No active terminal", systemImage: "terminal") } description: { Text("Choose a space or open a local shell.") } actions: { Button("Open Shell") { desk.newShell() } }
                    }
                }
                if showFiles {
                    Rectangle().fill(Color(nsColor: .separatorColor)).frame(width: 1)
                    FilesPanel(endpoint: desk.currentDevice?.endpoint ?? .init(kind: "local", socketPath: ""), path: desk.currentPane?.cwd, close: { showFiles = false }).frame(width: min(filesWidth, max(240, detail.size.width * 0.6)))
                }
                }.overlay(alignment: .trailing) {
                    if showFiles { ResizeStrip(width: $filesWidth, limits: 240...max(240, detail.size.width * 0.6), direction: -1, reset: 320).frame(width: 7).offset(x: -min(filesWidth, max(240, detail.size.width * 0.6)) + 3) }
                }
                }.clipped()
            }
        }.overlay(alignment: .leading) { if showSidebar { ResizeStrip(width: $sidebar, limits: 200...480, reset: 260).frame(width: 7).offset(x: sidebar - 3) } }
        .background(Color(nsColor: Theme.content)).background(WindowBehavior()).ignoresSafeArea(.container, edges: .top)
        .sheet(isPresented: $desk.showSearch) { Jump().environmentObject(desk).environment(\.locale, locale).background(SheetCloseHandler { desk.showSearch = false }) }
        .sheet(isPresented: $newAgent) { AgentLaunch().environmentObject(desk).environment(\.locale, locale).background(SheetCloseHandler { newAgent = false }) }
        .sheet(isPresented: $showFileManager) { FileManagerSheet().environmentObject(desk).environment(\.locale, locale).background(SheetCloseHandler { showFileManager = false }) }
        .sheet(isPresented: $newSpace) { SpaceCreate().environmentObject(desk).environment(\.locale, locale).background(SheetCloseHandler { newSpace = false }) }
        .alert("HerdrX", isPresented: Binding(get: { desk.message != nil }, set: { if !$0 { desk.message = nil } })) { Button("OK") { desk.message = nil } } message: { Text(desk.message ?? "") }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in Theme.apply(); desk.objectWillChange.send() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didHideNotification)) { _ in desk.applicationHidden() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didUnhideNotification)) { _ in desk.applicationShown() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in desk.shutdown() }
        .focusedSceneValue(\.workbenchActions, WorkbenchActions(perform: command, enabled: enabled))
    }
    var tabs: [(String, String)] {
        if let device = desk.selectedDevice { return desk.orderedTabs(device: device, space: desk.selectedSpace).map { ($0.id, $0.label) } }
        return desk.shellTabs.map { ($0.id, $0.label) }
    }
    func reorder(_ source: String, _ insertion: Int) {
        if desk.selectedDevice != nil { desk.reorderTab(source, insertion: insertion) }
        else if let index = desk.shellTabs.firstIndex(where: { $0.id == source }) {
            let tab = desk.shellTabs.remove(at: index); desk.shellTabs.insert(tab, at: min(desk.shellTabs.count, max(0, insertion > index ? insertion - 1 : insertion)))
        }
    }
    var sidebarView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4, pinnedViews: [.sectionHeaders]) {
                SidebarGroup(title: "On This Mac", id: "shells", empty: desk.shellTabs.isEmpty) {
                    ForEach(desk.shellTabs) { tab in
                        SidebarRow(selected: desk.selectedDevice == nil && desk.selectedTab == tab.id, action: { desk.select(device: nil, tab: tab.id) }) {
                            Label(tab.label, systemImage: "terminal").lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                ForEach(desk.devices.filter { desk.deviceFilter.isEmpty || $0.id == desk.deviceFilter }) { device in
                    SidebarGroup(title: device.displayName, id: "device-" + device.id, empty: false) {
                        if desk.connections[device.id] != "Connected" {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(LocalizedStringKey(desk.connections[device.id] ?? "Disconnected")).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                                Button("Retry Connection") { desk.connect(device) }.buttonStyle(.borderless)
                            }.padding(8)
                        }
                        ForEach((desk.sessions[device.id]?.spaces ?? []).map { ScopedSpace(id: device.id + "|" + $0.id, item: $0) }) { scoped in
                            let space = scoped.item
                            SidebarRow(selected: desk.selectedDevice == device.id && desk.selectedSpace == space.id, action: { desk.select(device: device.id, space: space.id) }, verticalPadding: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: "folder").font(.system(size: 12)).foregroundStyle(.secondary).frame(width: 12)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(space.label).font(.system(size: 13, weight: desk.selectedDevice == device.id && desk.selectedSpace == space.id ? .medium : .regular)).lineLimit(1)
                                        Text((space.tokens["branch"]?.string ?? desk.branches[device.id + "|" + space.id]).map { $0.isEmpty ? L("Directory") : $0 } ?? " ").font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                                    }.frame(maxWidth: .infinity, alignment: .leading)
                                    if let status = desk.attentionState.summary(device: device.id, panes: (desk.sessions[device.id]?.panes ?? []).filter { $0.workspace == space.id }) { AgentStatus(status: status, unread: status == "unread") }
                                }
                            }.draggable(device.id + "|" + space.id)
                            .dropDestination(for: String.self) { items, point in
                                guard let source = items.first, source.hasPrefix(device.id + "|"), let id = source.split(separator: "|", maxSplits: 1).last.map(String.init), let spaces = desk.sessions[device.id]?.spaces, let index = spaces.firstIndex(where: { $0.id == space.id }), spaces.contains(where: { $0.id == id }) else { return false }
                                desk.objectAction(device: device.id, method: "workspace.move", params: ["workspace_id": .string(id), "insert_index": .number(Double(index + (point.y > 24 ? 1 : 0)))])
                                return true
                            }.help(space.cwd ?? desk.sessions[device.id]?.panes.first { $0.workspace == space.id }?.cwd ?? space.label)
                            .contextMenu {
                                Button("Rename…") { desk.renameSpace(device: device.id, space: space) }
                                Button("Copy Directory") { let path = space.cwd ?? desk.sessions[device.id]?.panes.first { $0.workspace == space.id }?.cwd; if let path { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(path, forType: .string) } }
                                Button("Close Space…") { desk.closeSpace(device: device.id, space: space) }
                            }
                        }
                        if (desk.sessions[device.id]?.spaces ?? []).isEmpty, desk.connections[device.id] == "Connected" { Button("Create Space…") { newSpace = true }.buttonStyle(.borderless).padding(8) }
                    }
                }
                let agents = desk.agents.filter { desk.deviceFilter.isEmpty || $0.device == desk.deviceFilter }
                SidebarGroup(title: "Agents", id: "agents", empty: agents.isEmpty) {
                    ForEach(agents) { row in
                        SidebarRow(selected: desk.focused == row.id, action: { desk.jump(row.device + "|" + row.pane.id) }, radius: 7) {
                            HStack(spacing: 6) {
                                AgentStatus(status: row.pane.status, unread: desk.attentionState.unread.contains(row.id)).frame(width: 12)
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack { Text(row.pane.label).font(.system(size: 13.5)).lineLimit(1); Spacer(minLength: 2); Text(LocalizedStringKey(row.pane.stateLabel)).font(.system(size: 11)).foregroundStyle(.secondary) }
                                    Label((row.pane.agent ?? "Agent") + " · " + (desk.sessions[row.device]?.spaces.first { $0.id == row.pane.workspace }?.label ?? "Space") + (desk.deviceFilter.isEmpty ? " · " + (desk.devices.first { $0.id == row.device }?.displayName ?? "") : ""), systemImage: AgentToolIcon.symbol(for: row.pane.agent)).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                                    let metadata = ["model", "account", "context", "quota"].compactMap { key in row.pane.tokens[key]?.string.map { String($0.prefix(120)) } }.filter { !$0.isEmpty }
                                    if !metadata.isEmpty { Text(metadata.joined(separator: " · ")).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(2) }

                                }
                            }
                        }
                    }
                }
                let terminals = desk.devices.filter { desk.deviceFilter.isEmpty || $0.id == desk.deviceFilter }.flatMap { device in (desk.sessions[device.id]?.panes ?? []).filter { $0.agent == nil && (desk.selectedSpace == nil || (device.id == desk.selectedDevice && $0.workspace == desk.selectedSpace)) }.map { AgentRow(device: device.id, pane: $0) } }
                SidebarGroup(title: "Terminals", id: "terminals", empty: terminals.isEmpty) {
                    ForEach(terminals) { row in
                        SidebarRow(selected: desk.focused == row.id, action: { desk.jump(row.device + "|" + row.pane.id) }) { Label(row.pane.label, systemImage: "terminal").lineLimit(1).frame(maxWidth: .infinity, alignment: .leading) }
                    }
                }
            }.padding(.horizontal, 10).padding(.bottom, 8)
        }
    }
    func enabled(_ action: String) -> Bool {
        let sheet = newAgent || newSpace || desk.showSearch || showFileManager
        if action == "close" { return true }
        if sheet { return false }
        if action == "attention" { return !desk.attentionCandidates.isEmpty }
        if action == "space" { return !desk.creatingSpace && desk.devices.contains { desk.connections[$0.id] == "Connected" } }
        if action.hasPrefix("tab"), let number = Int(action.dropFirst(3)) { return number <= tabs.count }
        if ["splitRight", "splitDown", "zoom", "repair", "interrupt", "closePane", "left", "right", "up", "down", "resizeLeft", "resizeRight", "resizeUp", "resizeDown"].contains(action) { return desk.focused != nil }
        if ["closeTab", "previous", "next"].contains(action) { return !tabs.isEmpty }
        return true
    }
    func command(_ action: String) {
        guard enabled(action) else { return }
        switch action {
        case "agent": newAgent = true
        case "terminal", "tab": desk.create()
        case "space": desk.quickSpace()
        case "sidebar": showSidebar.toggle()
        case "search": desk.reindex(); desk.showSearch = true
        case "files": showFiles.toggle()
        case "fileManager": showFileManager = true
        case "close":
            if newAgent { newAgent = false } else if newSpace { newSpace = false } else if desk.showSearch { desk.showSearch = false } else if showFileManager { showFileManager = false } else if desk.focused != nil { desk.closePane() } else { NSApp.keyWindow?.performClose(nil) }
        case "closePane": desk.closePane()
        case "closeTab": desk.closeTab(desk.selectedTab)
        case "attention": desk.attention()
        case "splitRight": desk.split(horizontal: true)
        case "splitDown": desk.split(horizontal: false)
        case "zoom": desk.zoomed.toggle()
        case "previous": desk.changeTab(-1)
        case "next": desk.changeTab(1)
        case "repair": if let key = desk.focused { desk.terminals[key]?.repair() }
        case "interrupt":
            let alert = NSAlert(); alert.messageText = L("Interrupt the foreground task?"); alert.informativeText = L("Sends Ctrl-C followed by stty sane to this terminal."); alert.addButton(withTitle: L("Interrupt and Repair")); alert.addButton(withTitle: L("Cancel"))
            if let key = desk.focused, alert.runModal() == .alertFirstButtonReturn { desk.terminals[key]?.interruptAndRepair() }
        case "left", "right", "up", "down": desk.focusDirection(action)
        case "resizeLeft", "resizeRight", "resizeUp", "resizeDown": desk.resize(String(action.dropFirst(6)).lowercased())
        default: if action.hasPrefix("tab"), let number = Int(action.dropFirst(3)), tabs.indices.contains(number - 1) { desk.select(device: desk.selectedDevice, space: desk.selectedSpace, tab: tabs[number - 1].0) }
        }
    }

}

struct Jump: View {
    @EnvironmentObject var desk: Desk
    @State private var query = ""
    @FocusState private var field: Bool
    @State private var index = 0
    var results: [String] { desk.search.query(query) }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Jump to a space, terminal or agent", text: $query).textFieldStyle(.roundedBorder).focused($field)
                .onSubmit { if results.indices.contains(index) { desk.jump(results[index]) } }
                .onChange(of: query) { index = 0 }
                .onMoveCommand { direction in if direction == .down { index = min(max(0, results.count - 1), index + 1) }; if direction == .up { index = max(0, index - 1) } }.frame(height: 44)
            ScrollViewReader { reader in ScrollView { LazyVStack(alignment: .leading, spacing: 0) { ForEach(Array(results.enumerated()), id: \.element) { offset, id in
                let row = desk.jumpRows[id]
                Button { desk.jump(id) } label: { HStack(spacing: 10) { Image(systemName: row?.pane != nil ? "terminal" : row?.space != nil ? "square.stack.3d.up" : "terminal").foregroundStyle(.secondary).frame(width: 22); VStack(alignment: .leading, spacing: 1) { Text(row?.label ?? id).lineLimit(1); Text(row?.detail ?? "").font(.caption).foregroundStyle(.secondary).lineLimit(1) }; Spacer(minLength: 0) }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8).frame(height: 36).background(offset == index ? Color.accentColor.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 6)) }.buttonStyle(.plain).onHover { if $0 { index = offset } }.id(offset)
            }; if results.isEmpty { Text("No matching spaces or terminals").foregroundStyle(.secondary).padding(8) } } }.frame(height: 320).onChange(of: index) { reader.scrollTo(index, anchor: .center) } }
            HStack { Text("↑ ↓ Select     ↩ Open     Esc Close").font(.caption).foregroundStyle(.secondary); Spacer(); Button("Cancel") { desk.showSearch = false }.keyboardShortcut(.cancelAction) }.frame(height: 28)
        }.padding(.horizontal, 12).frame(width: 440).onAppear { field = true }
    }
}



private struct AgentLaunch: View {
    @EnvironmentObject var desk: Desk
    @Environment(\.dismiss) private var dismiss
    @State private var device = ""
    @State private var workspace = ""
    @State private var kind = ""
    @State private var options: [(String, String)] = []
    @State private var arguments = ""
    @State private var error: String?
    @State private var loading = false
    @State private var launching = false
    var spaces: [Item] { desk.sessions[device]?.spaces ?? [] }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("New Agent", systemImage: "sparkles").font(.title2)
            Form {
                Picker("Device", selection: $device) { ForEach(desk.devices) { Text($0.displayName).tag($0.id) } }
                Picker("Space", selection: $workspace) { ForEach(spaces) { Text($0.label).tag($0.id) } }
                Picker("Agent", selection: $kind) { ForEach(options, id: \.0) { Text($0.1).tag($0.0) } }
                TextField("Arguments", text: $arguments, prompt: Text("Optional, e.g. --model 'my model'"))
            }.disabled(launching)
            if let path = spaces.first(where: { $0.id == workspace })?.cwd ?? desk.sessions[device]?.panes.first(where: { $0.workspace == workspace })?.cwd { Text(path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled) }
            if loading { HStack { ProgressView().controlSize(.small); Text("Checking available tools…").foregroundStyle(.secondary) } }
            if let error { Text(error).font(.callout).foregroundStyle(.secondary).textSelection(.enabled) }
            Text("Opens a new terminal in this space. Herdr launches the selected tool.").font(.caption).foregroundStyle(.secondary)
            HStack { Spacer(); Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction).disabled(launching); Button(LocalizedStringKey(launching ? "Launching…" : "Launch Agent")) {
                launching = true; error = nil
                Task { do { let args = try Arguments.parse(arguments); try await desk.createTab(device: device, workspace: workspace, agent: kind, args: args); dismiss() } catch { self.error = error.localizedDescription }; launching = false }
            }.keyboardShortcut(.defaultAction).disabled(loading || launching || kind.isEmpty || workspace.isEmpty || desk.connections[device] != "Connected") }
        }.padding(24).frame(width: 480)
        .onAppear { device = desk.selectedDevice ?? desk.devices.first(where: { desk.connections[$0.id] == "Connected" })?.id ?? desk.devices.first?.id ?? "" }
        .task(id: device) {
            let target = device; options = []; kind = ""; error = nil; loading = true
            workspace = (device == desk.selectedDevice ? desk.selectedSpace : nil) ?? spaces.first?.id ?? ""
            do {
                let result = try await desk.rpc(target).call("integration.list")
                guard !Task.isCancelled, device == target else { return }
                options = result["integrations"].array.filter { $0["available"] == .bool(true) }.compactMap { value in guard let id = value["target"].string else { return nil }; return (id, value["label"].string ?? id) }
                if desk.devices.first(where: { $0.id == target })?.endpoint.kind == "local" {
                    for tool in AgentSettings.tools where !(UserDefaults.standard.string(forKey: "agentCommand." + tool.0) ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !options.contains(where: { $0.0 == tool.0 }) { options.append(tool) }
                }
                kind = options.first?.0 ?? ""
                if options.isEmpty { error = "No supported tools found. Install an agent CLI on this device, then reopen this sheet." }
                if spaces.isEmpty { error = "Create a space on this device before launching an agent." }
            } catch { if !Task.isCancelled { self.error = "Cannot load agents: " + error.localizedDescription } }
            if !Task.isCancelled { loading = false }
        }
    }
}

private struct SpaceCreate: View {
    @EnvironmentObject var desk: Desk
    @Environment(\.dismiss) private var dismiss
    @State private var device = ""
    @State private var name = ""
    @State private var path = ""
    @State private var error: String?
    @State private var busy = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("New Space", systemImage: "square.stack.3d.up").font(.title2)
            Form {
                Picker("Device", selection: $device) { ForEach(desk.devices) { Text($0.displayName).tag($0.id) } }
                TextField("Name", text: $name, prompt: Text("Project name"))
                TextField("Directory", text: $path, prompt: Text("Absolute path on this device"))
            }.disabled(busy)
            Text("Herdr creates the space in an existing directory on the selected device.").font(.caption).foregroundStyle(.secondary)
            if let error { Text(error).foregroundStyle(.secondary).textSelection(.enabled) }
            if desk.connections[device] != "Connected" { Text("Connect this device in Settings before creating a space.").font(.callout).foregroundStyle(.secondary) }
            HStack { Spacer(); Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction).disabled(busy); Button(LocalizedStringKey(busy ? "Creating…" : "Create Space")) {
                busy = true; error = nil
                Task { do { try await desk.createSpace(device: device, name: name.trimmingCharacters(in: .whitespaces), cwd: path); dismiss() } catch { self.error = error.localizedDescription }; busy = false }
            }.keyboardShortcut(.defaultAction).disabled(busy || name.trimmingCharacters(in: .whitespaces).isEmpty || !path.hasPrefix("/") || path.contains(where: \.isNewline) || desk.connections[device] != "Connected") }
        }.padding(24).frame(width: 480)
        .onAppear { device = desk.selectedDevice ?? desk.devices.first(where: { desk.connections[$0.id] == "Connected" })?.id ?? desk.devices.first?.id ?? "" }
        .onChange(of: device) { _, _ in path = device == desk.selectedDevice ? desk.currentPane?.cwd ?? "" : ""; if path.isEmpty, desk.devices.first(where: { $0.id == device })?.endpoint.kind == "local" { path = NSHomeDirectory() } }
    }
}
