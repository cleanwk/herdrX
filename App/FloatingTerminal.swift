import AppKit
import GhosttyTerminal
import HerdCore

/// Transient config commands and Herdr-owned plugin attachments use the same
/// real Ghostty/PTY byte path, without creating a second shell sidebar model.
@MainActor
final class FloatingTerminal: NSWindowController, NSWindowDelegate, TerminalSurfaceLifecycleDelegate, TerminalSurfaceCloseDelegate {
    let id = UUID()
    let process = ByteProcess()
    let session: InMemoryTerminalSession
    let terminalView = PopupTerminalView(frame: .zero)
    var didClose: (() -> Void)?
    var userClosed: (() -> Void)?
    var focusChanged: (() -> Void)?
    var exited: ((Int32) -> Void)?
    private var finished = false
    private var automaticClose = false
    init(title: String, command: String, environment: [String: String]? = nil, width: JSON = .null, height: JSON = .null) {
        let process = self.process
        session = InMemoryTerminalSession(write: { process.write($0) }, resize: { process.resize($0.columns, $0.rows) }, suppressesPixelOnlyResizes: true)
        let available = NSApp.keyWindow?.contentView?.bounds.size ?? NSSize(width: 1100, height: 740)
        func size(_ value: JSON, total: Double, cell: Double, fallback: Double, minimum: Double) -> Double {
            let result: Double
            if let cells = value.int { result = Double(cells) * cell }
            else if let string = value.string, string.hasSuffix("%"), let percent = Double(string.dropLast()) { result = total * percent / 100 }
            else { result = fallback }
            return max(minimum, min(total, result.isFinite ? result : fallback))
        }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: size(width, total: available.width, cell: 8, fallback: 800, minimum: 320), height: size(height, total: available.height, cell: 17, fallback: 460, minimum: 180)), styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        window.title = title; window.isReleasedWhenClosed = false; window.level = .floating
        window.contentMinSize = NSSize(width: 320, height: 180)
        super.init(window: window)
        window.delegate = self
        terminalView.controller = Terminal.controller; terminalView.delegate = self
        terminalView.configuration = TerminalSurfaceOptions(backend: .inMemory(session))
        terminalView.allowsRemoteScroll = true
        terminalView.onInterrupt = { process.write(Data([3])); return true }
        terminalView.frame = window.contentView!.bounds; terminalView.autoresizingMask = [.width, .height]
        window.contentView?.addSubview(terminalView)
        let session = self.session
        process.output = { [weak session] in session?.receive($0) }
        process.exited = { [weak self] status in self?.exited?(status); self?.finish() }
        window.center(); window.makeFirstResponder(terminalView)
        // Install owner callbacks before launch can finish (including exec errors).
        Task { [weak self] in guard let self, !finished else { return }; process.start(command, environment: environment) }
    }
    required init?(coder: NSCoder) { fatalError() }
    func terminalDidAttachSurface(_ surface: TerminalSurface) { terminalView.hostSurface = surface }
    func terminalDidDetachSurface() { terminalView.hostSurface = nil }
    func terminalDidClose(processAlive: Bool) { close() }
    func windowDidBecomeKey(_ notification: Notification) { focusChanged?() }
    func windowDidResignKey(_ notification: Notification) { focusChanged?() }
    func finish() { automaticClose = true; close() }
    func windowWillClose(_ notification: Notification) {
        guard !finished else { return }; finished = true
        process.stop()
        if !automaticClose { userClosed?() }
        didClose?()
    }
}

@MainActor
final class PopupTerminalView: InterruptTerminalView {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.type == .keyDown, window?.firstResponder === self,
           event.modifierFlags.intersection([.command, .control, .option, .shift]) == .command,
           event.charactersIgnoringModifiers?.lowercased() == "w" {
            window?.performClose(nil); return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
