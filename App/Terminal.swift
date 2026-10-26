import AppKit
import SwiftUI
import GhosttyTerminal
import HerdCore

@MainActor
final class Terminal: NSObject, TerminalSurfaceLifecycleDelegate, TerminalSurfaceOpenURLDelegate, TerminalSurfaceHoverLinkDelegate {
    static let controller = TerminalController(configSource: .none, theme: TerminalTheme(light: .alabaster, dark: TerminalConfiguration { $0.withBackground("101012"); $0.withForeground("E2E2E2") }))
    let process = ByteProcess()
    let observation = TerminalObservation()
    let session: InMemoryTerminalSession
    let view = TerminalView(frame: .zero)
    var surface: TerminalSurface?
    var command: String
    var takeoverCommand: String
    var observationCommand: (UInt16, UInt16) -> String
    var onExit: ((Int32) -> Void)?
    var onObservationEnded: (() -> Void)?
    var onKeyboardModesEnabled: (() -> Void)?
    var onScroll: (([NSEvent]) async -> Void)?
    var historyScroll = TerminalScroll()
    private var wheelEvents: [NSEvent] = []
    private var wheelTask: Task<Void, Never>?
    private var wheelID = UUID()
    private var cellHeightPixels: Double = 18
    var scrollLineHeight: Double { max(1, Double(cellHeightPixels) / Double(view.window?.backingScaleFactor ?? 1)) }
    private(set) var attachmentID = UUID()
    private(set) var hoverURL: URL?
    /// Set by `stop()` so a deliberate close does not start observation or
    /// paint an ended overlay while the pane is being removed.
    private var intentionalClose = false
    init(command: String, takeoverCommand: String, observationCommand: @escaping (UInt16, UInt16) -> String) {
        self.command = command
        self.takeoverCommand = takeoverCommand
        self.observationCommand = observationCommand
        let process = self.process
        let observation = self.observation
        session = InMemoryTerminalSession(write: { process.write($0) }, resize: {
            process.resize($0.columns, $0.rows)
            let columns = $0.columns, rows = $0.rows
            Task { @MainActor in observation.resize(columns, rows) }
        }, suppressesPixelOnlyResizes: true)
        super.init()
        view.controller = Self.controller; view.delegate = self
        view.configuration = TerminalSurfaceOptions(backend: .inMemory(session))
        let session = self.session
        observation.output = { [weak session] in session?.receive($0) }
        observation.ended = { [weak self] _ in self?.onObservationEnded?() }
        process.exited = { [weak self] status in
            guard let self else { return }
            self.view.allowsRemoteScroll = false
            self.process.stop(); self.resetInput()
            // Closing the pane stops the attach on purpose. Do not feed the
            // exit banner into the surface or start a stale observe session.
            if self.intentionalClose { return }
            self.observation.start(self.observationCommand)
            self.onExit?(status)
        }
        view.onFocus = { [weak self] in self?.focused?() }
        view.onRemoteScroll = { [weak self] in self?.enqueueScroll($0) }
        start(command)
    }
    var focused: (() -> Void)?
    private func start(_ command: String) {
        let monitor = TerminalKeyboardMonitor(), attachment = attachmentID
        let session = session
        process.output = { [weak self, weak session] data in
            session?.receive(data)
            if monitor.append(data) {
                Task { @MainActor [weak self] in
                    guard let self, self.attachmentID == attachment, !self.observation.isRunning else { return }
                    self.onKeyboardModesEnabled?()
                }
            }
        }
        process.start(command)
    }
    func restart(takeover: Bool = false) {
        intentionalClose = false
        attachmentID = UUID(); observation.stop(); resetInput(); view.allowsRemoteScroll = true
        start(takeover ? takeoverCommand : command)
    }
    // The live `herdr terminal attach` owns mouse capture, independently of the
    // child Agent. Clearing it on Agent exit disables shell/history scrolling.
    func repair() { view.cancelSelectionGesture(); session.receive(TerminalInputRecovery.keyboardBytes) }
    private func resetInput() { cancelScrolling(); view.cancelSelectionGesture(); session.receive(TerminalInputRecovery.bytes) }
    func interrupt() { process.write(Data([3])) }
    func stop() {
        intentionalClose = true
        attachmentID = UUID(); cancelScrolling(); view.allowsRemoteScroll = false
        observation.stop()
        // Drop the output sink before tearing the PTY so an attach exit banner
        // ("terminal … not found") cannot paint into the dying surface.
        process.output = nil
        process.stop()
    }
    private func enqueueScroll(_ event: NSEvent) {
        guard view.allowsRemoteScroll else { return }
        wheelEvents.append(event)
        guard wheelTask == nil else { return }
        let id = UUID(); wheelID = id
        wheelTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { if self.wheelID == id { self.wheelTask = nil } }
            while !Task.isCancelled, self.wheelID == id, !self.wheelEvents.isEmpty {
                let events = self.wheelEvents; self.wheelEvents.removeAll(keepingCapacity: true)
                await self.onScroll?(events)
            }
        }
    }
    private func cancelScrolling() {
        wheelID = UUID(); wheelTask?.cancel(); wheelTask = nil
        wheelEvents.removeAll(); historyScroll = TerminalScroll()
    }
    func takePendingScrollEvents() -> [NSEvent] {
        let events = wheelEvents
        wheelEvents.removeAll(keepingCapacity: true)
        return events
    }
    func terminalDidResize(_ size: TerminalGridMetrics) { cellHeightPixels = Double(size.cellHeightPixels) }
    func terminalDidAttachSurface(_ surface: TerminalSurface) { self.surface = surface; view.hostSurface = surface }
    func terminalDidDetachSurface() { surface = nil; view.hostSurface = nil }
    func terminalDidRequestOpenURL(_ url: String, kind: TerminalOpenURLKind) {
        guard let url = URL(string: url), ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return }
        NSWorkspace.shared.open(url)
    }
    func terminalDidUpdateHoverLink(_ value: String?) {
        hoverURL = value.flatMap(URL.init(string:)).flatMap { ["http", "https"].contains($0.scheme?.lowercased() ?? "") ? $0 : nil }
    }
    func visible(_ visible: Bool) { if !visible { cancelScrolling() }; view.visible = visible }
}

final class TerminalView: InterruptTerminalView {
    var objectMenu: ((PaneMenuSource) -> NSMenu?)?
    var commands: WorkbenchActions?
    override func rightMouseDown(with event: NSEvent) { cancelSelectionGesture(); if let menu = objectMenu?(.terminal) { NSMenu.popUpContextMenu(menu, with: event, for: self) } else { super.rightMouseDown(with: event) } }
    override func rightMouseUp(with event: NSEvent) { if objectMenu == nil { super.rightMouseUp(with: event) } }
    override func menu(for event: NSEvent) -> NSMenu? { objectMenu?(.terminal) ?? super.menu(for: event) }
    var onFocus: (() -> Void)?
    var visible = true {
        didSet { guard oldValue != visible else { return }; isHidden = !visible; if !visible { cancelSelectionGesture(); layer?.contents = nil }; setSurfaceVisible(visible) }
    }
    override func setFrameSize(_ size: NSSize) { if visible { super.setFrameSize(size) } }
    override func layout() { if visible { super.layout() } }
    override func becomeFirstResponder() -> Bool { let result = super.becomeFirstResponder(); if result { onFocus?() }; return result }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard !hasMarkedText() else { return super.performKeyEquivalent(with: event) }
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

/// Keep native surfaces mounted even while other workspaces occupy the viewport.
struct TerminalCanvas: NSViewRepresentable {
    let terminals: [(PaneKey, Terminal, CGRect)]
    let focused: PaneKey?
    let dividers: [Layout.Divider]
    let setRatio: (Layout.Divider, Double) -> Void
    let previewRatio: (Layout.Divider, Double) -> Void
    let titles: [PaneKey: PaneTitle]
    let close: (PaneKey) -> Void
    let canClose: (PaneKey) -> Bool
    let zoomed: Bool
    let restore: () -> Void
    let focusRevision: Int
    let minimumPaneSize: CGSize
    let actions: WorkbenchActions
    let corners: PaneCorners
    func makeNSView(context: Context) -> Canvas { Canvas() }
    func updateNSView(_ canvas: Canvas, context: Context) {
        // SwiftUI re-runs this for every observable change on Desk, including
        // status polls that cannot affect pane chrome. Only invalidate AppKit
        // layout and drawing when an input it consumes actually changed.
        let entriesChanged = canvas.entries.count != terminals.count || !zip(canvas.entries, terminals).allSatisfy { pair in
            pair.0.0 == pair.1.0 && pair.0.1 === pair.1.1 && pair.0.2 == pair.1.2
        }
        let titlesChanged = canvas.titles != titles
        let focusChanged = canvas.focused != focused
        let dividersChanged = canvas.dividers != dividers
        let zoomChanged = canvas.zoomed != zoomed
        let minimumChanged = canvas.minimumPaneSize != minimumPaneSize
        let cornersChanged = canvas.corners != corners
        let focusRevisionChanged = canvas.focusRevision != focusRevision
        canvas.corners = corners; canvas.actions = actions; canvas.focusRevision = focusRevision; canvas.minimumPaneSize = minimumPaneSize
        canvas.titles = titles; canvas.close = close; canvas.canClose = canClose; canvas.entries = terminals; canvas.focused = focused; canvas.dividers = dividers; canvas.setRatio = setRatio; canvas.previewRatio = previewRatio; canvas.zoomed = zoomed; canvas.restore = restore
        // Terminal views consult these closures for shortcuts even when the
        // visible layout did not change.
        for (_, terminal, _) in terminals { terminal.view.commands = actions }
        // Theme and appearance changes do not alter these inputs but must still
        // repaint chrome, so drawing stays unconditional while layout is skipped.
        canvas.markChromeForDisplay()
        guard entriesChanged || titlesChanged || focusChanged || dividersChanged || zoomChanged || minimumChanged || cornersChanged || focusRevisionChanged else { return }
        if titlesChanged { canvas.clearMeasuredTitleWidths() }
        canvas.needsLayout = true
    }
    final class Canvas: NSView {
        var actions: WorkbenchActions?
        var corners = PaneCorners()
        private var fullScreenObservers: [NSObjectProtocol] = []
        var entries: [(PaneKey, Terminal, CGRect)] = []
        var focusRevision = 0
        private var appliedFocusRevision = -1
        var minimumPaneSize: CGSize = .zero
        private var activationObservers: [NSObjectProtocol] = []
        private var accessibilityObserver: NSObjectProtocol?
        override init(frame: NSRect) {
            super.init(frame: frame)
            accessibilityObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.updateCloseButtons() }
            }
            for name in [NSWindow.didEnterFullScreenNotification, NSWindow.didExitFullScreenNotification] {
                fullScreenObservers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                    MainActor.assumeIsolated {
                        guard let self, (note.object as? NSWindow) === self.window else { return }
                        self.needsDisplay = true; self.needsLayout = true
                    }
                })
            }
            for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification] {
                activationObservers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                    MainActor.assumeIsolated { if let self, (note.object as? NSWindow) === self.window { self.needsDisplay = true; self.needsLayout = true } }
                })
            }
        }
        required init?(coder: NSCoder) { fatalError() }
        deinit {
            for observer in fullScreenObservers { NotificationCenter.default.removeObserver(observer) }
            for observer in activationObservers { NotificationCenter.default.removeObserver(observer) }
            if let accessibilityObserver { NSWorkspace.shared.notificationCenter.removeObserver(accessibilityObserver) }
        }
        var focused: PaneKey?
        var dividers: [Layout.Divider] = []
        var setRatio: ((Layout.Divider, Double) -> Void)?
        var titles: [PaneKey: PaneTitle] = [:]
        var close: ((PaneKey) -> Void)?
        var canClose: ((PaneKey) -> Bool)?
        var previewRatio: ((Layout.Divider, Double) -> Void)?
        var zoomed = false
        var restore: (() -> Void)?
        private var hovered: PaneKey?
        private var tracking: NSTrackingArea?
        private let restoreButton = CloseButton()
        private var closeButtons: [PaneKey: CloseButton] = [:]
        private var visibleKeys: Set<PaneKey> = []
        private var handles: [String: Handle] = [:]
        // Text measurement is the expensive part of pane chrome drawing; titles
        // change rarely, so retain the raw widths until the title dictionary does.
        private var titleWidths: [String: CGFloat] = [:]
        private static let regularTitleFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        private static let semiboldTitleFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
        private static let titleParagraphStyle: NSParagraphStyle = {
            let style = NSMutableParagraphStyle(); style.lineBreakMode = .byTruncatingTail; return style
        }()
        private static let contextParagraphStyle: NSParagraphStyle = {
            let style = NSMutableParagraphStyle(); style.lineBreakMode = .byTruncatingMiddle; return style
        }()
        func clearMeasuredTitleWidths() { titleWidths.removeAll(keepingCapacity: true) }
        func markChromeForDisplay() {
            needsDisplay = true
            for button in closeButtons.values { button.needsDisplay = true }
            restoreButton.needsDisplay = true
        }
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
            let voiceOver = NSWorkspace.shared.isVoiceOverEnabled
            for (key, button) in closeButtons {
                let visible = visibleKeys.contains(key)
                let revealed = hovered == key || button.pointerInside || voiceOver
                button.setVisibility(visible && (revealed || focused == key), opacity: revealed ? 1 : 0.5)
            }
            needsDisplay = true
        }
        override func menu(for event: NSEvent) -> NSMenu? {
            let point = convert(event.locationInWindow, from: nil)
            return entries.first { $0.2.width > 0 && paneFrame($0.2).contains(point) }?.1.view.objectMenu?(.title)
        }
        override func draw(_ dirtyRect: NSRect) {
            let content = Theme.content
            content.setFill(); bounds.fill()
            let keyWindow = window?.isKeyWindow == true
            let borderWidth = PaneMetrics.borderWidth(scale: window?.backingScaleFactor ?? 2)
            let inactiveStroke = Theme.foreground.withAlphaComponent(0.28).cgColor
            let activeStroke = Theme.accentStroke.cgColor
            let graphics = NSGraphicsContext.current?.cgContext
            let activeAttributes: [NSAttributedString.Key: Any] = [.font: Self.semiboldTitleFont, .foregroundColor: Theme.accent, .paragraphStyle: Self.titleParagraphStyle]
            let regularAttributes: [NSAttributedString.Key: Any] = [.font: Self.regularTitleFont, .foregroundColor: Theme.secondary, .paragraphStyle: Self.titleParagraphStyle]
            let contextAttributes: [NSAttributedString.Key: Any] = [.font: Self.regularTitleFont, .foregroundColor: Theme.secondary, .paragraphStyle: Self.contextParagraphStyle]
            for (key, _, rect) in entries where rect.width > 0 && rect.height > 0 {
                let frame = borderFrame(rect)
                let active = focused == key && keyWindow
                if let graphics {
                    graphics.saveGState()
                    graphics.setStrokeColor(active ? activeStroke : inactiveStroke)
                    graphics.setLineWidth(borderWidth)
                    let radii = paneCorners(rect).inset(by: borderWidth / 2)
                    graphics.addPath(PaneShape.path(in: frame, corners: radii))
                    graphics.strokePath(); graphics.restoreGState()
                }
                let title = titles[key] ?? PaneTitle(main: L("Terminal"), context: "")
                let attributes = active ? activeAttributes : regularAttributes
                let available = max(0, frame.width - (zoomed ? 82 : 56))
                let context = available >= 260 ? title.context : ""
                let mainKey = "m" + title.main + (active ? "\u{0}" : "\u{1}")
                let measuredMain: CGFloat
                if let cached = titleWidths[mainKey] {
                    measuredMain = cached
                } else {
                    measuredMain = (title.main as NSString).size(withAttributes: attributes).width
                    titleWidths[mainKey] = measuredMain
                }
                let mainWidth = min(available * (context.isEmpty ? 1 : 0.64), measuredMain)
                let measuredContext: CGFloat
                if context.isEmpty {
                    measuredContext = 0
                } else if let cached = titleWidths["c" + context] {
                    measuredContext = cached
                } else {
                    measuredContext = (context as NSString).size(withAttributes: contextAttributes).width
                    titleWidths["c" + context] = measuredContext
                }
                let contextWidth = min(max(0, available - mainWidth - PaneMetrics.titleGap), measuredContext)
                let box = NSRect(x: paneFrame(rect).minX + PaneMetrics.titleLeading, y: frame.maxY - 7, width: mainWidth + (contextWidth > 0 ? contextWidth + PaneMetrics.titleGap : 0) + PaneMetrics.titlePadding * 2, height: 14)
                content.setFill(); box.fill()
                (title.main as NSString).draw(in: NSRect(x: box.minX + PaneMetrics.titlePadding, y: box.minY, width: mainWidth, height: 14), withAttributes: attributes)
                if contextWidth > 0 { (context as NSString).draw(in: NSRect(x: box.minX + PaneMetrics.titlePadding + mainWidth + PaneMetrics.titleGap, y: box.minY, width: contextWidth, height: 14), withAttributes: contextAttributes) }
            }
            // Keep the backing opaque while the button glyph fades across the title outline.
            content.setFill()
            for button in closeButtons.values where !button.isHidden { button.frame.fill() }
        }
        override func viewDidChangeBackingProperties() {
            super.viewDidChangeBackingProperties()
            needsDisplay = true; needsLayout = true
        }
        private func paneCorners(_ rect: CGRect) -> PaneCorners {
            corners.forPane(rect, fullScreen: window?.styleMask.contains(.fullScreen) == true)
        }
        func paneFrame(_ rect: CGRect) -> CGRect {
            PaneMetrics.frame(rect, in: bounds.size, scale: window?.backingScaleFactor ?? 2)
        }
        private func borderFrame(_ rect: CGRect) -> CGRect {
            PaneMetrics.borderFrame(paneFrame(rect), scale: window?.backingScaleFactor ?? 2)
        }
        /// Small glyph, native button semantics and a stable 22pt hit target.
        final class CloseButton: NSButton {
            var invoke: (() -> Void)?
            private(set) var pointerInside = false
            var hoverChanged: (() -> Void)?
            private var interactive = true
            private var targetOpacity: CGFloat = -1
            private var visibilityRevision = 0
            func setVisibility(_ visible: Bool, opacity: CGFloat) {
                interactive = visible
                setAccessibilityElement(visible)
                setAccessibilityRole(.button)
                let target: CGFloat = visible ? opacity : 0
                guard target != targetOpacity else { return }
                targetOpacity = target; visibilityRevision += 1
                let revision = visibilityRevision
                if visible { isHidden = false }
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.15
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    animator().alphaValue = target
                } completionHandler: { [weak self] in
                    guard let self, self.visibilityRevision == revision else { return }
                    self.isHidden = !visible
                    self.superview?.needsDisplay = true
                }
            }
            override func hitTest(_ point: NSPoint) -> NSView? { interactive ? super.hitTest(point) : nil }
            override func menu(for event: NSEvent) -> NSMenu? { superview?.menu(for: event) }
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
            override func mouseEntered(with event: NSEvent) { pointerInside = true; hoverChanged?(); needsDisplay = true }
            override func mouseExited(with event: NSEvent) { pointerInside = false; hoverChanged?(); needsDisplay = true }
            override func draw(_ dirtyRect: NSRect) {
                Theme.content.setFill(); bounds.fill()
                if pointerInside || isHighlighted {
                    Theme.foreground.withAlphaComponent(isHighlighted ? 0.14 : 0.07).setFill()
                    NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 4, yRadius: 4).fill()
                }
                contentTintColor = pointerInside ? Theme.foreground : Theme.secondary
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
                button.isEnabled = canClose?(key) == true
                button.hoverChanged = { [weak self] in self?.updateCloseButtons() }
                if visible {
                    let frame = paneFrame(rect)
                    button.frame = NSRect(x: frame.maxX - 30, y: frame.maxY - 22, width: 22, height: 22)
                    button.toolTip = L("Close") + " " + (titles[key]?.main ?? L("Pane"))
                    terminal.view.toolTip = titles[key]?.full; terminal.view.setAccessibilityLabel(titles[key]?.full)
                    button.setAccessibilityLabel(button.toolTip)
                    let contentFrame = CGRect(x: frame.minX + PaneMetrics.contentInset, y: frame.minY + PaneMetrics.contentInset, width: max(0, frame.width - PaneMetrics.horizontalOverhead), height: max(0, frame.height - PaneMetrics.verticalOverhead))
                    if terminal.view.frame != contentFrame { terminal.view.frame = contentFrame }
                    let radii = paneCorners(rect).inset(by: PaneMetrics.contentInset)
                    if radii.left > 0 || radii.right > 0 {
                        terminal.view.wantsLayer = true
                        let mask = (terminal.view.layer?.mask as? CAShapeLayer) ?? CAShapeLayer()
                        mask.path = PaneShape.path(in: CGRect(origin: .zero, size: contentFrame.size), corners: radii)
                        terminal.view.layer?.mask = mask
                    } else { terminal.view.layer?.mask = nil }
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
                let report: [String: Any] = ["window": [window?.frame.width ?? 0, window?.frame.height ?? 0], "canvas": [bounds.width, bounds.height], "canvasFrame": [frame.minX, frame.minY, frame.width, frame.height], "canvasBoundsOrigin": [bounds.minX, bounds.minY], "backingScale": window?.backingScaleFactor ?? 1, "corners": [corners.left, corners.right], "fullScreen": window?.styleMask.contains(.fullScreen) == true, "panes": entries.map { key, terminal, rect -> [String: Any] in ["device": key.device, "pane": key.pane, "surface": terminal.surface.map { String(describing: ObjectIdentifier($0)) } ?? "pending", "visible": rect.width > 0, "resizeCount": terminal.process.resizeCount, "normalizedRect": [rect.minX, rect.minY, rect.width, rect.height], "frame": [terminal.view.frame.minX, terminal.view.frame.minY, terminal.view.frame.width, terminal.view.frame.height]] }]
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
            private var dragging = false
            override func draw(_ dirtyRect: NSRect) {
                guard dragging, let divider else { return }
                Theme.accentStroke.setFill()
                let line = divider.horizontal
                    ? CGRect(x: bounds.midX - 0.5, y: bounds.minY, width: 1, height: bounds.height)
                    : CGRect(x: bounds.minX, y: bounds.midY - 0.5, width: bounds.width, height: 1)
                line.fill()
            }
            override func resetCursorRects() { addCursorRect(bounds, cursor: divider?.horizontal == true ? .resizeLeftRight : .resizeUpDown) }
            override func mouseDown(with event: NSEvent) { start = event.locationInWindow; initial = divider }
            override func mouseDragged(with event: NSEvent) {
                guard let initial, let parent = superview else { return }
                dragging = true; needsDisplay = true
                let delta = initial.horizontal ? (event.locationInWindow.x - start.x) / (parent.bounds.width * initial.box.width) : (start.y - event.locationInWindow.y) / (parent.bounds.height * initial.box.height)
                // Local layouts update continuously; remote layouts commit on release.
                preview?(initial, clamped(initial.ratio + delta))
            }
            override func mouseUp(with event: NSEvent) {
                defer { initial = nil; dragging = false; needsDisplay = true }
                guard let initial, let parent = superview else { return }
                let delta = initial.horizontal ? (event.locationInWindow.x - start.x) / (parent.bounds.width * initial.box.width) : (start.y - event.locationInWindow.y) / (parent.bounds.height * initial.box.height)
                commit?(initial, clamped(initial.ratio + delta))
            }
        }
    }
}
