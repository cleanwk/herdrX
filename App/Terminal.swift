import AppKit
import SwiftUI
import GhosttyTerminal
import HerdCore

@MainActor
final class Terminal: NSObject, TerminalSurfaceLifecycleDelegate, TerminalSurfaceOpenURLDelegate {
    static let controller = TerminalController(configSource: .none, theme: TerminalTheme(light: .alabaster, dark: TerminalConfiguration { $0.withBackground("101012"); $0.withForeground("E2E2E2") }))
    let process = ByteProcess()
    let session: InMemoryTerminalSession
    let view = TerminalView(frame: .zero)
    var surface: TerminalSurface?
    var command: String
    var onExit: (() -> Void)?
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
    func repair() { session.receive(Data("\u{1b}[<u\u{1b}[=0u".utf8)); process.write(Data("\u{03}stty sane\n".utf8)) }
    func terminalDidAttachSurface(_ surface: TerminalSurface) { self.surface = surface }
    func terminalDidDetachSurface() { surface = nil }
    func terminalDidRequestOpenURL(_ url: String, kind: TerminalOpenURLKind) {
        guard let url = URL(string: url), ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return }
        NSWorkspace.shared.open(url)
    }
    func visible(_ visible: Bool) { view.visible = visible }
}

final class TerminalView: AppTerminalView {
    var onFocus: (() -> Void)?
    var visible = true {
        didSet { guard oldValue != visible else { return }; isHidden = !visible; if !visible { layer?.contents = nil }; setSurfaceVisible(visible) }
    }
    override func selectedRange() -> NSRange { hasMarkedText() ? super.selectedRange() : NSRange(location: 0, length: 0) }
    override func markedRange() -> NSRange { hasMarkedText() ? super.markedRange() : NSRange(location: 0, length: 0) }
    override func setFrameSize(_ size: NSSize) { if visible { super.setFrameSize(size) } }
    override func layout() { if visible { super.layout() } }
    override func becomeFirstResponder() -> Bool { let result = super.becomeFirstResponder(); if result { onFocus?() }; return result }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Application menu shortcuts must reach AppKit before Ghostty's bindings.
        if event.modifierFlags.intersection([.command, .control, .option, .shift]) == .command,
           [12, 43].contains(event.keyCode) { return false } // ⌘Q and ⌘,
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
    func makeNSView(context: Context) -> Canvas { Canvas() }
    func updateNSView(_ canvas: Canvas, context: Context) {
        canvas.entries = terminals; canvas.focused = focused; canvas.dividers = dividers; canvas.setRatio = setRatio; canvas.needsLayout = true; canvas.needsDisplay = true
    }
    final class Canvas: NSView {
        var entries: [(PaneKey, Terminal, CGRect)] = []
        var focused: PaneKey?
        var dividers: [Layout.Divider] = []
        var setRatio: ((Layout.Divider, Double) -> Void)?
        private var handles: [String: Handle] = [:]
        override func draw(_ dirtyRect: NSRect) {
            NSColor.separatorColor.setFill(); bounds.fill()
            if let focused, let rect = entries.first(where: { $0.0 == focused })?.2, rect.width > 0 {
                NSColor.controlAccentColor.withAlphaComponent(0.7).setStroke()
                let frame = CGRect(x: bounds.width * rect.minX + 0.5, y: bounds.height * (1 - rect.maxY) + 0.5, width: bounds.width * rect.width - 1, height: bounds.height * rect.height - 1)
                NSBezierPath(rect: frame).stroke()
            }
        }
        override func layout() {
            super.layout()
            for (key, terminal, rect) in entries {
                let visible = rect.width > 0 && rect.height > 0
                terminal.visible(visible)
                if terminal.view.superview !== self { terminal.view.removeFromSuperview(); addSubview(terminal.view) }
                if visible {
                    terminal.view.frame = CGRect(x: bounds.width * rect.minX + 1, y: bounds.height * (1 - rect.maxY) + 1, width: max(0, bounds.width * rect.width - 2), height: max(0, bounds.height * rect.height - 2))
                    if focused == key && window?.firstResponder !== terminal.view { window?.makeFirstResponder(terminal.view) }
                }
            }
            let paths = Set(dividers.map { $0.path.map { $0 ? "1" : "0" }.joined() })
            for id in Array(handles.keys) where !paths.contains(id) { handles.removeValue(forKey: id)?.removeFromSuperview() }
            for divider in dividers {
                let id = divider.path.map { $0 ? "1" : "0" }.joined()
                let handle = handles[id] ?? Handle(); handles[id] = handle
                handle.divider = divider; handle.commit = setRatio
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
            private var start: CGPoint = .zero
            private var initial: Layout.Divider?
            override func resetCursorRects() { addCursorRect(bounds, cursor: divider?.horizontal == true ? .resizeLeftRight : .resizeUpDown) }
            override func mouseDown(with event: NSEvent) { start = event.locationInWindow; initial = divider }
            override func mouseDragged(with event: NSEvent) {
                guard let initial, let parent = superview else { return }
                let delta = initial.horizontal ? (event.locationInWindow.x - start.x) / (parent.bounds.width * initial.box.width) : (start.y - event.locationInWindow.y) / (parent.bounds.height * initial.box.height)
                // Local layouts update continuously; remote layouts commit on release.
                if initial.panes.allSatisfy({ $0.device == "shell" }) { commit?(initial, min(0.9, max(0.1, initial.ratio + delta))) }
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
