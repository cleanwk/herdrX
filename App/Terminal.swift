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
    var onExit: ((Int32) -> Void)?
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
        process.exited = { [weak self] status in self?.onExit?(status) }
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
    var commands: WorkbenchActions?
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
        localSelection = (UserDefaults.standard.object(forKey: "disableMouseReporting") as? Bool ?? true) || event.modifierFlags.contains(.shift) || event.clickCount > 1
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
        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        var keys: KeyModifiers = []
        if modifiers.contains(.command) { keys.insert(.command) }; if modifiers.contains(.shift) { keys.insert(.shift) }; if modifiers.contains(.option) { keys.insert(.option) }; if modifiers.contains(.control) { keys.insert(.control) }
        if let action = WorkbenchShortcut.action(event.charactersIgnoringModifiers ?? "", modifiers: keys), let commands {
            if commands.enabled(action) { commands.perform(action) }; return true
        }
        if modifiers.contains(.command), NSApp.mainMenu?.performKeyEquivalent(with: event) == true { return true }
        return super.performKeyEquivalent(with: event)
    }

}

/// Chrome geometry is also used by split validation; terminal row capacity must agree with rendering.
enum PaneMetrics {
    static let contentInset: CGFloat = 4
    static let headerHeight: CGFloat = 24
    static let horizontalOverhead = contentInset * 2
    static let verticalOverhead = headerHeight + contentInset
}

/// Keep native surfaces mounted even while other workspaces occupy the viewport.
struct TerminalCanvas: NSViewRepresentable {
    let terminals: [(PaneKey, Terminal, CGRect)]
    let focused: PaneKey?
    let dividers: [Layout.Divider]
    let setRatio: (Layout.Divider, Double) -> Void
    let previewRatio: (Layout.Divider, Double) -> Void
    let titles: [PaneKey: PaneTitle]
    let close: (PaneKey) -> Void
    let zoomed: Bool
    let restore: () -> Void
    let focusRevision: Int
    let minimumPaneSize: CGSize
    let actions: WorkbenchActions
    let roundLeft: Bool
    func makeNSView(context: Context) -> Canvas { Canvas() }
    func updateNSView(_ canvas: Canvas, context: Context) {
        canvas.actions = actions; canvas.roundLeft = roundLeft; canvas.focusRevision = focusRevision; canvas.minimumPaneSize = minimumPaneSize
        canvas.titles = titles; canvas.close = close; canvas.entries = terminals; canvas.focused = focused; canvas.dividers = dividers; canvas.setRatio = setRatio; canvas.previewRatio = previewRatio; canvas.zoomed = zoomed; canvas.restore = restore; canvas.needsLayout = true; canvas.needsDisplay = true
    }
    final class Canvas: NSView {
        var actions: WorkbenchActions?
        var roundLeft = false
        var entries: [(PaneKey, Terminal, CGRect)] = []
        var focusRevision = 0
        private var appliedFocusRevision = -1
        var minimumPaneSize: CGSize = .zero
        private var activation: NSObjectProtocol?
        override init(frame: NSRect) {
            super.init(frame: frame)
            activation = NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { [weak self] note in
                MainActor.assumeIsolated { if let self, (note.object as? NSWindow) === self.window { self.needsDisplay = true; self.needsLayout = true } }
            }
        }
        required init?(coder: NSCoder) { fatalError() }
        deinit { if let activation { NotificationCenter.default.removeObserver(activation) } }
        var focused: PaneKey?
        var dividers: [Layout.Divider] = []
        var setRatio: ((Layout.Divider, Double) -> Void)?
        var titles: [PaneKey: PaneTitle] = [:]
        var close: ((PaneKey) -> Void)?
        var previewRatio: ((Layout.Divider, Double) -> Void)?
        var zoomed = false
        var restore: (() -> Void)?
        private var hovered: PaneKey?
        private var tracking: NSTrackingArea?
        private let restoreButton = CloseButton()
        private var closeButtons: [PaneKey: CloseButton] = [:]
        private var visibleKeys: Set<PaneKey> = []
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
                let visible = visibleKeys.contains(key)
                button.isHidden = !visible || (hovered != key && focused != key && !NSWorkspace.shared.isVoiceOverEnabled)
            }
        }
        override func draw(_ dirtyRect: NSRect) {
            Theme.content.setFill(); bounds.fill()
            for (key, _, rect) in entries where rect.width > 0 {
                var frame = paneFrame(rect).insetBy(dx: 3.5, dy: 3.5)
                // The 14pt title straddles the outline; reserve its full upper half.
                frame.size.height = max(0, frame.height - 7.5)
                let active = focused == key && window?.isKeyWindow == true
                (active ? Theme.accent : Theme.separator).setStroke()
                let corners = bottomCorners(rect)
                let border = outline(frame, left: corners.left, right: corners.right)
                border.lineWidth = 1
                border.stroke()
                let title = titles[key] ?? PaneTitle(main: L("Terminal"), context: "")
                let style = NSMutableParagraphStyle(); style.lineBreakMode = .byTruncatingTail
                let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 11, weight: active ? .semibold : .regular), .foregroundColor: active ? Theme.accent : Theme.secondary, .paragraphStyle: style]
                let contextStyle = NSMutableParagraphStyle(); contextStyle.lineBreakMode = .byTruncatingMiddle
                let secondary: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular), .foregroundColor: Theme.secondary, .paragraphStyle: contextStyle]
                let available = max(0, frame.width - (zoomed ? 82 : 56))
                let mainWidth = min(available * (title.context.isEmpty ? 1 : 0.64), (title.main as NSString).size(withAttributes: attributes).width)
                let contextWidth = min(max(0, available - mainWidth - 10), (title.context as NSString).size(withAttributes: secondary).width)
                let box = NSRect(x: frame.minX + 9, y: frame.maxY - 7, width: mainWidth + (contextWidth > 0 ? contextWidth + 10 : 0) + 8, height: 14)
                Theme.content.setFill(); box.fill()
                (title.main as NSString).draw(in: NSRect(x: box.minX + 4, y: box.minY, width: mainWidth, height: 14), withAttributes: attributes)
                if contextWidth > 0 { (title.context as NSString).draw(in: NSRect(x: box.minX + mainWidth + 14, y: box.minY, width: contextWidth, height: 14), withAttributes: secondary) }

            }
        }
        private func outline(_ rect: NSRect, left: Bool, right: Bool) -> NSBezierPath {
            let path = NSBezierPath(), l: CGFloat = left ? 10 : 0, r: CGFloat = right ? 10 : 0
            path.move(to: NSPoint(x: rect.minX, y: rect.maxY)); path.line(to: NSPoint(x: rect.maxX, y: rect.maxY))
            path.line(to: NSPoint(x: rect.maxX, y: rect.minY + r))
            path.curve(to: NSPoint(x: rect.maxX - r, y: rect.minY), controlPoint1: NSPoint(x: rect.maxX, y: rect.minY + r * 0.45), controlPoint2: NSPoint(x: rect.maxX - r * 0.45, y: rect.minY))
            path.line(to: NSPoint(x: rect.minX + l, y: rect.minY))
            path.curve(to: NSPoint(x: rect.minX, y: rect.minY + l), controlPoint1: NSPoint(x: rect.minX + l * 0.45, y: rect.minY), controlPoint2: NSPoint(x: rect.minX, y: rect.minY + l * 0.45))
            path.close(); return path
        }
        func paneFrame(_ rect: CGRect) -> CGRect { CGRect(x: bounds.width * rect.minX, y: bounds.height * (1 - rect.maxY), width: bounds.width * rect.width, height: bounds.height * rect.height) }
        private func bottomCorners(_ rect: CGRect) -> (left: Bool, right: Bool) {
            let bottom = rect.maxY > 0.999 && window?.styleMask.contains(.fullScreen) != true
            return (bottom && roundLeft && rect.minX < 0.001, bottom && rect.maxX > 0.999)
        }
        /// Small glyph, native button semantics and a stable 22pt hit target.
        final class CloseButton: NSButton {
            var invoke: (() -> Void)?
            private var hovered = false
            private var tracking: NSTrackingArea?
            init() {
                super.init(frame: .zero)
                image = NSImage(systemSymbolName: "xmark", accessibilityDescription: L("Close Pane"))
                image = image?.withSymbolConfiguration(.init(pointSize: 9, weight: .semibold))
                imagePosition = .imageOnly; isBordered = false
                setButtonType(.momentaryChange); focusRingType = .exterior
                target = self; action = #selector(pressed)
            }
            override func updateTrackingAreas() {
                super.updateTrackingAreas()
                if let tracking { removeTrackingArea(tracking) }
                let next = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self)
                tracking = next; addTrackingArea(next)
            }
            override func mouseEntered(with event: NSEvent) { hovered = true; needsDisplay = true }
            override func mouseExited(with event: NSEvent) { hovered = false; needsDisplay = true }
            override func draw(_ dirtyRect: NSRect) {
                Theme.content.setFill(); bounds.fill()
                if hovered || isHighlighted {
                    Theme.foreground.withAlphaComponent(isHighlighted ? 0.14 : 0.07).setFill()
                    NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 4, yRadius: 4).fill()
                }
                contentTintColor = hovered ? Theme.foreground : Theme.secondary
                super.draw(dirtyRect)
            }
            required init?(coder: NSCoder) { fatalError() }
            @objc func pressed() { invoke?() }
        }
        override func layout() {
            super.layout()
            visibleKeys = Set(entries.filter { $0.2.width > 0 && $0.2.height > 0 }.map(\.0))
            let keys = Set(entries.map(\.0))
            for key in Array(closeButtons.keys) where !keys.contains(key) { closeButtons.removeValue(forKey: key)?.removeFromSuperview() }
            let views = Set(entries.map { ObjectIdentifier($0.1.view) })
            for view in subviews where view is TerminalView && !views.contains(ObjectIdentifier(view)) { view.removeFromSuperview() }
            for (key, terminal, rect) in entries {
                let visible = rect.width > 0 && rect.height > 0
                terminal.view.commands = actions
                terminal.visible(visible)
                if terminal.view.superview !== self { terminal.view.removeFromSuperview(); addSubview(terminal.view) }
                let button = closeButtons[key] ?? CloseButton(); closeButtons[key] = button
                if button.superview !== self { addSubview(button) }
                button.invoke = { [weak self] in self?.close?(key) }
                if visible {
                    let frame = paneFrame(rect)
                    button.frame = NSRect(x: frame.maxX - 30, y: frame.maxY - 22, width: 22, height: 22)
                    button.toolTip = L("Close") + " " + (titles[key]?.main ?? L("Pane"))
                    terminal.view.toolTip = titles[key]?.full; terminal.view.setAccessibilityLabel(titles[key]?.full)
                    button.setAccessibilityLabel(button.toolTip)
                    let contentFrame = CGRect(x: frame.minX + PaneMetrics.contentInset, y: frame.minY + PaneMetrics.contentInset, width: max(0, frame.width - PaneMetrics.horizontalOverhead), height: max(0, frame.height - PaneMetrics.verticalOverhead))
                    if terminal.view.frame != contentFrame { terminal.view.frame = contentFrame }
                    // The opaque terminal must follow the outline, or it paints over its curved corners.
                    let corners = bottomCorners(rect)
                    terminal.view.wantsLayer = true
                    terminal.view.layer?.cornerRadius = 9.5
                    terminal.view.layer?.maskedCorners = (corners.left ? CACornerMask.layerMinXMinYCorner : []).union(corners.right ? .layerMaxXMinYCorner : [])
                    terminal.view.layer?.masksToBounds = corners.left || corners.right
                    if focused == key, appliedFocusRevision != focusRevision, window?.isKeyWindow == true, window?.attachedSheet == nil {
                        if window?.makeFirstResponder(terminal.view) == true { appliedFocusRevision = focusRevision }
                    }
                }
            }
            updateCloseButtons()
            if restoreButton.superview !== self { addSubview(restoreButton) }
            restoreButton.isHidden = !zoomed
            restoreButton.frame = NSRect(x: bounds.maxX - 56, y: bounds.maxY - 22, width: 22, height: 22)
            restoreButton.image = NSImage(systemSymbolName: "arrow.down.right.and.arrow.up.left", accessibilityDescription: L("Restore Pane"))?.withSymbolConfiguration(.init(pointSize: 10, weight: .medium))
            restoreButton.toolTip = L("Restore Pane · ⌘⇧Return"); restoreButton.invoke = { [weak self] in self?.restore?() }
            #if DEBUG
            if let path = ProcessInfo.processInfo.environment["HERDRX_DIAGNOSTICS"] {
                let report: [String: Any] = ["window": [window?.frame.width ?? 0, window?.frame.height ?? 0], "canvas": [bounds.width, bounds.height], "panes": entries.map { key, terminal, rect -> [String: Any] in ["device": key.device, "pane": key.pane, "surface": terminal.surface.map { String(describing: ObjectIdentifier($0)) } ?? "pending", "visible": rect.width > 0, "resizeCount": terminal.process.resizeCount, "frame": [terminal.view.frame.minX, terminal.view.frame.minY, terminal.view.frame.width, terminal.view.frame.height]] }]
                if let data = try? JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]), let file = FileHandle(forWritingAtPath: path) { _ = try? file.seekToEnd(); try? file.write(contentsOf: data + Data("\n".utf8)); try? file.close() }
            }
            #endif
            let paths = Set(dividers.map { $0.path.map { $0 ? "1" : "0" }.joined() })
            for id in Array(handles.keys) where !paths.contains(id) { handles.removeValue(forKey: id)?.removeFromSuperview() }
            for divider in dividers {
                let id = divider.path.map { $0 ? "1" : "0" }.joined()
                let handle = handles[id] ?? Handle(); handles[id] = handle
                handle.divider = divider; handle.commit = setRatio; handle.preview = previewRatio; handle.minimumPaneSize = minimumPaneSize
                handle.setAccessibilityElement(true); handle.setAccessibilityRole(.splitter); handle.setAccessibilityLabel(L(divider.horizontal ? "Resize Pane Width" : "Resize Pane Height")); handle.setAccessibilityValue(divider.ratio * 100)
                if handle.superview !== self { addSubview(handle) }
                let box = divider.box
                handle.frame = divider.horizontal
                    ? CGRect(x: bounds.width * (box.minX + box.width * divider.ratio) - 3.5, y: bounds.height * (1 - box.maxY), width: 7, height: bounds.height * box.height)
                    : CGRect(x: bounds.width * box.minX, y: bounds.height * (1 - box.minY - box.height * divider.ratio) - 3.5, width: bounds.width * box.width, height: 7)
            }
        }
        final class Handle: NSView {
            var divider: Layout.Divider?
            var minimumPaneSize: CGSize = .zero
            override var acceptsFirstResponder: Bool { true }
            func clamped(_ value: Double) -> Double {
                guard let divider, let parent = superview else { return value }
                let dimension = divider.horizontal ? parent.bounds.width * divider.box.width : parent.bounds.height * divider.box.height
                let minimum = divider.horizontal ? minimumPaneSize.width : minimumPaneSize.height
                let edge = min(0.5, max(0.1, minimum / max(1, dimension)))
                return min(1 - edge, max(edge, value))
            }
            override func accessibilityMinValue() -> Any? { clamped(0) * 100 }
            override func accessibilityMaxValue() -> Any? { clamped(1) * 100 }
            override func accessibilityPerformIncrement() -> Bool { guard let divider else { return false }; commit?(divider, clamped(divider.ratio + 0.05)); return true }
            override func accessibilityPerformDecrement() -> Bool { guard let divider else { return false }; commit?(divider, clamped(divider.ratio - 0.05)); return true }
            override func keyDown(with event: NSEvent) { if [124, 125].contains(event.keyCode) { _ = accessibilityPerformIncrement() } else if [123, 126].contains(event.keyCode) { _ = accessibilityPerformDecrement() } else { super.keyDown(with: event) } }
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
                preview?(initial, clamped(initial.ratio + delta))
            }
            override func mouseUp(with event: NSEvent) {
                defer { initial = nil }
                guard let initial, let parent = superview else { return }
                let delta = initial.horizontal ? (event.locationInWindow.x - start.x) / (parent.bounds.width * initial.box.width) : (start.y - event.locationInWindow.y) / (parent.bounds.height * initial.box.height)
                commit?(initial, clamped(initial.ratio + delta))
            }
        }
    }
}
