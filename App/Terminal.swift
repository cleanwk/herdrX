import AppKit
import SwiftUI
import GhosttyTerminal
import HerdCore

@MainActor
final class Terminal: NSObject, TerminalSurfaceLifecycleDelegate, TerminalSurfaceOpenURLDelegate, TerminalSurfaceHoverLinkDelegate {
    static let controller = TerminalController(configSource: .none, theme: TerminalTheme(light: .alabaster, dark: TerminalConfiguration { $0.withBackground("101012"); $0.withForeground("E2E2E2") }))
    let process = ByteProcess()
    let session: InMemoryTerminalSession
    let view = TerminalView(frame: .zero)
    var surface: TerminalSurface?
    var command: String
    var onExit: (() -> Void)?
    private(set) var hoverURL: URL?
    init(command: String) {
        self.command = command
        let process = self.process
        session = InMemoryTerminalSession(write: { process.write($0) }, resize: { process.resize($0.columns, $0.rows) }, suppressesPixelOnlyResizes: true)
        super.init()
        view.controller = Self.controller; view.delegate = self
        view.configuration = TerminalSurfaceOptions(backend: .inMemory(session))
        let session = self.session
        process.output = { session.receive($0) }
        process.exited = { [weak self] _ in self?.onExit?() }
        view.onFocus = { [weak self] in self?.focused?() }
        process.start(command)
    }
    var focused: (() -> Void)?
    func restart() { session.receive(Data("\u{1b}[<u\u{1b}[=0u".utf8)); process.start(command) }
    func repair() { session.receive(Data("\u{1b}[<u\u{1b}[=0u".utf8)) }
    func interruptAndRepair() { repair(); process.write(Data("\u{03}stty sane\n".utf8)) }
    func terminalDidAttachSurface(_ surface: TerminalSurface) { self.surface = surface; view.hostSurface = surface }
    func terminalDidDetachSurface() { surface = nil; view.hostSurface = nil }
    func terminalDidRequestOpenURL(_ url: String, kind: TerminalOpenURLKind) {
        guard let url = URL(string: url), ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return }
        NSWorkspace.shared.open(url)
    }
    func terminalDidUpdateHoverLink(_ value: String?) {
        hoverURL = value.flatMap(URL.init(string:)).flatMap { ["http", "https"].contains($0.scheme?.lowercased() ?? "") ? $0 : nil }
    }
    func visible(_ visible: Bool) { view.visible = visible }
}

final class TerminalView: AppTerminalView {
    weak var hostSurface: TerminalSurface?
    var objectMenu: (() -> NSMenu?)?
    var pasteAttachment: (() -> Bool)?
    private var mouseOrigin: NSEvent?
    private var localSelection = false
    private var selectionTimer: Timer?
    private var edgeDirection: String?
    private func selecting(_ event: NSEvent) -> NSEvent {
        NSEvent.mouseEvent(with: event.type, location: event.locationInWindow, modifierFlags: event.modifierFlags.union(.shift), timestamp: event.timestamp, windowNumber: event.windowNumber, context: nil, eventNumber: event.eventNumber, clickCount: event.clickCount, pressure: event.pressure) ?? event
    }
    private func stopSelection() { selectionTimer?.invalidate(); selectionTimer = nil; edgeDirection = nil; mouseOrigin = nil }
    override func mouseDown(with event: NSEvent) {
        stopSelection(); mouseOrigin = event
        localSelection = UserDefaults.standard.bool(forKey: "disableMouseReporting") || event.modifierFlags.contains(.shift) || event.clickCount > 1
        super.mouseDown(with: localSelection ? selecting(event) : event)
    }
    override func mouseDragged(with event: NSEvent) {
        if !localSelection, hostSurface?.isMouseCaptured == true, let origin = mouseOrigin {
            super.mouseUp(with: event); super.mouseDown(with: selecting(origin)); localSelection = true
        }
        super.mouseDragged(with: localSelection ? selecting(event) : event)
        let point = convert(event.locationInWindow, from: nil)
        edgeDirection = point.y < 12 ? "down" : point.y > bounds.height - 12 ? "up" : nil
        if edgeDirection != nil, selectionTimer == nil {
            let timer = Timer(timeInterval: 0.06, repeats: true) { [weak self] _ in
                // This timer is registered exclusively on the main run loop below.
                MainActor.assumeIsolated {
                    guard let self else { return }
                    guard self.visible, self.window?.isKeyWindow == true, NSEvent.pressedMouseButtons & 1 != 0, let direction = self.edgeDirection else { self.stopSelection(); return }
                    guard self.hostSurface?.hasSelection() == true else { return }
                    _ = self.hostSurface?.performBindingAction("adjust_selection:" + direction)
                    _ = self.hostSurface?.performBindingAction("scroll_to_selection")
                }
            }
            selectionTimer = timer; RunLoop.main.add(timer, forMode: .common)
        } else if edgeDirection == nil { selectionTimer?.invalidate(); selectionTimer = nil }
    }
    override func mouseUp(with event: NSEvent) { super.mouseUp(with: localSelection ? selecting(event) : event); stopSelection(); localSelection = false }
    override func viewWillMove(toWindow newWindow: NSWindow?) { stopSelection(); super.viewWillMove(toWindow: newWindow) }
    override func rightMouseDown(with event: NSEvent) { stopSelection(); if let menu = objectMenu?() { NSMenu.popUpContextMenu(menu, with: event, for: self) } else { super.rightMouseDown(with: event) } }
    override func rightMouseUp(with event: NSEvent) { if objectMenu == nil { super.rightMouseUp(with: event) } }
    override func menu(for event: NSEvent) -> NSMenu? { objectMenu?() ?? super.menu(for: event) }
    var onFocus: (() -> Void)?
    var visible = true {
        didSet { guard oldValue != visible else { return }; isHidden = !visible; if !visible { stopSelection(); layer?.contents = nil }; setSurfaceVisible(visible) }
    }
    override func selectedRange() -> NSRange { hasMarkedText() ? super.selectedRange() : NSRange(location: 0, length: 0) }
    override func markedRange() -> NSRange { hasMarkedText() ? super.markedRange() : NSRange(location: 0, length: 0) }
    override func setFrameSize(_ size: NSSize) { if visible { super.setFrameSize(size) } }
    override func layout() { if visible { super.layout() } }
    override func becomeFirstResponder() -> Bool { let result = super.becomeFirstResponder(); if result { onFocus?() }; return result }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Resolve native app commands before Ghostty's default split/tab bindings.
        if event.modifierFlags.contains(.command) {
            if event.charactersIgnoringModifiers?.lowercased() == "v", pasteAttachment?() == true { return true }
            if NSApp.mainMenu?.performKeyEquivalent(with: event) == true { return true }
            if ["n", "t", "w", "d", "b", "k", "j", "r", "e", "f", "[", "]", "1", "2", "3", "4", "5", "6", "7", "8", "9"].contains(event.charactersIgnoringModifiers?.lowercased() ?? "") { return true }
        }
        return super.performKeyEquivalent(with: event)
    }
    override func keyUp(with event: NSEvent) {
        if event.modifierFlags.contains(.command) && event.keyCode == 9 { return }
        super.keyUp(with: event)
    }
}

/// Keep native surfaces mounted even while other workspaces occupy the viewport.
struct TerminalCanvas: NSViewRepresentable {
    let terminals: [(PaneKey, Terminal, CGRect)]
    let focused: PaneKey?
    let dividers: [Layout.Divider]
    let setRatio: (Layout.Divider, Double) -> Void
    let previewRatio: (Layout.Divider, Double) -> Void
    let titles: [PaneKey: String]
    let close: (PaneKey) -> Void
    let zoomed: Bool
    let restore: () -> Void
    func makeNSView(context: Context) -> Canvas { Canvas() }
    func updateNSView(_ canvas: Canvas, context: Context) {
        canvas.titles = titles; canvas.close = close; canvas.entries = terminals; canvas.focused = focused; canvas.dividers = dividers; canvas.setRatio = setRatio; canvas.previewRatio = previewRatio; canvas.zoomed = zoomed; canvas.restore = restore; canvas.needsLayout = true; canvas.needsDisplay = true
    }
    final class Canvas: NSView {
        var entries: [(PaneKey, Terminal, CGRect)] = []
        var focused: PaneKey?
        var dividers: [Layout.Divider] = []
        var setRatio: ((Layout.Divider, Double) -> Void)?
        var titles: [PaneKey: String] = [:]
        var close: ((PaneKey) -> Void)?
        var previewRatio: ((Layout.Divider, Double) -> Void)?
        var zoomed = false
        var restore: (() -> Void)?
        private var hovered: PaneKey?
        private var tracking: NSTrackingArea?
        private let restoreButton = CloseButton()
        private var closeButtons: [PaneKey: CloseButton] = [:]
        private var handles: [String: Handle] = [:]
        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let tracking { removeTrackingArea(tracking) }
            let next = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow, .inVisibleRect], owner: self)
            addTrackingArea(next); tracking = next
        }
        override func mouseMoved(with event: NSEvent) {
            let point = convert(event.locationInWindow, from: nil)
            let next = entries.first { $0.2.width > 0 && paneFrame($0.2).contains(point) }?.0
            if next != hovered { hovered = next; updateCloseButtons() }
        }
        override func mouseEntered(with event: NSEvent) { mouseMoved(with: event) }
        override func mouseExited(with event: NSEvent) { hovered = nil; updateCloseButtons() }
        private func updateCloseButtons() {
            for (key, button) in closeButtons {
                let visible = entries.contains { $0.0 == key && $0.2.width > 0 }
                button.isHidden = !visible || (hovered != key && !NSWorkspace.shared.isVoiceOverEnabled)
            }
        }
        override func draw(_ dirtyRect: NSRect) {
            Theme.content.setFill(); bounds.fill()
            for (key, _, rect) in entries where rect.width > 0 {
                var frame = paneFrame(rect).insetBy(dx: 3.5, dy: 3.5)
                // The 14pt title straddles the outline; reserve its full upper half.
                frame.size.height = max(0, frame.height - 3.5)
                let active = focused == key
                (active ? Theme.accent : NSColor.separatorColor).setStroke()
                NSBezierPath(rect: frame).stroke()
                let style = NSMutableParagraphStyle(); style.lineBreakMode = .byTruncatingTail
                let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 11, weight: active ? .semibold : .regular), .foregroundColor: active ? Theme.accent : NSColor.secondaryLabelColor, .paragraphStyle: style]
                let title = titles[key] ?? "Terminal"
                let width = min(max(0, frame.width - 50), (title as NSString).size(withAttributes: attributes).width + 12)
                let box = NSRect(x: frame.minX + 9, y: frame.maxY - 7, width: width, height: 14)
                Theme.content.setFill(); box.fill()
                (title as NSString).draw(in: box.insetBy(dx: 6, dy: 0), withAttributes: attributes)
            }
        }
        func paneFrame(_ rect: CGRect) -> CGRect { CGRect(x: bounds.width * rect.minX, y: bounds.height * (1 - rect.maxY), width: bounds.width * rect.width, height: bounds.height * rect.height) }
        final class CloseButton: NSButton {
            var invoke: (() -> Void)?
            init() { super.init(frame: .zero); image = NSImage(systemSymbolName: "xmark", accessibilityDescription: L("Close Pane")); isBordered = false; target = self; action = #selector(pressed) }
            required init?(coder: NSCoder) { fatalError() }
            @objc func pressed() { invoke?() }
        }
        override func layout() {
            super.layout()
            let keys = Set(entries.map(\.0))
            for key in Array(closeButtons.keys) where !keys.contains(key) { closeButtons.removeValue(forKey: key)?.removeFromSuperview() }
            let views = Set(entries.map { ObjectIdentifier($0.1.view) })
            for view in subviews where view is TerminalView && !views.contains(ObjectIdentifier(view)) { view.removeFromSuperview() }
            for (key, terminal, rect) in entries {
                let visible = rect.width > 0 && rect.height > 0
                terminal.visible(visible)
                if terminal.view.superview !== self { terminal.view.removeFromSuperview(); addSubview(terminal.view) }
                let button = closeButtons[key] ?? CloseButton(); closeButtons[key] = button
                if button.superview !== self { addSubview(button) }
                button.invoke = { [weak self] in self?.close?(key) }
                if visible {
                    let frame = paneFrame(rect)
                    button.frame = NSRect(x: frame.maxX - 26, y: frame.maxY - 21, width: 20, height: 20)
                    button.toolTip = L("Close") + " " + (titles[key] ?? "Pane")
                    button.setAccessibilityLabel(button.toolTip)
                    terminal.view.frame = CGRect(x: frame.minX + 4, y: frame.minY + 4, width: max(0, frame.width - 8), height: max(0, frame.height - 18))
                    if focused == key && window?.firstResponder !== terminal.view { window?.makeFirstResponder(terminal.view) }
                }
            }
            updateCloseButtons()
            if restoreButton.superview !== self { addSubview(restoreButton) }
            restoreButton.isHidden = !zoomed
            restoreButton.frame = NSRect(x: bounds.maxX - 49, y: bounds.maxY - 21, width: 20, height: 20)
            restoreButton.image = NSImage(systemSymbolName: "arrow.down.right.and.arrow.up.left", accessibilityDescription: L("Restore Pane"))
            restoreButton.toolTip = "Restore Pane · ⌘⇧Return"; restoreButton.invoke = { [weak self] in self?.restore?() }
            #if DEBUG
            if let path = ProcessInfo.processInfo.environment["HERDRX_DIAGNOSTICS"] {
                let report: [String: Any] = ["window": [window?.frame.width ?? 0, window?.frame.height ?? 0], "canvas": [bounds.width, bounds.height], "panes": entries.map { key, terminal, rect -> [String: Any] in ["device": key.device, "pane": key.pane, "surface": terminal.surface.map { String(describing: ObjectIdentifier($0)) } ?? "pending", "visible": rect.width > 0, "frame": [terminal.view.frame.minX, terminal.view.frame.minY, terminal.view.frame.width, terminal.view.frame.height]] }]
                if let data = try? JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]), let file = FileHandle(forWritingAtPath: path) { _ = try? file.seekToEnd(); try? file.write(contentsOf: data + Data("\n".utf8)); try? file.close() }
            }
            #endif
            let paths = Set(dividers.map { $0.path.map { $0 ? "1" : "0" }.joined() })
            for id in Array(handles.keys) where !paths.contains(id) { handles.removeValue(forKey: id)?.removeFromSuperview() }
            for divider in dividers {
                let id = divider.path.map { $0 ? "1" : "0" }.joined()
                let handle = handles[id] ?? Handle(); handles[id] = handle
                handle.divider = divider; handle.commit = setRatio; handle.preview = previewRatio
                if handle.superview !== self { addSubview(handle) }
                let box = divider.box
                handle.frame = divider.horizontal
                    ? CGRect(x: bounds.width * (box.minX + box.width * divider.ratio) - 3, y: bounds.height * (1 - box.maxY), width: 6, height: bounds.height * box.height)
                    : CGRect(x: bounds.width * box.minX, y: bounds.height * (1 - box.minY - box.height * divider.ratio) - 3, width: bounds.width * box.width, height: 6)
            }
        }
        final class Handle: NSView {
            var divider: Layout.Divider?
            var commit: ((Layout.Divider, Double) -> Void)?
            var preview: ((Layout.Divider, Double) -> Void)?
            private var start: CGPoint = .zero
            private var initial: Layout.Divider?
            override func resetCursorRects() { addCursorRect(bounds, cursor: divider?.horizontal == true ? .resizeLeftRight : .resizeUpDown) }
            override func mouseDown(with event: NSEvent) { start = event.locationInWindow; initial = divider }
            override func mouseDragged(with event: NSEvent) {
                guard let initial, let parent = superview else { return }
                let delta = initial.horizontal ? (event.locationInWindow.x - start.x) / (parent.bounds.width * initial.box.width) : (start.y - event.locationInWindow.y) / (parent.bounds.height * initial.box.height)
                // Local layouts update continuously; remote layouts commit on release.
                preview?(initial, min(0.9, max(0.1, initial.ratio + delta)))
            }
            override func mouseUp(with event: NSEvent) {
                defer { initial = nil }
                guard let initial, let parent = superview else { return }
                let delta = initial.horizontal ? (event.locationInWindow.x - start.x) / (parent.bounds.width * initial.box.width) : (start.y - event.locationInWindow.y) / (parent.bounds.height * initial.box.height)
                commit?(initial, min(0.9, max(0.1, initial.ratio + delta)))
            }
        }
    }
}
