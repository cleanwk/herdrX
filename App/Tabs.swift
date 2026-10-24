import AppKit
import SwiftUI

/// Shared with the SwiftUI host so tab content cannot touch the window edge.
enum TabMetrics {
    static let barHeight: CGFloat = 28
    static let height: CGFloat = 22
    static let inset: CGFloat = 8
    static let gap: CGFloat = 4
    static let radius: CGFloat = 5
}

struct TabEntry: Equatable { let id: String; let title: String; let count: Int }

struct Tabs: NSViewRepresentable {
    let scope: String
    let entries: [TabEntry]
    let selected: String
    let select: (String) -> Void
    let move: (String, Int) -> Void
    let rename: (String) -> Void
    let close: (String) -> Void
    let writable: Bool
    func makeNSView(context: Context) -> HorizontalScrollView { let scroll = HorizontalScrollView(); scroll.documentView = Strip(); return scroll }
    func updateNSView(_ scroll: HorizontalScrollView, context: Context) {
        guard let strip = scroll.documentView as? Strip else { return }
        let scopeChanged = strip.scope != scope
        let selectionChanged = strip.selected != selected
        let contentChanged = scopeChanged || selectionChanged || strip.entries != entries
        let navigate = scopeChanged || selectionChanged
        if scopeChanged { strip.stopDrag() }
        strip.scope = scope; strip.writable = writable
        strip.select = select; strip.move = move; strip.rename = rename; strip.close = close
        if contentChanged {
            strip.entries = entries; strip.selected = selected
            strip.syncButtons()
            scroll.fitDocument()
            if navigate { strip.revealSelection() }
        }
        // Theme and appearance changes do not change the entries; retint only
        // when the selected/idle colour actually differs to avoid a redraw storm.
        for (index, button) in strip.buttons.enumerated() where index < strip.entries.count {
            let tint = strip.entries[index].id == strip.selected ? Theme.selectedText : Theme.tabText
            if button.contentTintColor != tint {
                button.contentTintColor = tint
                button.needsDisplay = true
            }
        }
    }
    /// A tab bar has one scrolling axis, including momentum and programmatic reveals.
    final class HorizontalScrollView: NSScrollView {
        private var viewportSize: NSSize = .zero
        // Workbench windows drag by their background; the tab strip must keep
        // every mouse event for reorder, not hand it to the window chrome.
        override var mouseDownCanMoveWindow: Bool { false }
        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            contentView = HorizontalClipView()
            drawsBackground = false; contentView.drawsBackground = false
            hasHorizontalScroller = false; hasVerticalScroller = false
            horizontalScrollElasticity = .none; verticalScrollElasticity = .none
            automaticallyAdjustsContentInsets = false; contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            borderType = .noBorder
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func layout() {
            super.layout(); fitDocument()
            if viewportSize != contentSize {
                viewportSize = contentSize
                (documentView as? Strip)?.revealSelection()
            }
        }
        func fitDocument() {
            guard let strip = documentView as? Strip else { return }
            let size = NSSize(width: max(contentSize.width, strip.contentWidth), height: contentSize.height)
            if strip.frame.size != size { strip.setFrameSize(size); strip.syncButtons() }
            scrollHorizontally(to: contentView.bounds.minX)
        }
        func scrollHorizontally(to x: CGFloat) {
            let limit = max(0, (documentView?.frame.width ?? 0) - contentSize.width)
            contentView.scroll(to: NSPoint(x: min(max(0, x), limit), y: 0))
            reflectScrolledClipView(contentView)
        }
        override func scrollWheel(with event: NSEvent) {
            let delta = event.scrollingDeltaX != 0 ? event.scrollingDeltaX : event.modifierFlags.contains(.shift) ? event.scrollingDeltaY : 0
            guard delta != 0 else { return }
            scrollHorizontally(to: contentView.bounds.minX - delta * (event.hasPreciseScrollingDeltas ? 1 : 10))
        }
    }
    final class HorizontalClipView: NSClipView {
        override var mouseDownCanMoveWindow: Bool { false }
        override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
            var constrained = super.constrainBoundsRect(proposedBounds)
            constrained.origin.y = 0
            return constrained
        }
        override func setBoundsOrigin(_ newOrigin: NSPoint) { super.setBoundsOrigin(NSPoint(x: newOrigin.x, y: 0)) }
        override func scroll(to newOrigin: NSPoint) { super.scroll(to: NSPoint(x: newOrigin.x, y: 0)) }
    }
    final class Strip: NSView {
        override var isFlipped: Bool { true }
        // The workbench enables background window dragging. Tab gestures must
        // stay in this view instead of being claimed by the window/title bar.
        override var mouseDownCanMoveWindow: Bool { false }
        var scope = ""
        var entries: [TabEntry] = []; var selected = ""; var writable = true
        private var edgeTimer: Timer?
        private var escapeMonitor: Any?
        private var dragMonitor: Any?
        private var windowObserver: NSObjectProtocol?
        private var pointer: CGPoint = .zero
        private var grabOffset: CGFloat = 0
        private var dragOrder: [String] = []
        private var layoutFrames: [NSRect] = []
        private var dropFrame: NSRect?
        private var renaming = false
        var select: ((String) -> Void)?; var move: ((String, Int) -> Void)?; var rename: ((String) -> Void)?; var close: ((String) -> Void)?
        var source: String?; var origin: CGFloat = 0; var dragged = false; var insertion: Int?
        var buttons: [TabButton] = []
        var contentWidth: CGFloat { (layoutFrames.last?.maxX ?? TabMetrics.inset) + TabMetrics.inset }
        private var hover: Int?
        private var tracking: NSTrackingArea?
        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let tracking { removeTrackingArea(tracking) }
            let area = NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self)
            tracking = area; addTrackingArea(area)
        }
        override func mouseMoved(with event: NSEvent) {
            let point = convert(event.locationInWindow, from: nil)
            let next = buttons.firstIndex { $0.frame.contains(point) }
            if next != hover { hover = next; updateHover() }
        }
        override func mouseExited(with event: NSEvent) { hover = nil; updateHover() }
        private func updateHover() {
            for (index, button) in buttons.enumerated() { button.hovered = !dragged && hover == index }
        }
        func syncButtons() {
            let ids = entries.map(\.id)
            // An active drag owns the gesture until mouse-up / Escape. Poll
            // refreshes that only reorder ids must not yank the lift preview;
            // drop still requires the source id to remain and writability.
            if let source {
                if !ids.contains(source) || (dragged && !writable) { stopDrag() }
                else if !dragged, dragOrder != ids { stopDrag() }
            }
            // Preserve view identity so the background and label animate together on reorder/rollback.
            let previous = Dictionary(uniqueKeysWithValues: buttons.map { ($0.entryID, $0) })
            let reordered = !buttons.isEmpty && buttons.map(\.entryID) != ids
            for button in buttons where !ids.contains(button.entryID) { button.removeFromSuperview() }
            buttons = entries.map { entry in
                if let button = previous[entry.id] { return button }
                let button = TabButton(); button.entryID = entry.id; button.title = ""; button.isBordered = false; button.focusRingType = .exterior; button.bezelStyle = .regularSquare; button.target = self; button.action = #selector(pressed(_:)); button.lineBreakMode = .byTruncatingTail; button.wantsLayer = true; addSubview(button)
                return button
            }
            setAccessibilityChildren(buttons)
            layoutFrames = []
            var x = TabMetrics.inset
            for (index, button) in buttons.enumerated() {
                button.state = selected == entries[index].id ? .on : .off; button.tag = index; button.displayTitle = entries[index].title; button.paneCount = entries[index].count
                button.font = .systemFont(ofSize: 12, weight: selected == entries[index].id ? .semibold : .regular)
                button.contentTintColor = selected == entries[index].id ? Theme.selectedText : Theme.tabText
                // Reserve the selected weight so changing tabs does not move its neighbours.
                let width = min(200, max(40, (button.displayTitle as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 12, weight: .semibold)]).width + 18 + button.countWidth + (button.paneCount > 1 ? 8 : 0)))
                let frame = NSRect(x: x, y: max(0, (bounds.height - TabMetrics.height) / 2), width: width, height: TabMetrics.height)
                layoutFrames.append(frame); x += width + TabMetrics.gap
                if previous[button.entryID] == nil { button.frame = frame }
                button.setAccessibilityRole(.radioButton); button.setAccessibilityLabel(entries[index].title); button.setAccessibilityValue(selected == entries[index].id ? 1 : 0); button.setAccessibilityHelp(LF("%d panes", entries[index].count)); button.toolTip = entries[index].title + "\n" + LF("%d panes", entries[index].count); button.needsDisplay = true
            }
            updateHover()
            if dragged { updateDragPreview() }
            else { positionButtons(layoutFrames, animated: reordered) }
        }
        private func positionButtons(_ frames: [NSRect], animated: Bool, excluding: String? = nil) {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.18 : 0
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                for (button, frame) in zip(buttons, frames) where button.entryID != excluding {
                    guard button.targetFrame != frame else { continue }
                    button.targetFrame = frame
                    if context.duration > 0 { button.animator().frame = frame }
                    else { button.layer?.removeAllAnimations(); button.frame = frame }
                }
            }
        }
        @objc func pressed(_ sender: NSButton) { if entries.indices.contains(sender.tag) { select?(entries[sender.tag].id) } }
        final class TabButton: NSButton {
            override var mouseDownCanMoveWindow: Bool { false }
            var entryID = ""
            var targetFrame: NSRect = .zero
            var hovered = false { didSet { if hovered != oldValue { needsDisplay = true } } }
            var lifted = false { didSet {
                guard lifted != oldValue else { return }
                layer?.zPosition = lifted ? 1 : 0
                layer?.shadowColor = NSColor.black.cgColor
                layer?.shadowOpacity = lifted ? 0.20 : 0
                layer?.shadowRadius = 2
                layer?.shadowOffset = CGSize(width: 0, height: -1)
                needsDisplay = true
            } }
            var displayTitle = ""
            var paneCount = 1
            private var countFont: NSFont { .monospacedDigitSystemFont(ofSize: 10, weight: .regular) }
            var countWidth: CGFloat { paneCount > 1 ? ceil((String(paneCount) as NSString).size(withAttributes: [.font: countFont]).width) : 0 }
            var countRect: NSRect { NSRect(x: bounds.maxX - 9 - countWidth, y: (bounds.height - 14) / 2, width: countWidth, height: 14) }
            var labelRect: NSRect { NSRect(x: 9, y: (bounds.height - 16) / 2, width: max(0, bounds.width - 18 - countWidth - (paneCount > 1 ? 8 : 0)), height: 16) }
            override var focusRingMaskBounds: NSRect { bounds.insetBy(dx: 0.5, dy: 0.5) }
            override func drawFocusRingMask() { NSBezierPath(roundedRect: focusRingMaskBounds, xRadius: TabMetrics.radius, yRadius: TabMetrics.radius).fill() }
            override func draw(_ dirtyRect: NSRect) {
                let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: TabMetrics.radius, yRadius: TabMetrics.radius)
                (state == .on ? Theme.tabWash : hovered || lifted ? Theme.tabHoverWash : Theme.tabInactiveWash).setFill()
                path.fill()
                (lifted ? Theme.accentStroke.withAlphaComponent(0.75) : state == .on ? Theme.accentStroke.withAlphaComponent(0.40) : Theme.foreground.withAlphaComponent(hovered ? 0.18 : 0.12)).setStroke()
                path.lineWidth = 1; path.stroke()
                // Let the native button draw focus/pressed treatment; text has separate slots.
                super.draw(dirtyRect)
                let style = NSMutableParagraphStyle(); style.lineBreakMode = .byTruncatingTail
                (displayTitle as NSString).draw(in: labelRect, withAttributes: [.font: font ?? NSFont.systemFont(ofSize: 12), .foregroundColor: contentTintColor ?? Theme.foreground, .paragraphStyle: style])
                if paneCount > 1 { (String(paneCount) as NSString).draw(in: countRect, withAttributes: [.font: countFont, .foregroundColor: state == .on ? Theme.selectedSecondary : Theme.tabText]) }
            }
            override func mouseDown(with event: NSEvent) { (superview as? Strip)?.mouseDown(with: event) }
            override func mouseDragged(with event: NSEvent) { (superview as? Strip)?.mouseDragged(with: event) }
            override func mouseUp(with event: NSEvent) { (superview as? Strip)?.mouseUp(with: event) }
            override func menu(for event: NSEvent) -> NSMenu? { (superview as? Strip)?.menu(for: event) }
        }
        override func menu(for event: NSEvent) -> NSMenu? {
            let x = convert(event.locationInWindow, from: nil).x
            guard let index = buttons.firstIndex(where: { $0.frame.minX <= x && x <= $0.frame.maxX }), entries.indices.contains(index) else { return nil }
            let menu = NSMenu(); menu.autoenablesItems = false
            let id = entries[index].id, rename = rename, close = close
            menu.addItem(ActionMenuItem("Rename Tab…", enabled: writable) { rename?(id) })
            menu.addItem(.separator())
            menu.addItem(ActionMenuItem("Close Tab…", enabled: writable) { close?(id) })
            return menu
        }
        func revealSelection() {
            guard !dragged, let scroll = enclosingScrollView as? HorizontalScrollView,
                  let index = entries.firstIndex(where: { $0.id == selected }), layoutFrames.indices.contains(index) else { return }
            let rect = layoutFrames[index].insetBy(dx: -TabMetrics.inset, dy: 0), visible = scroll.contentView.bounds
            if rect.minX < visible.minX { scroll.scrollHorizontally(to: rect.minX) }
            else if rect.maxX > visible.maxX { scroll.scrollHorizontally(to: rect.maxX - visible.width) }
        }
        func stopDrag(restore: Bool = true, animated: Bool = false) {
            source = nil; insertion = nil; dropFrame = nil; dragged = false; dragOrder = []
            pinnedWindow?.isMovable = true; pinnedWindow = nil
            edgeTimer?.invalidate(); edgeTimer = nil
            if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor); self.escapeMonitor = nil }
            if let dragMonitor { NSEvent.removeMonitor(dragMonitor); self.dragMonitor = nil }
            if let windowObserver { NotificationCenter.default.removeObserver(windowObserver); self.windowObserver = nil }
            for button in buttons { button.lifted = false }
            if restore { positionButtons(layoutFrames, animated: animated) }
            updateHover(); needsDisplay = true
        }
        override func cancelOperation(_ sender: Any?) { stopDrag(animated: true) }
        override func viewWillMove(toWindow newWindow: NSWindow?) { if newWindow == nil { stopDrag() }; super.viewWillMove(toWindow: newWindow) }
        private func scrollEdge() {
            guard dragged, writable, let scroll = enclosingScrollView as? HorizontalScrollView, let source, entries.contains(where: { $0.id == source }) else { return }
            let point = convert(pointer, from: nil), visible = visibleRect
            let edge: CGFloat = 28
            let delta: CGFloat = point.x < visible.minX + edge ? -8 * min(1, (visible.minX + edge - point.x) / edge) : point.x > visible.maxX - edge ? 8 * min(1, (point.x - visible.maxX + edge) / edge) : 0
            guard delta != 0 else { return }
            scroll.scrollHorizontally(to: scroll.contentView.bounds.minX + delta)
            updateDragPreview()
        }
        private func updateDragPreview() {
            guard dragged, let source, let old = entries.firstIndex(where: { $0.id == source }), layoutFrames.count == buttons.count else { return }
            var frame = layoutFrames[old]
            frame.origin.x = min(max(TabMetrics.inset, convert(pointer, from: nil).x - grabOffset), max(TabMetrics.inset, contentWidth - TabMetrics.inset - frame.width))
            let others = entries.indices.filter { $0 != old }
            // Compare the leading edge with the remaining tabs' midpoints. Removing
            // the source width first lets a wide tab reach either end beside short tabs.
            var destination = 0, remainingX = TabMetrics.inset
            for index in others {
                if frame.minX > remainingX + layoutFrames[index].width / 2 { destination += 1 }
                remainingX += layoutFrames[index].width + TabMetrics.gap
            }
            insertion = destination > old ? destination + 1 : destination
            var order = others; order.insert(old, at: destination)
            var frames = layoutFrames, x = TabMetrics.inset
            for index in order {
                frames[index].origin.x = x
                x += frames[index].width + TabMetrics.gap
            }
            dropFrame = frames[old]
            positionButtons(frames, animated: true, excluding: source)
            let button = buttons[old]
            button.layer?.removeAllAnimations(); button.frame = frame; button.targetFrame = frame
            needsDisplay = true
        }
        override func draw(_ dirtyRect: NSRect) {
            if let dropFrame {
                let path = NSBezierPath(roundedRect: dropFrame.insetBy(dx: 0.5, dy: 0.5), xRadius: TabMetrics.radius, yRadius: TabMetrics.radius)
                Theme.tabInactiveWash.setFill(); path.fill()
                Theme.accentStroke.withAlphaComponent(0.40).setStroke()
                path.lineWidth = 1; path.setLineDash([3, 2], count: 2, phase: 0); path.stroke()
            }
        }
        static var pressMode = "consume"
        private weak var pinnedWindow: NSWindow?
        private var pressMonitor: Any?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let pressMonitor { NSEvent.removeMonitor(pressMonitor); self.pressMonitor = nil }
            guard window != nil, Self.pressMode != "none" else { return }
            pressMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                guard let self, let window = self.window, event.window === window,
                      let frameView = window.contentView?.superview,
                      let hit = frameView.hitTest(frameView.convert(event.locationInWindow, from: nil)), hit.isDescendant(of: self) else { return event }
                if Self.pressMode == "pin" { if window.isMovable { window.isMovable = false; self.pinnedWindow = window }; return event }
                if !window.isKeyWindow { window.makeKeyAndOrderFront(nil) }
                self.mouseDown(with: event); return nil
            }
        }
        override func mouseDown(with event: NSEvent) {
            stopDrag()
            renaming = event.clickCount == 2
            let point = convert(event.locationInWindow, from: nil)
            origin = point.x; pointer = event.locationInWindow
            guard let index = buttons.firstIndex(where: { $0.frame.contains(point) }) else { return }
            source = entries[index].id; grabOffset = point.x - buttons[index].frame.minX; dragOrder = entries.map(\.id)
            if renaming, writable, let source { rename?(source); stopDrag(); return }
            // Consume left-drag/up through a local monitor so isMovableByWindowBackground
            // cannot claim the gesture after the 4pt threshold. Discrete sendEvent
            // harnesses still hit this path; view mouseDragged remains a fallback.
            installDragMonitor()
        }
        private func installDragMonitor() {
            if dragMonitor != nil { return }
            dragMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDragged, .leftMouseUp]) { [weak self] event in
                guard let self, event.window === self.window else { return event }
                // Only claim events while this strip owns a tab grab.
                guard self.source != nil else { return event }
                switch event.type {
                case .leftMouseDragged:
                    self.handleDragged(event)
                    return nil
                case .leftMouseUp:
                    self.handleMouseUp(event)
                    return nil
                default:
                    return event
                }
            }
        }
        override func mouseDragged(with event: NSEvent) { handleDragged(event) }
        override func mouseUp(with event: NSEvent) { handleMouseUp(event) }
        private func handleDragged(_ event: NSEvent) {
            guard writable, !renaming, let source else { return }
            let x = convert(event.locationInWindow, from: nil).x
            guard abs(x - origin) > 4 || dragged else { return }
            pointer = event.locationInWindow
            if !dragged {
                dragged = true; hover = nil; updateHover()
                buttons.first { $0.entryID == source }?.lifted = true
                if escapeMonitor == nil {
                    escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                        guard let self, event.window === self.window, event.keyCode == 53 else { return event }
                        self.cancelOperation(nil); return nil
                    }
                }
                if windowObserver == nil {
                    windowObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: .main) { [weak self] _ in
                        MainActor.assumeIsolated { self?.stopDrag(animated: true) }
                    }
                }
                if edgeTimer == nil {
                    let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.scrollEdge() } }
                    edgeTimer = timer; RunLoop.main.add(timer, forMode: .common)
                }
            }
            updateDragPreview()
        }
        private func handleMouseUp(_ event: NSEvent) {
            defer { renaming = false }
            guard !renaming, let source, let old = entries.firstIndex(where: { $0.id == source }) else { stopDrag(); return }
            guard dragged else { stopDrag(); select?(source); return }
            guard writable, dragOrder == entries.map(\.id) else { stopDrag(animated: true); return }
            pointer = event.locationInWindow; updateDragPreview()
            guard let insertion, insertion != old, insertion != old + 1, let dropFrame else { stopDrag(animated: true); return }
            var frames = buttons.map(\.targetFrame); frames[old] = dropFrame
            positionButtons(frames, animated: true)
            stopDrag(restore: false)
            move?(source, insertion)
        }
    }
}
