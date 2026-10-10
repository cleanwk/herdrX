import SwiftUI
import AppKit
import HerdCore

struct Workbench: View {
    @EnvironmentObject var desk: Desk
    @Environment(\.locale) private var locale
    @AppStorage("sidebarWidth") private var sidebar = 260.0
    @AppStorage("showSidebar") private var showSidebar = true
    var body: some View {
        HStack(spacing: 0) {
            if showSidebar {
                VStack(spacing: 0) {
                    HStack { Spacer(); Button { showSidebar = false } label: { Image(systemName: "sidebar.left") }.help("Toggle Sidebar · ⌘B").accessibilityLabel("Hide Sidebar") }
                        .buttonStyle(.borderless).padding(.leading, 78).padding(.trailing, 12).frame(height: 28)
                    HStack(spacing: 5) {
                        Button { desk.quickSpace() } label: { Label("New", systemImage: "plus") }.disabled(desk.creatingSpace).help(desk.creationHelp)
                        Menu { Button("New Space with Name and Directory…") { desk.showSpaceForm() } } label: { Image(systemName: "chevron.down") }.menuIndicator(.hidden).fixedSize().accessibilityLabel("Space Options")
                        Spacer(minLength: 0)
                        Button { desk.openSearch() } label: { Image(systemName: "magnifyingglass") }.help("Search · ⌘K").accessibilityLabel("Search")
                    }.font(.system(size: 12, weight: .medium)).buttonStyle(.borderless).padding(.horizontal, 16).frame(height: 40)
                    sidebarView
                    HStack {
                        DeviceSwitcher()
                        Spacer(minLength: 0)
                        SettingsLink { Image(systemName: "gearshape") }.help("Settings · ⌘,").accessibilityLabel("Settings")
                    }.buttonStyle(.borderless).padding(.horizontal, 12).frame(height: 40)
                }.frame(width: sidebar)
                Rectangle().fill(Color(nsColor: .separatorColor)).frame(width: 1)
            }
            VStack(spacing: 0) {
                HStack(spacing: 4) {
                    if !showSidebar { Button { showSidebar = true } label: { Image(systemName: "sidebar.left") }.padding(.leading, 78).help("Show Sidebar · ⌘B").accessibilityLabel("Show Sidebar") }
                    Tabs(scope: (desk.selectedDevice ?? "") + "|" + (desk.selectedSpace ?? ""), entries: tabs, selected: desk.selectedTab, select: { id in desk.select(device: desk.selectedDevice, space: desk.selectedSpace, tab: id) }, move: reorder, rename: { desk.renameTab($0) }, close: { desk.closeTab($0) }, writable: desk.selectedDevice.map(desk.canWrite) ?? false)
                    Button { desk.create() } label: { Image(systemName: "plus") }.disabled(!desk.canCreate).help("New Terminal Tab · ⌘T").accessibilityLabel("New Terminal Tab")
                    Menu {
                        Button("Split Right") { desk.split(horizontal: true) }.disabled(!desk.canSplit(horizontal: true))
                        Button("Split Down") { desk.split(horizontal: false) }.disabled(!desk.canSplit(horizontal: false))
                        Button(LocalizedStringKey(desk.zoomed ? "Restore Pane" : "Zoom Pane")) { desk.zoomed.toggle() }.disabled(desk.focused == nil)
                    } label: { Image(systemName: "rectangle.split.2x1") }.menuIndicator(.hidden).frame(width: 22).accessibilityLabel("Pane Layout").help("Splits require room for at least 24 columns and 6 rows per pane.")
                }.font(.system(size: 12)).buttonStyle(.borderless).padding(.trailing, 8).frame(height: 28).background(Color(nsColor: Theme.chrome)).zIndex(1)
                Divider()
                ZStack(alignment: .bottom) {
                    TerminalCanvas(terminals: desk.canvas, focused: desk.focused, dividers: desk.dividers, setRatio: desk.setRatio, previewRatio: desk.previewRatio, titles: desk.paneTitles, close: { desk.closePane($0) }, zoomed: desk.zoomed, restore: { desk.zoomed = false }, focusRevision: desk.focusRevision, minimumPaneSize: desk.minimumPaneSize, actions: WorkbenchActions(perform: command, enabled: enabled), roundLeft: !showSidebar)
                    if let key = desk.focused, desk.ended.contains(key) {
                        HStack { Text(desk.recoveryLabel(key)); Button("Reconnect") { desk.reconnect(key) }.disabled(!desk.canWrite(key.device)) }.padding(12).background(.regularMaterial).clipShape(RoundedRectangle(cornerRadius: 8)).padding(20)
                    }
                    if desk.activeRects.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "square.stack.3d.up").font(.system(size: 28, weight: .light)).foregroundStyle(Color(nsColor: Theme.secondary))
                            Text("Choose a Space").font(.system(size: 17, weight: .medium))
                            Text("Your spaces and agents appear in the sidebar.").font(.system(size: 12)).foregroundStyle(Color(nsColor: Theme.secondary))
                            Button("New Space…") { desk.showSpaceForm() }.padding(.top, 4)
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)

                    }
                }.background(GeometryReader { geo in Color.clear.onAppear { desk.canvasSize = geo.size }.onChange(of: geo.size) { desk.canvasSize = $1 } }).clipped().padding(.top, 6)
            }
        }.foregroundStyle(Color(nsColor: Theme.foreground)).tint(Color(nsColor: Theme.accent))
        .overlay(alignment: .leading) { if showSidebar { ResizeStrip(width: $sidebar, limits: 200...480, reset: 260).frame(width: 7).offset(x: sidebar - 3) } }
        .background(Color(nsColor: Theme.content)).background(WindowBehavior()).ignoresSafeArea(.container, edges: .top)
        .sheet(isPresented: $desk.showSearch, onDismiss: desk.restoreFocus) { Jump().environmentObject(desk).environment(\.locale, locale).background(SheetCloseHandler { desk.showSearch = false }) }
        .sheet(item: $desk.spaceRequest, onDismiss: desk.restoreFocus) { request in SpaceCreate(initialDevice: request.device ?? "").environmentObject(desk).environment(\.locale, locale) }
        .alert("HerdrX", isPresented: Binding(get: { desk.message != nil }, set: { if !$0 { desk.message = nil } })) { Button("OK") { desk.message = nil } } message: { Text(desk.message ?? "") }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in Theme.apply(); desk.objectWillChange.send() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didHideNotification)) { _ in desk.applicationHidden() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didUnhideNotification)) { _ in desk.applicationShown() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in desk.shutdown() }
        .focusedSceneValue(\.workbenchActions, WorkbenchActions(perform: command, enabled: enabled))
    }
    var tabs: [TabEntry] {
        if let device = desk.selectedDevice { return desk.orderedTabs(device: device, space: desk.selectedSpace).map { tab in TabEntry(id: tab.id, title: tab.label, count: desk.sessions[device]?.panes.filter { $0.tab == tab.id }.count ?? 0) } }
        return []
    }
    func reorder(_ source: String, _ insertion: Int) {
        desk.reorderTab(source, insertion: insertion)
    }

    var sidebarView: some View {
        ScrollViewReader { reader in ScrollView {
            LazyVStack(alignment: .leading, spacing: 2, pinnedViews: [.sectionHeaders]) {
                ForEach(desk.devices.filter { desk.deviceFilter.isEmpty || $0.id == desk.deviceFilter }) { device in deviceGroup(device) }
                let agents = desk.agents.filter { desk.deviceFilter.isEmpty || $0.device == desk.deviceFilter }
                SidebarGroup(title: L("Agents"), id: "agents", empty: agents.isEmpty) { ForEach(agents) { row in agentRow(row) } }

            }.padding(.horizontal, 10).padding(.bottom, 8)
        }.onChange(of: desk.sidebarReveal) { _, value in if let value { reader.scrollTo(value) } } }
    }
    func deviceGroup(_ device: Device) -> some View {
        SidebarGroup(title: device.displayName, id: "device-" + device.id, empty: false, status: desk.connections[device.id] == "Connected" ? L("Connected") : L("Offline"), connected: desk.connections[device.id] == "Connected") {
            if desk.connections[device.id] != "Connected" {
                VStack(alignment: .leading, spacing: 4) {
                    if desk.sessions[device.id] != nil { Text("Cached session data · offline").font(.caption) }
                    Text(desk.connections[device.id] ?? L("Disconnected")).font(.caption).foregroundStyle(.secondary).lineLimit(2).help(desk.connections[device.id] ?? "")
                    Button("Retry Connection") { desk.connect(device) }.buttonStyle(.borderless)
                }.padding(8)
            }
            let spaces = desk.sessions[device.id]?.spaces ?? []
            ForEach(spaces) { space in
                SidebarRow(selected: desk.selectedDevice == device.id && desk.selectedSpace == space.id, action: { desk.select(device: device.id, space: space.id) }, verticalPadding: 6.5) {
                    HStack(spacing: 6) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(space.label).font(.system(size: 13, weight: desk.selectedDevice == device.id && desk.selectedSpace == space.id ? .medium : .regular)).lineLimit(1)
                            let branch = desk.branchStates[device.id + "|" + space.id]
                            Label(branch?.text ?? L("Directory"), systemImage: branch?.symbol ?? "folder").font(.system(size: 11)).foregroundStyle(Color(nsColor: Theme.secondary)).lineLimit(1).frame(height: 13)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 18)
                        if let status = desk.attentionState.summary(device: device.id, panes: (desk.sessions[device.id]?.panes ?? []).filter { $0.workspace == space.id }) { AgentStatus(status: status, unread: status == "unread") }
                    }
                }.id(device.id + "|" + space.id).help(DisplayTitle.detail([space.label, desk.spacePath(device: device.id, space: space.id), desk.branchStates[device.id + "|" + space.id]?.detail]))
                .contextMenu {
                    Button("Rename…") { desk.renameSpace(device: device.id, space: space) }.disabled(!desk.canAct(device: device.id, object: "space|" + space.id))
                    Button("Copy Directory") { if let path = desk.spacePath(device: device.id, space: space.id) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(path, forType: .string) } }.disabled(desk.spacePath(device: device.id, space: space.id) == nil)
                    let index = spaces.firstIndex { $0.id == space.id } ?? 0
                    Button("Move Up") { moveSpace(device.id, space.id, index - 1) }.disabled(index == 0 || !desk.canAct(device: device.id, object: "space|" + space.id))
                    Button("Move Down") { moveSpace(device.id, space.id, index + 1) }.disabled(index + 1 >= spaces.count || !desk.canAct(device: device.id, object: "space|" + space.id))
                    Button("Close Space…") { desk.closeSpace(device: device.id, space: space) }.disabled(!desk.canAct(device: device.id, object: "space|" + space.id))
                }
            }
            if spaces.isEmpty, desk.canWrite(device.id) { Button("Create Space…") { desk.showSpaceForm(device: device.id) }.buttonStyle(.borderless).padding(8) }
        }.contextMenu {
            Button("New Space…") { desk.showSpaceForm(device: device.id) }.disabled(!desk.canWrite(device.id))
            Button("Retry Connection") { desk.connect(device) }
        }
    }
    func moveSpace(_ device: String, _ space: String, _ index: Int) { desk.objectAction(device: device, method: "workspace.move", params: ["workspace_id": .string(space), "insert_index": .number(Double(index))]) }
    func agentRow(_ row: AgentRow) -> some View {
        let unread = desk.attentionState.unread.contains(row.id)
        let context = DisplayTitle.detail([row.pane.agent, desk.sessions[row.device]?.spaces.first { $0.id == row.pane.workspace }?.label, desk.deviceFilter.isEmpty && desk.devices.count > 1 ? desk.devices.first { $0.id == row.device }?.displayName : nil])
        return SidebarRow(selected: desk.focused == row.id, action: { desk.jump(row.device + "|" + row.pane.id) }, verticalPadding: 9.5, radius: 7, filledSelection: true) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) { Text(desk.title(device: row.device, pane: row.pane)).font(.system(size: 13)).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading); AgentStatus(status: row.pane.status, unread: unread).accessibilityHidden(true) }
                HStack(spacing: 5) {
                    Label(context, systemImage: AgentToolIcon.symbol(for: row.pane.agent)).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(Color(nsColor: Theme.secondary))
                    Text(L(unread ? "Completed, unread" : row.pane.stateLabel)).lineLimit(1).foregroundStyle(AgentStatus.color(row.pane.status, unread: unread)).fixedSize(horizontal: true, vertical: false)
                }.font(.system(size: 11))
            }.padding(.leading, 18)
        }.help(desk.paneHelp(row)).contextMenu { paneActions(row) }
    }
    @ViewBuilder func paneActions(_ row: AgentRow) -> some View {
        Button("Rename Pane…") { desk.renamePane(row.id) }.disabled(!desk.canAct(on: row.id))
        Button("Copy Directory") { desk.copyDirectory(row.id) }.disabled(row.pane.cwd == nil).help(row.pane.cwd == nil ? L("Directory is unavailable.") : row.pane.cwd ?? "")
        Button("Close Pane…") { desk.closePane(row.id) }.disabled(!desk.canAct(on: row.id))
    }
    func enabled(_ action: String) -> Bool {
        if desk.spaceRequest != nil || desk.showSearch { return false }
        if action == "attention" { return !desk.attentionCandidates.isEmpty }
        if action == "space" { return !desk.creatingSpace }
        if action == "terminal" || action == "tab" { return desk.canCreate }
        if action == "splitRight" { return desk.canSplit(horizontal: true) }
        if action == "splitDown" { return desk.canSplit(horizontal: false) }
        if action.hasPrefix("tab"), let number = Int(action.dropFirst(3)) { return number <= tabs.count }
        if ["close", "closePane"].contains(action) { return desk.focused.map(desk.canAct) ?? false }
        if ["zoom", "repair", "interrupt", "left", "right", "up", "down", "resizeLeft", "resizeRight", "resizeUp", "resizeDown"].contains(action) { return desk.focused != nil }
        if action == "closeTab" { return !tabs.isEmpty && (desk.selectedDevice.map(desk.canWrite) ?? false) }
        if ["previous", "next"].contains(action) { return !tabs.isEmpty }
        return true
    }
    func command(_ action: String) {
        guard enabled(action) else { return }
        switch action {
        case "terminal", "tab": desk.create()
        case "space": desk.quickSpace()
        case "sidebar": showSidebar.toggle()
        case "search": desk.openSearch()
        case "close", "closePane": desk.closePane()
        case "closeTab": desk.closeTab(desk.selectedTab)
        case "attention": desk.attention()
        case "splitRight": desk.split(horizontal: true)
        case "splitDown": desk.split(horizontal: false)
        case "zoom": desk.zoomed.toggle()
        case "previous": desk.changeTab(-1)
        case "next": desk.changeTab(1)
        case "repair": if let key = desk.focused { desk.terminals[key]?.repair() }
        case "interrupt":
            let key = desk.focused
            let alert = NSAlert(); alert.messageText = L("Interrupt the foreground task?"); alert.informativeText = L("Sends Ctrl-C followed by stty sane to this terminal."); alert.addButton(withTitle: L("Interrupt and Repair")); alert.addButton(withTitle: L("Cancel"))
            if let key, alert.runModal() == .alertFirstButtonReturn { desk.terminals[key]?.interruptAndRepair() }
        case "left", "right", "up", "down": desk.focusDirection(action)
        case "resizeLeft", "resizeRight", "resizeUp", "resizeDown": desk.resize(String(action.dropFirst(6)).lowercased())
        default: if action.hasPrefix("tab"), let number = Int(action.dropFirst(3)), tabs.indices.contains(number - 1) { desk.select(device: desk.selectedDevice, space: desk.selectedSpace, tab: tabs[number - 1].id) }
        }
    }
}

struct Jump: View {
    @EnvironmentObject var desk: Desk
    @State private var query = ""
    @State private var selection = SearchSelection()
    @State private var keyboardTarget: String?
    var results: [String] { desk.search.query(query) }
    func open(_ id: String) { guard results.contains(id), let row = desk.jumpRows[id], desk.valid(row) else { return }; desk.focusReturn = nil; desk.jump(id) }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary).accessibilityHidden(true)
                SearchInput(text: $query, move: { step in selection.move(step, in: results); keyboardTarget = selection.id }, submit: { if let id = selection.id { open(id) } }, cancel: { desk.showSearch = false }).frame(height: 22)
                    .onChange(of: query) { selection.reset(results); keyboardTarget = selection.id }

            }.padding(.horizontal, 12).frame(height: 44)
            Divider()
            ScrollViewReader { reader in
                ScrollView { LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(results, id: \.self) { id in if let row = desk.jumpRows[id] {
                        let pane = row.device.flatMap { desk.sessions[$0]?.panes.first { $0.id == row.pane } }
                        Button { open(id) } label: {
                            HStack(spacing: 8) {
                                Image(systemName: pane?.agent != nil ? AgentToolIcon.symbol(for: pane?.agent) : row.pane != nil || row.tab != nil ? "terminal" : "square.stack.3d.up").foregroundStyle(.secondary).frame(width: 20).accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 1) { Text(row.label).lineLimit(1); Text(row.detail).font(.system(size: 10.5)).foregroundStyle(.secondary).lineLimit(1) }
                                Spacer(minLength: 0)
                                if let pane, let device = row.device, pane.agent != nil { AgentStatus(status: pane.status, unread: desk.attentionState.unread.contains(PaneKey(device: device, pane: pane.id))) }
                            }.padding(.horizontal, 10).frame(height: 36).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle()).background(selection.id == id ? Color(nsColor: Theme.selection).opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 6))
                        }.buttonStyle(.plain).onHover { if $0 { selection.choose(id) } }.id(id).help(row.label + "\n" + row.detail).accessibilityAddTraits(selection.id == id ? .isSelected : [])
                    } }
                    if results.isEmpty { Text("No matching spaces, terminals or agents").foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(12) }
                }.padding(.horizontal, 4) }.frame(height: min(320, max(44, CGFloat(results.count) * 36)))
                    .onChange(of: keyboardTarget) { _, id in if let id { reader.scrollTo(id) } }
            }
            Divider()
            HStack { Text("↑ ↓ Select     ↩ Open     Esc Close").font(.caption).foregroundStyle(.secondary); Spacer(); Button("Cancel") { desk.showSearch = false }.keyboardShortcut(.cancelAction) }.padding(.horizontal, 12).frame(height: 28)
        }.frame(width: 440).onAppear { selection.reset(results) }.onChange(of: results) { selection.reconcile(results) }
    }
}

private struct SpaceCreate: View {
    @EnvironmentObject var desk: Desk
    @Environment(\.dismiss) private var dismiss
    let initialDevice: String
    @State private var device = ""
    @State private var name = ""
    @State private var path = ""
    @State private var error: String?
    @State private var busy = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("New Space", systemImage: "square.stack.3d.up").font(.title2)
            Form {
                Picker("Device", selection: $device) { Text("Select device").tag(""); ForEach(desk.devices) { Text($0.displayName).tag($0.id) } }
                TextField("Name", text: $name, prompt: Text("Project name"))
                TextField("Directory", text: $path, prompt: Text("Absolute path on this device"))
            }.disabled(busy)
            Text("Herdr creates the space in an existing directory on the selected device.").font(.caption).foregroundStyle(.secondary)
            if let error { Text(error).foregroundStyle(.secondary).textSelection(.enabled) }
            if !desk.canWrite(device) { Text("Connect this device in Settings before creating a space.").font(.callout).foregroundStyle(.secondary) }
            HStack { Spacer(); Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction).disabled(busy); Button(LocalizedStringKey(busy ? "Creating…" : "Create Space")) {
                guard !busy else { return }; busy = true; error = nil
                let target = device, directory = path, title = name
                Task { do { try await desk.createSpace(device: target, name: title, cwd: directory); desk.focusReturn = nil; dismiss() } catch { self.error = error.localizedDescription }; busy = false }
            }.keyboardShortcut(.defaultAction).disabled(busy || DisplayTitle.clean(name) == nil || !path.hasPrefix("/") || path.contains(where: \.isNewline) || !desk.canWrite(device)) }
        }.padding(24).frame(width: 480).interactiveDismissDisabled(busy).background(SheetCloseHandler { if !busy { dismiss() } })
        .onAppear { device = initialDevice; updatePath() }
        .onChange(of: device) { updatePath() }
    }
    func updatePath() { path = device == desk.selectedDevice ? desk.currentPane?.cwd ?? "" : ""; if path.isEmpty, desk.devices.first(where: { $0.id == device })?.endpoint.kind == "local" { path = NSHomeDirectory() }; error = nil }
}
