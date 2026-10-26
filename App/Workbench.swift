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
                        .buttonStyle(.borderless).tint(Color(nsColor: Theme.secondary)).padding(.leading, 78).padding(.trailing, 12).frame(height: TabMetrics.barHeight)
                    HStack(spacing: 5) {
                        Button { desk.quickSpace() } label: { Label("New Space", systemImage: "plus") }.disabled(desk.creatingSpace).help(desk.creationHelp)
                        Menu { Button("New Space…") { desk.showSpaceForm() } } label: { Image(systemName: "chevron.down") }.menuIndicator(.hidden).fixedSize().accessibilityLabel("Space Options")
                        Spacer(minLength: 0)
                        Button { desk.openSearch() } label: { Image(systemName: "magnifyingglass") }.help("Search · ⌘K").accessibilityLabel("Search")
                    }.font(.system(size: 12, weight: .medium)).buttonStyle(.borderless).tint(Color(nsColor: Theme.secondary)).padding(.horizontal, 16).frame(height: 40)
                    HStack {
                        Text("Show").foregroundStyle(Color(nsColor: Theme.secondary))
                        Spacer(minLength: 4)
                        Menu {
                            Picker("Activity Filter", selection: $desk.activityFilter) {
                                ForEach(AgentActivityFilter.allCases, id: \.self) { filter in Text(L(filter.title)).tag(filter) }
                            }.pickerStyle(.inline)
                        } label: {
                            Label(L(desk.activityFilter.title), systemImage: "line.3.horizontal.decrease")
                        }.menuStyle(.borderlessButton).fixedSize()
                            .accessibilityLabel("Activity Filter").accessibilityValue(L(desk.activityFilter.title))
                            .help("Filter spaces and agents. Your current task stays visible.")
                    }.font(.system(size: 11)).padding(.horizontal, 18).frame(height: 28)
                    sidebarView
                    if !desk.statusText.isEmpty {
                        Text(desk.statusText).font(.system(size: 11, design: .monospaced)).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 14).padding(.vertical, 6).help(desk.statusText).accessibilityLabel(desk.statusText)
                    }
                    if let error = desk.configError { Label("Herdr config unavailable", systemImage: "exclamationmark.triangle").font(.caption).padding(8).help(error) }
                    HStack {
                        DeviceSwitcher()
                        Spacer(minLength: 0)
                        SettingsLink { Image(systemName: "gearshape") }.help("Settings · ⌘,").accessibilityLabel("Settings")
                    }.buttonStyle(.borderless).tint(Color(nsColor: Theme.secondary)).padding(.horizontal, 12).frame(height: 40)
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
                        Button(LocalizedStringKey(desk.zoomed ? "Restore Pane" : "Zoom Pane")) { desk.zoomed.toggle() }.disabled(desk.focused.map(desk.canZoom) != true)
                    } label: { Image(systemName: "rectangle.split.2x1") }.menuIndicator(.hidden).frame(width: 22).accessibilityLabel("Pane Layout").help("Splits require room for at least 24 columns and 6 rows per pane.")
                }.font(.system(size: 12)).buttonStyle(.borderless).tint(Color(nsColor: Theme.secondary)).padding(.trailing, 8).frame(height: TabMetrics.barHeight).background(Color(nsColor: Theme.chrome)).zIndex(1)
                Divider()
                // Each pane contributes 3pt outside its border, including the top.
                ZStack(alignment: .bottom) {
                    GeometryReader { geo in
                        TerminalCanvas(terminals: desk.canvas, focused: desk.focused, dividers: desk.dividers, setRatio: desk.setRatio, previewRatio: desk.previewRatio, titles: desk.paneTitles, close: { desk.closePane($0) }, canClose: { desk.canAct(on: $0) }, zoomed: desk.zoomed, restore: { desk.zoomed = false }, focusRevision: desk.focusRevision, minimumPaneSize: desk.minimumPaneSize, actions: WorkbenchActions(perform: command, enabled: enabled), corners: paneCorners(geo))
                    }
                    if let key = desk.focused, desk.ended.contains(key) {
                        VStack(spacing: 8) {
                            Text(desk.recoveryLabel(key)).multilineTextAlignment(.center)
                            HStack {
                                Button("Reconnect") { desk.reconnect(key) }
                                Button("Take Control…") { desk.reconnect(key, takeover: true) }
                            }.disabled(!desk.canWrite(key.device))
                        }.padding(12).background(.regularMaterial).clipShape(RoundedRectangle(cornerRadius: 8)).padding(20)
                    }
                    if desk.activeRects.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "square.stack.3d.up").font(.system(size: 28, weight: .light)).foregroundStyle(Color(nsColor: Theme.secondary))
                            if let device = unavailableDevice {
                                Text(device.displayName).font(.system(size: 17, weight: .medium)).lineLimit(2).truncationMode(.middle).multilineTextAlignment(.center).frame(maxWidth: 300).help(device.displayName)
                                ConnectionRecovery(device: device, centered: true).frame(maxWidth: 300).padding(.top, 4)
                            } else {
                                Text("Choose a Space").font(.system(size: 17, weight: .medium))
                                Text("Your spaces and agents appear in the sidebar.").font(.system(size: 12)).foregroundStyle(Color(nsColor: Theme.secondary))
                                Button("New Space…") { desk.showSpaceForm() }.padding(.top, 4)
                            }
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)

                    }
                }.background(GeometryReader { geo in Color.clear.onAppear { desk.canvasSize = geo.size }.onChange(of: geo.size) { desk.canvasSize = $1 } }).clipped().padding(PaneMetrics.edgeInset)
            }
        }.foregroundStyle(Color(nsColor: Theme.foreground)).tint(Color(nsColor: Theme.accent))
        .overlay(alignment: .leading) { if showSidebar { ResizeStrip(width: $sidebar, limits: 200...480, reset: 260).frame(width: 7).offset(x: sidebar - 3) } }
        .background(Color(nsColor: Theme.content)).background(WindowBehavior()).ignoresSafeArea(.container, edges: .top)
        .sheet(isPresented: $desk.showSearch, onDismiss: desk.restoreFocus) { Jump().environmentObject(desk).environment(\.locale, locale).background(SheetCloseHandler { desk.showSearch = false }) }
        .sheet(item: $desk.renameRequest, onDismiss: desk.restoreFocus) { request in RenameSheet(request: request).environmentObject(desk).environment(\.locale, locale) }
        .sheet(item: $desk.spaceRequest, onDismiss: desk.restoreFocus) { request in SpaceCreate(initialDevice: request.device ?? "").environmentObject(desk).environment(\.locale, locale) }
        .alert("HerdrX", isPresented: Binding(get: { desk.message != nil }, set: { if !$0 { desk.message = nil } })) { Button("OK") { desk.message = nil } } message: { Text(desk.message ?? "") }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in Theme.apply(); desk.applicationActivated(); desk.objectWillChange.send() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didHideNotification)) { _ in desk.applicationHidden() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didUnhideNotification)) { _ in desk.applicationShown() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in desk.shutdown() }
        .focusedSceneValue(\.workbenchActions, WorkbenchActions(perform: command, enabled: enabled))
    }
    private func paneCorners(_ geometry: GeometryProxy) -> PaneCorners {
        var resolvedRadii = true
        #if DEBUG
        // Exercise the macOS 26 public-inset path in the isolated native fixture.
        resolvedRadii = ProcessInfo.processInfo.environment["HERDRX_CORNER_INSETS"] != "1"
        #endif
        if #available(macOS 27.0, *), resolvedRadii, let radii = geometry.concentricCornerRadii {
            return PaneCorners(left: showSidebar ? 0 : radii.bottomLeading, right: radii.bottomTrailing)
        }
        if #available(macOS 26.0, *) {
            let insets = geometry.containerCornerInsets
            return PaneCorners(left: showSidebar ? 0 : min(insets.bottomLeading.width, insets.bottomLeading.height),
                               right: min(insets.bottomTrailing.width, insets.bottomTrailing.height))
        }
        // Older AppKit windows have a 10pt corner; subtract the existing outer gutter.
        let radius = max(0, 10 - PaneMetrics.edgeInset)
        return PaneCorners(left: showSidebar ? 0 : radius, right: radius)
    }
    private var unavailableDevice: Device? {
        let visible = desk.navigationDevices
        if let device = visible.first(where: { $0.id == desk.selectedDevice }), !desk.canWrite(device.id) { return device }
        return visible.contains(where: { desk.canWrite($0.id) }) ? nil : visible.first
    }
    var tabs: [TabEntry] {
        guard let device = desk.selectedDevice else { return [] }
        let counts = (desk.sessions[device]?.panes ?? []).reduce(into: [String: Int]()) { $0[$1.tab, default: 0] += 1 }
        return desk.orderedTabs(device: device, space: desk.selectedSpace).map { TabEntry(id: $0.id, title: $0.label, count: counts[$0.id, default: 0]) }
    }
    func reorder(_ source: String, _ insertion: Int) {
        desk.reorderTab(source, insertion: insertion)
    }

    var sidebarView: some View {
        ScrollViewReader { reader in ScrollView {
            LazyVStack(alignment: .leading, spacing: 2, pinnedViews: [.sectionHeaders]) {
                let devices = desk.navigationDevices
                ForEach(devices.filter { desk.activityFilter == .all || !desk.visibleSpaces($0.id).isEmpty || !desk.canWrite($0.id) }) { device in deviceGroup(device) }
                let visible = Set(devices.map(\.id))
                let agents = desk.sidebarAgents.filter { visible.contains($0.device) && (desk.activityMatches($0) || desk.focused == $0.id) }
                SidebarGroup(title: L("Agents"), id: "agents", empty: false) {
                    ForEach(agents) { row in agentRow(row) }
                    if agents.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(LocalizedStringKey(desk.activityFilter == .all ? "No agents reported by Herdr." : "No matching activity."))
                            if desk.activityFilter != .all { Button("Show All Activity") { desk.activityFilter = .all }.buttonStyle(.borderless) }
                        }.font(.system(size: 11)).foregroundStyle(Color(nsColor: Theme.secondary)).padding(.horizontal, 18).padding(.vertical, 8)
                    }
                }

            }.padding(.horizontal, 10).padding(.bottom, 8).background(SidebarScrollStyle())
        }.onChange(of: desk.sidebarReveal) { _, value in if let value { reader.scrollTo(value) } } }
    }
    func deviceGroup(_ device: Device) -> some View {
        SidebarGroup(title: device.displayName, id: "device-" + device.id, empty: false, status: L((desk.connections[device.id] ?? .connecting).title), statusColor: (desk.connections[device.id] ?? .connecting).color) {
            if !desk.canWrite(device.id) {
                ConnectionRecovery(device: device).padding(.horizontal, 8).padding(.vertical, 6)
            }
            let spaces = desk.sessions[device.id]?.spaces ?? []
            ForEach(desk.visibleSpaces(device.id)) { space in
                SidebarRow(selected: desk.selectedDevice == device.id && desk.selectedSpace == space.id, action: { desk.select(device: device.id, space: space.id) }, verticalPadding: 6.5) {
                    HStack(spacing: 6) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(space.label).font(.system(size: 13, weight: desk.selectedDevice == device.id && desk.selectedSpace == space.id ? .medium : .regular)).lineLimit(1)
                            let branch = desk.branchStates[device.id + "|" + space.id]
                            let path = desk.spacePath(device: device.id, space: space.id)
                            let branchName = branch.flatMap { $0.phase == .branch || $0.phase == .stale ? $0.text : nil }
                            Label(branchName ?? path.map { ($0 as NSString).lastPathComponent } ?? L("Directory"), systemImage: branch?.symbol ?? "folder").font(.system(size: 11)).foregroundStyle(Color(nsColor: desk.selectedDevice == device.id && desk.selectedSpace == space.id ? Theme.selectedSecondary : Theme.secondary)).lineLimit(1).frame(height: 13)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 18)
                        if let status = desk.attentionState.summary(device: device.id, panes: (desk.sessions[device.id]?.panes ?? []).filter { $0.workspace == space.id }) { AgentStatus(status: status, unread: status == "unread", selected: desk.selectedDevice == device.id && desk.selectedSpace == space.id) }
                    }.padding(.trailing, 22)
                }.id(device.id + "|" + space.id).help(DisplayTitle.detail([space.label, desk.spacePath(device: device.id, space: space.id), desk.branchStates[device.id + "|" + space.id]?.detail]))
                .overlay(alignment: .trailing) {
                    Button { desk.create(device: device.id, space: space.id) } label: { Image(systemName: "plus").font(.system(size: 11)).frame(width: 22, height: 28).contentShape(Rectangle()) }
                        .buttonStyle(.borderless).tint(Color(nsColor: Theme.secondary)).padding(.trailing, 5)
                        .disabled(!desk.canWrite(device.id) || desk.busy.contains(desk.creationID(device.id, space.id)))
                        .help(LF("New Terminal Tab in %@", space.label)).accessibilityLabel(LF("New Terminal Tab in %@", space.label))
                }
                .contextMenu {
                    Button("New Terminal Tab") { desk.create(device: device.id, space: space.id) }.disabled(!desk.canWrite(device.id) || desk.busy.contains(desk.creationID(device.id, space.id)))
                    Divider()
                    Button("Rename…") { desk.renameSpace(device: device.id, space: space) }.disabled(!desk.canAct(device: device.id, object: "space|" + space.id))
                    Button("Copy Directory") { if let path = desk.spacePath(device: device.id, space: space.id) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(path, forType: .string) } }.disabled(desk.spacePath(device: device.id, space: space.id) == nil)
                    let index = spaces.firstIndex { $0.id == space.id } ?? 0
                    if spaces.count > 1 {
                        Divider()
                        Button("Move Up") { moveSpace(device.id, space.id, index - 1) }.disabled(index == 0 || !desk.canAct(device: device.id, object: "space|" + space.id))
                        Button("Move Down") { moveSpace(device.id, space.id, index + 1) }.disabled(index + 1 >= spaces.count || !desk.canAct(device: device.id, object: "space|" + space.id))
                    }
                    Divider()
                    Button("Close Space…") { desk.closeSpace(device: device.id, space: space) }.disabled(!desk.canAct(device: device.id, object: "space|" + space.id))
                }
            }
            if spaces.isEmpty, desk.canWrite(device.id) { Button("Create Space…") { desk.showSpaceForm(device: device.id) }.buttonStyle(.borderless).padding(8) }
        }.contextMenu {
            Button("New Space…") { desk.showSpaceForm(device: device.id) }.disabled(!desk.canWrite(device.id))
            if desk.connections[device.id]?.issue?.canStart == true, LocalHerdrTarget(endpoint: device.endpoint) != nil {
                Button("Start Herdr") { desk.startLocalHerdr(device) }
            }
            if !desk.canWrite(device.id) {
                Button("Retry Connection") { desk.connect(device) }.disabled(desk.connections[device.id]?.isBusy == true)
            }
        }
    }
    func moveSpace(_ device: String, _ space: String, _ index: Int) { desk.objectAction(device: device, method: "workspace.move", params: ["workspace_id": .string(space), "insert_index": .number(Double(index))]) }
    func agentRow(_ row: AgentRow) -> some View {
        let selected = desk.focused == row.id
        let unread = desk.attentionState.unread.contains(row.id)
        let status = L(unread ? "Completed, unread" : row.pane.stateLabel)
        let title = DisplayTitle.agentRow(row.pane, tab: desk.sessions[row.device]?.tabs.first { $0.id == row.pane.tab }, fallback: L("Untitled Task"))
        let context = DisplayTitle.detail([desk.sessions[row.device]?.spaces.first { $0.id == row.pane.workspace }?.label, desk.deviceFilter.isEmpty && desk.navigationGroups.count > 1 ? desk.devices.first { $0.id == row.device }?.displayName : nil])
        return SidebarRow(selected: desk.focused == row.id, action: { desk.jump(row.device + "|" + row.pane.id) }, verticalPadding: 9.5, radius: 7, filledSelection: true) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) { Text(title).font(.system(size: 13)).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading); AgentStatus(status: row.pane.status, unread: unread, selected: selected).accessibilityHidden(true) }
                HStack(spacing: 5) {
                    HStack(spacing: 4) { AgentIcon(tool: row.pane.agent); Text(context).lineLimit(1) }.frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(Color(nsColor: selected ? Theme.selectedSecondary : Theme.secondary))
                    Text(unread ? L("Unread") : status).lineLimit(1).truncationMode(.tail).foregroundStyle(AgentStatus.color(row.pane.status, unread: unread, selected: selected)).frame(width: 64, alignment: .trailing).help(status)
                }.font(.system(size: 11))
            }.padding(.leading, 18)
        }.help(desk.paneHelp(row) + "\n" + status).accessibilityLabel(DisplayTitle.detail([title, row.pane.agent, context])).accessibilityValue(status).contextMenu { paneActions(row) }
    }
    @ViewBuilder func paneActions(_ row: AgentRow) -> some View {
        Button("Rename Pane…") { desk.renamePane(row.id) }.disabled(!desk.canAct(on: row.id))
        Button("Copy Directory") { desk.copyDirectory(row.id) }.disabled(row.pane.cwd == nil).help(row.pane.cwd == nil ? L("Directory is unavailable.") : row.pane.cwd ?? "")
        Divider()
        Button("Close Pane…") { desk.closePane(row.id) }.disabled(!desk.canAct(on: row.id))
    }
    func enabled(_ action: String) -> Bool {
        if desk.spaceRequest != nil || desk.renameRequest != nil || desk.showSearch { return false }
        if action == "attention" { return !desk.attentionCandidates.isEmpty }
        if action == "space" { return !desk.creatingSpace }
        if action == "terminal" || action == "tab" { return desk.canCreate }
        if action == "splitRight" { return desk.canSplit(horizontal: true) }
        if action == "splitDown" { return desk.canSplit(horizontal: false) }
        if action.hasPrefix("tab"), let number = Int(action.dropFirst(3)) { return number <= tabs.count }
        if ["close", "closePane"].contains(action) { return desk.focused.map(desk.canAct) ?? false }
        if action == "zoom" { return desk.focused.map(desk.canZoom) == true }
        if ["repair", "interrupt"].contains(action) { return desk.focused.map { desk.canWrite($0.device) && !desk.ended.contains($0) && desk.terminals[$0] != nil } == true }
        if ["left", "right", "up", "down", "resizeLeft", "resizeRight", "resizeUp", "resizeDown"].contains(action) { return desk.focused != nil }
        if action == "renameTab" { return desk.selectedDevice.map { desk.canAct(device: $0, object: "tab|" + desk.selectedTab) } == true && !tabs.isEmpty }
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
        case "renameTab": desk.renameTab(desk.selectedTab)
        case "closeTab": desk.closeTab(desk.selectedTab)
        case "attention": desk.attention()
        case "splitRight": desk.split(horizontal: true)
        case "splitDown": desk.split(horizontal: false)
        case "zoom": desk.zoomed.toggle()
        case "previous": desk.changeTab(-1)
        case "next": desk.changeTab(1)
        case "repair": if let key = desk.focused { desk.restoreInput(key) }
        case "interrupt":
            let key = desk.focused
            let alert = NSAlert(); alert.messageText = L("Interrupt the foreground task?"); alert.informativeText = L("Sends Ctrl-C, then restores input modes only after the foreground returns to the shell. Terminal history is preserved."); alert.addButton(withTitle: L("Interrupt and Repair")); alert.addButton(withTitle: L("Cancel"))
            if let key, alert.runModal() == .alertFirstButtonReturn { desk.restoreInput(key, interrupt: true) }
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
        // The body reads the result list for rows, height, onChange and its
        // empty state; query the index once per evaluation instead of per use.
        let results = desk.search.query(query)
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
                                Group {
                                    if let agent = pane?.agent { AgentIcon(tool: agent, size: 14) }
                                    else { Image(systemName: desk.isCommand(id) ? "command" : row.pane != nil || row.tab != nil ? "terminal" : "square.stack.3d.up").foregroundStyle(.secondary) }
                                }.frame(width: 20).accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 1) { Text(row.label).foregroundStyle(Color(nsColor: selection.id == id ? Theme.selectedText : Theme.foreground)).lineLimit(1); Text(row.detail).font(.system(size: 10.5)).foregroundStyle(Color(nsColor: selection.id == id ? Theme.selectedSecondary : Theme.secondary)).lineLimit(1) }
                                Spacer(minLength: 0)
                                if let pane, let device = row.device, pane.agent != nil { AgentStatus(status: pane.status, unread: desk.attentionState.unread.contains(PaneKey(device: device, pane: pane.id))) }
                            }.padding(.horizontal, 10).frame(height: 36).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle()).background(selection.id == id ? Color(nsColor: Theme.accentWash) : .clear, in: RoundedRectangle(cornerRadius: 6))
                        }.buttonStyle(.plain).disabled(!desk.valid(row)).onHover { if $0 { selection.choose(id) } }.id(id).help(row.label + "\n" + row.detail).accessibilityAddTraits(selection.id == id ? .isSelected : [])
                    } }
                    if results.isEmpty { Text("No matching spaces, terminals, agents or commands").foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(12) }
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
