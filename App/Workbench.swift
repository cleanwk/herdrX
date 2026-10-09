import SwiftUI
import AppKit
import HerdCore

struct Workbench: View {
    @EnvironmentObject var desk: Desk
    @State private var sidebar: CGFloat = 260
    @State private var baseWidth: CGFloat = 260
    @State private var newAgent = false
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("Herd-X").font(.headline).padding(.leading, 80)
                Spacer()
                Button { desk.showSearch = true } label: { Label("Jump", systemImage: "magnifyingglass") }.help("Jump to a pane · ⌘K")
                Menu { ForEach(["codex", "claude", "pi", "cursor"], id: \.self) { agent in Button(agent) { desk.create(agent: agent) } }; Divider(); Button("New Shell") { desk.create() }; Button("New Space") { desk.create(space: true) } } label: { Label("New", systemImage: "plus") }
                Button { desk.split(horizontal: true) } label: { Image(systemName: "rectangle.split.2x1") }.help("Split Right · ⌘D")
                SettingsLink { Image(systemName: "gearshape") }.help("Settings · ⌘,")
            }.buttonStyle(.borderless).padding(.horizontal, 16).frame(height: 48)
            Divider()
            HStack(spacing: 0) {
                sidebarView.frame(width: sidebar)
                Rectangle().fill(Color(nsColor: .separatorColor)).frame(width: 1)
                    .overlay(Rectangle().fill(.clear).frame(width: 8).contentShape(Rectangle()).gesture(DragGesture().onChanged { sidebar = min(450, max(180, baseWidth + $0.translation.width)) }.onEnded { _ in baseWidth = sidebar }).onTapGesture(count: 2) { sidebar = 260; baseWidth = 260 })
                VStack(spacing: 0) {
                    Tabs(entries: tabs, selected: desk.selectedTab, select: { id in desk.select(device: desk.selectedDevice, space: desk.selectedSpace, tab: id) }, move: reorder).frame(height: 38)
                    Divider()
                    ZStack(alignment: .bottom) {
                        TerminalCanvas(terminals: desk.canvas, focused: desk.focused, dividers: desk.dividers, setRatio: desk.setRatio)
                        if let key = desk.focused, desk.ended.contains(key) {
                            HStack { Text("Terminal detached or exited"); Button("Reconnect") { desk.ended.remove(key); desk.terminals[key]?.restart() } }.padding(12).background(.regularMaterial).clipShape(RoundedRectangle(cornerRadius: 8)).padding(20)
                        }
                        if desk.activeRects.isEmpty {
                            ContentUnavailableView { Label("No active terminal", systemImage: "terminal") } description: { Text("Choose a space or open a local shell.") } actions: { Button("Open Shell") { desk.newShell() } }
                        }
                    }
                }
            }
            Divider()
            HStack(spacing: 8) {
                Circle().fill(desk.currentDevice.map { desk.connections[$0.id] == "Connected" ? Color.green : Color.orange } ?? Color.green).frame(width: 6, height: 6)
                Text(desk.currentDevice.map { desk.connections[$0.id] ?? "Disconnected" } ?? "Local shell").lineLimit(1)
                Spacer(); Text(desk.currentPane?.agent ?? "Shell"); Text("⌘K Jump").foregroundStyle(.secondary)
            }.font(.system(size: 11)).padding(.horizontal, 14).frame(height: 26)
        }.background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $desk.showSearch) { Jump().environmentObject(desk) }
        .sheet(isPresented: $newAgent) {
            VStack(alignment: .leading, spacing: 16) { Text("New Agent").font(.title2); ForEach(["codex", "claude", "pi", "cursor"], id: \.self) { agent in Button(agent) { desk.create(agent: agent); newAgent = false } }; Button("Cancel") { newAgent = false } }.padding(24).frame(width: 320)
        }
        .alert("Herd-X", isPresented: Binding(get: { desk.message != nil }, set: { if !$0 { desk.message = nil } })) { Button("OK") { desk.message = nil } } message: { Text(desk.message ?? "") }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in desk.shutdown() }
        .background(shortcuts)
    }
    var tabs: [(String, String)] {
        if let device = desk.selectedDevice { return (desk.sessions[device]?.tabs.filter { $0.workspace == desk.selectedSpace } ?? []).map { ($0.id, $0.label) } }
        return desk.shellTabs.map { ($0.id, $0.label) }
    }
    func reorder(_ source: String, _ insertion: Int) {
        if desk.selectedDevice != nil { desk.perform { _ = try await $0.call("tab.move", ["tab_id": .string(source), "insert_index": .number(Double(insertion))]) } }
        else if let index = desk.shellTabs.firstIndex(where: { $0.id == source }) {
            let tab = desk.shellTabs.remove(at: index); desk.shellTabs.insert(tab, at: min(desk.shellTabs.count, max(0, insertion > index ? insertion - 1 : insertion)))
        }
    }
    var sidebarView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ON THIS MAC").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).padding(.horizontal, 8)
                    ForEach(desk.shellTabs) { tab in
                        Button { desk.select(device: nil, tab: tab.id) } label: { Label(tab.label, systemImage: "terminal").lineLimit(1).frame(maxWidth: .infinity, alignment: .leading).padding(8).background(desk.selectedDevice == nil && desk.selectedTab == tab.id ? Color.accentColor.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 6)) }.buttonStyle(.plain)
                    }
                }
                ForEach(desk.devices) { device in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack { Image(systemName: device.endpoint.kind == "local" ? "desktopcomputer" : "server.rack"); Text(device.displayName).fontWeight(.semibold).lineLimit(1); Spacer(); Button { desk.connect(device) } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.borderless).help("Reconnect") }.padding(8)
                        if desk.connections[device.id] != "Connected" { Text(desk.connections[device.id] ?? "Disconnected").font(.caption).foregroundStyle(.secondary).lineLimit(3).padding(.horizontal, 8) }
                        ForEach(desk.sessions[device.id]?.spaces ?? []) { space in
                            let pane = desk.sessions[device.id]?.panes.first { $0.workspace == space.id }
                            Button { desk.select(device: device.id, space: space.id) } label: {
                                VStack(alignment: .leading, spacing: 3) { Text(space.label).fontWeight(.medium).lineLimit(1); Text(space.tokens.isEmpty ? pane?.cwd ?? "Workspace" : space.tokens.keys.sorted().compactMap { space.tokens[$0]?.string }.joined(separator: " · ")).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle) }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 10).frame(height: 48).background(desk.selectedDevice == device.id && desk.selectedSpace == space.id ? Color.accentColor.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 6))
                            }.buttonStyle(.plain)
                        }
                    }
                }
                if !desk.agents.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AGENTS").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).padding(.horizontal, 8)
                        ForEach(desk.agents) { row in
                            let device = row.device, pane = row.pane
                            Button { desk.jump(device + "|" + pane.id) } label: { HStack { Circle().fill(pane.status == "blocked" ? Color.orange : pane.status == "working" ? Color.green : Color.secondary).frame(width: 6, height: 6); VStack(alignment: .leading, spacing: 2) { Text(pane.label).lineLimit(1); Text(pane.stateLabel).font(.caption).foregroundStyle(.secondary) }; Spacer() }.padding(8) }.buttonStyle(.plain)
                        }
                    }
                }
            }.padding(10)
        }
    }
    var shortcuts: some View {
        Group {
            Button("Jump") { desk.showSearch = true }.keyboardShortcut("k")
            Button("New Shell") { desk.create() }.keyboardShortcut("t")
            Button("New Agent") { newAgent = true }.keyboardShortcut("n")
            Button("New Space") { desk.create(space: true) }.keyboardShortcut("n", modifiers: [.command, .shift])
            Button("New Tab") { desk.create() }.keyboardShortcut("t", modifiers: [.command, .option])
            Button("Split Right") { desk.split(horizontal: true) }.keyboardShortcut("d")
            Button("Split Down") { desk.split(horizontal: false) }.keyboardShortcut("d", modifiers: [.command, .shift])
            Button("Close Pane") { desk.closePane() }.keyboardShortcut("w")
            Button("Zoom") { desk.zoomed.toggle() }.keyboardShortcut(.return, modifiers: [.command, .shift])
            Button("Needs Attention") { desk.attention() }.keyboardShortcut("j", modifiers: [.command, .shift])
            ForEach(1...9, id: \.self) { number in
                Button("Tab \(number)") { if tabs.indices.contains(number - 1) { desk.select(device: desk.selectedDevice, space: desk.selectedSpace, tab: tabs[number - 1].0) } }.keyboardShortcut(KeyEquivalent(Character(String(number))))
            }
            Button("Previous Tab") { desk.changeTab(-1) }.keyboardShortcut("[", modifiers: [.command, .shift])
            Button("Next Tab") { desk.changeTab(1) }.keyboardShortcut("]", modifiers: [.command, .shift])
            Button("Focus Left") { desk.focusDirection("left") }.keyboardShortcut(.leftArrow, modifiers: [.command, .option])
            Button("Focus Right") { desk.focusDirection("right") }.keyboardShortcut(.rightArrow, modifiers: [.command, .option])
            Button("Focus Up") { desk.focusDirection("up") }.keyboardShortcut(.upArrow, modifiers: [.command, .option])
            Button("Focus Down") { desk.focusDirection("down") }.keyboardShortcut(.downArrow, modifiers: [.command, .option])
            Button("Resize Left") { desk.resize("left") }.keyboardShortcut(.leftArrow, modifiers: [.command, .control])
            Button("Resize Right") { desk.resize("right") }.keyboardShortcut(.rightArrow, modifiers: [.command, .control])
            Button("Resize Up") { desk.resize("up") }.keyboardShortcut(.upArrow, modifiers: [.command, .control])
            Button("Resize Down") { desk.resize("down") }.keyboardShortcut(.downArrow, modifiers: [.command, .control])
            Button("Repair Input") { if let key = desk.focused { desk.terminals[key]?.repair() } }.keyboardShortcut("r", modifiers: [.command, .shift])
        }.hidden().frame(width: 0, height: 0)
    }
}

struct Jump: View {
    @EnvironmentObject var desk: Desk
    @State private var query = ""
    @FocusState private var field: Bool
    @State private var index = 0
    var results: [String] { desk.search.query(query) }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Jump to a space, terminal or agent", text: $query).textFieldStyle(.roundedBorder).focused($field)
                .onSubmit { if results.indices.contains(index) { desk.jump(results[index]) } }
                .onChange(of: query) { index = 0 }
                .onMoveCommand { direction in if direction == .down { index = min(max(0, results.count - 1), index + 1) }; if direction == .up { index = max(0, index - 1) } }
            ScrollViewReader { reader in ScrollView { LazyVStack(alignment: .leading, spacing: 4) { ForEach(Array(results.enumerated()), id: \.element) { offset, id in
                let row = desk.jumpRows[id]
                Button { desk.jump(id) } label: { VStack(alignment: .leading) { Text(row?.label ?? id).lineLimit(1); Text(row?.detail ?? "").font(.caption).foregroundStyle(.secondary).lineLimit(1) }.frame(maxWidth: .infinity, alignment: .leading).padding(8).background(offset == index ? Color.accentColor.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 6)) }.buttonStyle(.plain).id(offset)
            }; if results.isEmpty { Text("No matching spaces or terminals").foregroundStyle(.secondary).padding(8) } } }.frame(height: 320).onChange(of: index) { reader.scrollTo(index) } }
            Button("Cancel") { desk.showSearch = false }.keyboardShortcut(.cancelAction)
        }.padding(20).frame(width: 520).onAppear { field = true }
    }
}

struct Tabs: NSViewRepresentable {
    let entries: [(String, String)]
    let selected: String
    let select: (String) -> Void
    let move: (String, Int) -> Void
    func makeNSView(context: Context) -> NSScrollView { let scroll = NSScrollView(); scroll.hasHorizontalScroller = false; scroll.drawsBackground = false; scroll.documentView = Strip(); return scroll }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let strip = scroll.documentView as? Strip else { return }
        strip.entries = entries; strip.selected = selected; strip.select = select; strip.move = move
        strip.syncButtons()
        strip.frame = NSRect(x: 0, y: 0, width: max(scroll.bounds.width, CGFloat(entries.count) * 150), height: 38); strip.needsDisplay = true
    }
    final class Strip: NSView {
        var entries: [(String, String)] = []; var selected = ""
        var select: ((String) -> Void)?; var move: ((String, Int) -> Void)?
        var source: Int?; var origin: CGFloat = 0; var dragged = false; var insertion: Int?
        var buttons: [NSButton] = []
        func syncButtons() {
            while buttons.count > entries.count { buttons.removeLast().removeFromSuperview() }
            while buttons.count < entries.count { let button = TabButton(); button.isBordered = false; button.bezelStyle = .regularSquare; button.target = self; button.action = #selector(pressed(_:)); button.lineBreakMode = .byTruncatingTail; addSubview(button); buttons.append(button) }
            for (index, button) in buttons.enumerated() {
                button.tag = index; button.title = entries[index].1
                button.font = .systemFont(ofSize: 12, weight: selected == entries[index].0 ? .semibold : .regular)
                button.frame = NSRect(x: CGFloat(index) * 150 + 4, y: 4, width: 142, height: 30)
                button.setAccessibilityLabel(entries[index].1 + (selected == entries[index].0 ? ", selected tab" : ", tab"))
                button.toolTip = entries[index].1
            }
        }
        @objc func pressed(_ sender: NSButton) { if entries.indices.contains(sender.tag) { select?(entries[sender.tag].0) } }
        final class TabButton: NSButton {
            override func mouseDown(with event: NSEvent) { (superview as? Strip)?.mouseDown(with: event) }
            override func mouseDragged(with event: NSEvent) { (superview as? Strip)?.mouseDragged(with: event) }
            override func mouseUp(with event: NSEvent) { (superview as? Strip)?.mouseUp(with: event) }
        }
        override func draw(_ dirtyRect: NSRect) {
            for (index, entry) in entries.enumerated() {
                let rect = NSRect(x: CGFloat(index) * 150 + 4, y: 4, width: 142, height: 30)
                if selected == entry.0 {
                    let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
                    NSColor.controlAccentColor.withAlphaComponent(0.14).setFill(); path.fill()
                    NSColor.controlAccentColor.withAlphaComponent(0.5).setStroke(); path.lineWidth = 0.5; path.stroke()
                }
            }
            if let insertion { NSColor.controlAccentColor.setFill(); NSBezierPath(rect: NSRect(x: CGFloat(insertion) * 150, y: 6, width: 2, height: 26)).fill() }
        }
        override func mouseDown(with event: NSEvent) { origin = convert(event.locationInWindow, from: nil).x; let index = Int(origin / 150); source = entries.indices.contains(index) ? index : nil; dragged = false }
        override func mouseDragged(with event: NSEvent) {
            let x = convert(event.locationInWindow, from: nil).x; guard abs(x - origin) > 4 || dragged else { return }; dragged = true
            insertion = min(entries.count, max(0, Int((x + 75) / 150))); needsDisplay = true
        }
        override func mouseUp(with event: NSEvent) {
            defer { source = nil; insertion = nil; needsDisplay = true }
            guard let source else { return }
            if dragged, let insertion { move?(entries[source].0, insertion) } else { select?(entries[source].0) }
        }
    }
}
