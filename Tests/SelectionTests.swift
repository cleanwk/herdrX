import AppKit
import GhosttyTerminal
import Testing

// The production selection view and Theme compile unchanged in a hostless test
// bundle. Only the application-wide controller holder is supplied by the harness.
@MainActor enum Terminal {
    static let controller = TerminalController(configSource: .none)
}

@Suite(.serialized) @MainActor struct SelectionTests {
    @Test func repeatedSelectionsCopyOnlyOnRelease() async throws {
        let h = try await Harness()
        defer { h.close() }
        for reporting in [false, true] {
            for capture in [false, true] {
                h.preferences(copy: true, reporting: reporting)
                h.receive("\u{1b}[?1000l\u{1b}[?1002l\u{1b}[?1003l" + (capture ? "\u{1b}[?1000h\u{1b}[?1006h\u{1b}[>1s" : "") + Harness.text)
                for (row, columns, expected) in [(0, 9, "ALPHA_ONE"), (1, 9, "DELTA_TWO"), (2, 12, "中文选择测试")] {
                    try await Task.sleep(for: .milliseconds(550))
                    h.clipboard("sentinel")
                    h.down(row: row, column: 0.25)
                    h.drag(row: row, column: Double(columns) - 0.25)
                    #expect(NSPasteboard.general.string(forType: .string) == "sentinel")
                    h.up(row: row, column: Double(columns) - 0.25)
                    #expect(NSPasteboard.general.string(forType: .string) == expected)
                    #expect(h.view.hostSurface?.hasSelection() == false)
                }
            }
        }
    }

    @Test func capturedClickAndDragAreExclusive() async throws {
        let h = try await Harness()
        defer { h.close() }
        h.preferences(copy: true, reporting: true)
        for mode in [1000, 1002, 1003] {
            h.receive("\u{1b}[?1000l\u{1b}[?1002l\u{1b}[?1003l\u{1b}[?\(mode)h\u{1b}[?1006h" + Harness.text)
            h.output.clear()
            h.down(row: 0, column: 0.25)
            try await Task.sleep(for: .milliseconds(80))
            #expect(h.output.data.isEmpty, "Pending press reached TUI")
            h.drag(row: 0, column: 8.75)
            h.up(row: 0, column: 8.75)
            try await Task.sleep(for: .milliseconds(80))
            #expect(h.output.data.isEmpty, "Local drag reached TUI")
            #expect(NSPasteboard.general.string(forType: .string) == "ALPHA_ONE")
            h.down(row: 1, column: 0.25)
            h.up(row: 1, column: 0.25)
            try await Task.sleep(for: .milliseconds(80))
            let bytes = String(decoding: h.output.data, as: UTF8.self)
            #expect(bytes == "\u{1b}[<0;1;2M\u{1b}[<0;1;2m", "Click must deliver exactly one press/release pair: \(bytes.debugDescription)")
        }
    }

    @Test func disabledCopyCancellationAndNextAnchor() async throws {
        let h = try await Harness()
        defer { h.close() }
        h.preferences(copy: false, reporting: true)
        h.receive("\u{1b}[?1000h\u{1b}[?1006h\u{1b}[>1s" + Harness.text)
        h.clipboard("sentinel")
        h.down(row: 0, column: 0.25); h.drag(row: 0, column: 8.75); h.up(row: 0, column: 8.75)
        #expect(NSPasteboard.general.string(forType: .string) == "sentinel")
        #expect(h.view.hostSurface?.readSelection() == "ALPHA_ONE")
        try await Task.sleep(for: .milliseconds(550))
        h.down(row: 1, column: 0.25); h.drag(row: 1, column: 8.75); h.up(row: 1, column: 8.75)
        #expect(h.view.hostSurface?.readSelection() == "DELTA_TWO", "Copy-off retained an old anchor")
        #expect(h.view.copySelectedTextToPasteboard())
        #expect(NSPasteboard.general.string(forType: .string) == "DELTA_TWO")
        #expect(!h.view.copySelectedTextToPasteboard(), "Empty selection copied stale text")
        h.preferences(copy: true, reporting: true)
        h.clipboard("cancel sentinel")
        h.down(row: 0, column: 0.25); h.drag(row: 0, column: 8.75)
        h.view.isHidden = true
        h.up(row: 0, column: 8.75)
        #expect(NSPasteboard.general.string(forType: .string) == "cancel sentinel")
        h.view.isHidden = false
        try await Task.sleep(for: .milliseconds(550))
        h.down(row: 1, column: 0.25); h.drag(row: 1, column: 8.75); h.up(row: 1, column: 8.75)
        #expect(NSPasteboard.general.string(forType: .string) == "DELTA_TWO")
        h.clipboard("click sentinel")
        h.down(row: 0, column: 0.25); h.up(row: 0, column: 0.25)
        #expect(NSPasteboard.general.string(forType: .string) == "click sentinel")
    }

    @Test func realShiftLinksAndTextFidelity() async throws {
        let h = try await Harness()
        defer { h.close() }
        h.preferences(copy: false, reporting: true)
        h.receive("\u{1b}[?1000h\u{1b}[?1006h\u{1b}[>1s" + Harness.text)
        h.output.clear()
        h.down(row: 0, column: 0.25); h.drag(row: 0, column: 8.75); h.up(row: 0, column: 8.75)
        try await Task.sleep(for: .milliseconds(550))
        let end = h.point(row: 1, column: 8.75)
        h.view.mouseDown(with: h.event(.leftMouseDown, local: end, modifiers: .shift))
        h.view.mouseUp(with: h.event(.leftMouseUp, local: end, modifiers: .shift))
        #expect(h.view.hostSurface?.readSelection() == "ALPHA_ONE bravo charlie\nDELTA_TWO")
        try await Task.sleep(for: .milliseconds(80))
        #expect(h.output.data.isEmpty)

        // An OSC8 link routes to the test delegate, never NSWorkspace/network.
        let url = "https://example.com/audit?q=alpha&lang=zh"
        h.receive("\u{1b}[2J\u{1b}[H\u{1b}]8;;" + url + "\u{1b}\\LINK\u{1b}]8;;\u{1b}\\")
        try await Task.sleep(for: .milliseconds(550))
        let link = h.point(row: 0, column: 1.25)
        for _ in 0..<2 {
            // A real pointer may already be on this cell before Command is
            // pressed; the engine deduplicates repeated cursor coordinates.
            h.view.mouseMoved(with: h.event(.mouseMoved, local: link))
            h.view.mouseDown(with: h.event(.leftMouseDown, local: link, modifiers: .command))
            h.view.mouseUp(with: h.event(.leftMouseUp, local: link, modifiers: .command))
            try await Task.sleep(for: .milliseconds(550))
        }
        #expect(h.openedURLs == [url, url])
        try await Task.sleep(for: .milliseconds(80))
        #expect(h.output.data.isEmpty)

        h.preferences(copy: false, reporting: false)
        let lines = "中文 👩‍💻，句号。\r\n    indented path /tmp/a b.swift\r\nhard line"
        h.receive("\u{1b}[?1000l\u{1b}[2J\u{1b}[H" + lines)
        #expect(h.view.hostSurface?.performBindingAction("select_all") == true)
        #expect(h.view.copySelectedTextToPasteboard())
        #expect(NSPasteboard.general.string(forType: .string) == lines.replacingOccurrences(of: "\r\n", with: "\n"))
        let paste = "中文 👩‍💻\n  pasted text"
        h.receive("\u{1b}[?2004h")
        h.output.clear()
        #expect(h.view.paste(text: paste))
        try await Task.sleep(for: .milliseconds(80))
        #expect(String(decoding: h.output.data, as: UTF8.self) == "\u{1b}[200~" + paste + "\u{1b}[201~")
    }

    @Test func stationaryEdgesGrowAndCancellationStops() async throws {
        let h = try await Harness()
        defer { h.close() }
        h.preferences(copy: false, reporting: false)
        h.receive("\u{1b}[2J\u{1b}[H" + (1...180).map { "ROW_\(String(format: "%03d", $0)) 中文 selection-scroll-fixture\r\n" }.joined())
        for upward in [true, false] {
            _ = h.view.hostSurface?.performBindingAction(upward ? "scroll_to_bottom" : "scroll_to_top")
            try await Task.sleep(for: .milliseconds(550))
            h.down(row: 8, column: 4.25)
            let edge = NSPoint(x: h.cellWidth * 10, y: upward ? h.view.bounds.height - 2 : 2)
            h.view.mouseDragged(with: h.event(.leftMouseDragged, local: edge))
            let before = h.view.hostSurface?.readSelection() ?? ""
            try await Task.sleep(for: .milliseconds(1150))
            let after = h.view.hostSurface?.readSelection() ?? ""
            #expect(after.count > before.count, "Stationary \(upward ? "upper" : "lower") edge did not grow")
            if upward { h.view.mouseUp(with: h.event(.leftMouseUp, local: edge)) }
            else { NotificationCenter.default.post(name: NSWindow.didResignKeyNotification, object: h.window) }
            let stopped = h.view.hostSurface?.readSelection()
            try await Task.sleep(for: .milliseconds(200))
            #expect(h.view.hostSurface?.readSelection() == stopped, "Selection continued after release/cancel")
        }
    }

    @Test func themeRolesKeepHierarchyAndAccentIdentity() async throws {
        let h = try await Harness()
        defer { h.close() }
        let defaults = UserDefaults.standard
        for (family, _) in Theme.palettes where family != "herdr" {
            defaults.set(family, forKey: "palette")
            for dark in [false, true] {
                var normal: [NSColor]?
                var states: [NSColor]?
                for accent in Theme.accents {
                    defaults.set(accent, forKey: "accent")
                    let r = Theme.roles(dark: dark)
                    for surface in r.surfaces {
                        #expect(ThemeColors.contrast(r.foreground, surface) >= 4.499)
                        #expect(ThemeColors.contrast(r.secondary, surface) >= 4.499)
                        #expect(ThemeColors.contrast(r.accentText, surface) >= 4.499)
                    }
                    for surface in r.selectedSurfaces {
                        #expect(ThemeColors.contrast(r.selectedText, surface) >= 4.499)
                        #expect(ThemeColors.contrast(r.selectedSecondary, surface) >= 4.499)
                    }
                    if let normal { #expect(normal == [r.foreground, r.secondary, r.decoration]) }
                    normal = [r.foreground, r.secondary, r.decoration]
                    var resolvedStates: [NSColor] = []
                    NSAppearance(named: dark ? .darkAqua : .aqua)!.performAsCurrentDrawingAppearance {
                        for state in [Theme.working, Theme.success, Theme.warning, Theme.failure] {
                            let normalState = state.usingColorSpace(.sRGB)!
                            resolvedStates.append(normalState)
                            for surface in r.surfaces { #expect(ThemeColors.contrast(normalState, surface) >= 4.499) }
                            let selectedState = Theme.selectedState(state).usingColorSpace(.sRGB)!
                            for surface in r.selectedSurfaces { #expect(ThemeColors.contrast(selectedState, surface) >= 4.499) }
                        }
                    }
                    if let states { #expect(states == resolvedStates, "Accent changed semantic state colors") }
                    states = resolvedStates
                    #expect(r.foreground != r.secondary)
                    #expect(r.secondary != r.decoration)
                    #expect(r.accentWash != r.hover)
                    #expect(ThemeColors.contrast(r.onAccent, r.accentStroke) >= 4.5)
                    if family == "catppuccin", !dark, accent == "orange" {
                        #expect(r.accentStroke == Theme.color(0xdf5619))
                        #expect(ThemeColors.luminance(r.secondary) > ThemeColors.luminance(r.foreground) + 0.04)
                    }
                }
            }
        }
        // Applying preferences updates the same mounted surface and its content.
        h.receive(Harness.text)
        let surface = h.view.hostSurface
        let before = h.session.readViewportText()
        h.view.isHidden = true
        Theme.apply()
        h.view.isHidden = false
        #expect(h.view.hostSurface === surface)
        #expect(h.session.readViewportText() == before)
    }
}

private final class LockedOutput: @unchecked Sendable {
    private let lock = NSLock()
    private var bytes = Data()
    var data: Data { lock.lock(); defer { lock.unlock() }; return bytes }
    func append(_ data: Data) { lock.lock(); bytes.append(data); lock.unlock() }
    func clear() { lock.lock(); bytes.removeAll(); lock.unlock() }
}

@MainActor private final class Harness: TerminalSurfaceLifecycleDelegate, TerminalSurfaceGridResizeDelegate, TerminalSurfaceOpenURLDelegate {
    static let text = "\u{1b}[2J\u{1b}[HALPHA_ONE bravo charlie\r\nDELTA_TWO echo foxtrot\r\n中文选择测试 标点，句号。 emoji 👩‍💻 END\r\n"
    let output = LockedOutput()
    let session: InMemoryTerminalSession
    let view = SelectionTerminalView(frame: NSRect(x: 0, y: 0, width: 800, height: 400))
    let window: NSWindow
    var openedURLs: [String] = []
    private var metrics: TerminalGridMetrics?
    private let keys = ["copyOnSelect", "disableMouseReporting", "palette", "accent", "fontFamily", "fontSize"]
    private var saved: [String: Any] = [:]
    private var clipboardItems: [[NSPasteboard.PasteboardType: Data]] = []
    var cellWidth: CGFloat { CGFloat(metrics!.cellWidthPixels) / window.backingScaleFactor }
    var cellHeight: CGFloat { CGFloat(metrics!.cellHeightPixels) / window.backingScaleFactor }
    init() async throws {
        _ = NSApplication.shared
        window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 800, height: 400), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let output = output
        session = InMemoryTerminalSession(write: { output.append($0) }, resize: { _ in })
        for key in keys { if let value = UserDefaults.standard.object(forKey: key) { saved[key] = value } }
        clipboardItems = (NSPasteboard.general.pasteboardItems ?? []).map { item in
            Dictionary(uniqueKeysWithValues: item.types.compactMap { type in item.data(forType: type).map { (type, $0) } })
        }
        UserDefaults.standard.set("SF Mono", forKey: "fontFamily")
        UserDefaults.standard.set(13.5, forKey: "fontSize")
        preferences(copy: true, reporting: false)
        view.delegate = self
        view.controller = Terminal.controller
        view.configuration = TerminalSurfaceOptions(backend: .inMemory(session))
        window.contentView = view
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)
        try await Task.sleep(for: .milliseconds(250))
        _ = try #require(view.hostSurface)
        _ = try #require(metrics)
    }
    func terminalDidRequestOpenURL(_ url: String, kind: TerminalOpenURLKind) { openedURLs.append(url) }
    func terminalDidAttachSurface(_ surface: TerminalSurface) { view.hostSurface = surface }
    func terminalDidDetachSurface() { view.hostSurface = nil }
    func terminalDidResize(_ size: TerminalGridMetrics) { metrics = size }
    func preferences(copy: Bool, reporting: Bool) {
        UserDefaults.standard.set(copy, forKey: "copyOnSelect")
        UserDefaults.standard.set(!reporting, forKey: "disableMouseReporting")
        Theme.apply()
    }
    func receive(_ text: String) { session.receive(text); session.waitForPendingOutput() }
    func clipboard(_ text: String) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string) }
    // The pinned engine default is 2pt padding on each edge. Cell metrics
    // exclude that inset; include it before sending AppKit coordinates.
    func point(row: Int, column: Double) -> NSPoint { NSPoint(x: 2 + column * cellWidth, y: view.bounds.height - 2 - (Double(row) + 0.5) * cellHeight) }
    func event(_ type: NSEvent.EventType, local: NSPoint, modifiers: NSEvent.ModifierFlags = [], clicks: Int = 1) -> NSEvent {
        NSEvent.mouseEvent(with: type, location: view.convert(local, to: nil), modifierFlags: modifiers,
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
            eventNumber: 0, clickCount: clicks, pressure: type == .leftMouseUp ? 0 : 1)!
    }
    func down(row: Int, column: Double) { view.mouseDown(with: event(.leftMouseDown, local: point(row: row, column: column))) }
    func drag(row: Int, column: Double) { view.mouseDragged(with: event(.leftMouseDragged, local: point(row: row, column: column))) }
    func up(row: Int, column: Double) { view.mouseUp(with: event(.leftMouseUp, local: point(row: row, column: column))) }
    func close() {
        view.cancelSelectionGesture()
        window.orderOut(nil); view.removeFromSuperview(); window.close()
        for key in keys { UserDefaults.standard.set(saved[key], forKey: key) }
        NSPasteboard.general.clearContents()
        let items = clipboardItems.map { data in let item = NSPasteboardItem(); for (type, value) in data { item.setData(value, forType: type) }; return item }
        if !items.isEmpty { NSPasteboard.general.writeObjects(items) }
    }
}
