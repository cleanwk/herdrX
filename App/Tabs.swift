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
        let navigate = strip.scope != scope || strip.selected != selected
        if strip.scope != scope { strip.stopDrag() }; strip.scope = scope; strip.writable = writable
        strip.entries = entries; strip.selected = selected; strip.select = select; strip.move = move; strip.rename = rename; strip.close = close
        strip.syncButtons()
        scroll.fitDocument()
        strip.needsDisplay = true
        if navigate { strip.revealSelection() }
    }
    /// A tab bar has one scrolling axis, including momentum and programmatic reveals.
    final class HorizontalScrollView: NSScrollView {
        private var viewportSize: NSSize = .zero
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
            let size = NSSize(width: max(contentSize.width, (strip.buttons.last?.frame.maxX ?? 0) + TabMetrics.inset), height: contentSize.height)
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
        var scope = ""
        var entries: [TabEntry] = []; var selected = ""; var writable = true
        private var edgeTimer: Timer?
        private var pointer: CGPoint = .zero
        private var renaming = false
        var select: ((String) -> Void)?; var move: ((String, Int) -> Void)?; var rename: ((String) -> Void)?; var close: ((String) -> Void)?
        var source: String?; var origin: CGFloat = 0; var dragged = false; var insertion: Int?
        var buttons: [NSButton] = []
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
            if next != hover { hover = next; needsDisplay = true }
        }
        override func mouseExited(with event: NSEvent) { hover = nil; needsDisplay = true }
        func syncButtons() {
            while buttons.count > entries.count { buttons.removeLast().removeFromSuperview() }
            while buttons.count < entries.count { let button = TabButton(); button.isBordered = false; button.bezelStyle = .regularSquare; button.target = self; button.action = #selector(pressed(_:)); button.lineBreakMode = .byTruncatingTail; addSubview(button); buttons.append(button) }
            var x = TabMetrics.inset
            for (index, button) in buttons.enumerated() {
                button.tag = index; button.title = entries[index].title + (entries[index].count > 1 ? "  \(entries[index].count)" : "")
                button.font = .systemFont(ofSize: 12, weight: selected == entries[index].id ? .semibold : .regular)
                button.contentTintColor = selected == entries[index].id ? Theme.foreground : Theme.secondary
                let width = min(200, max(40, (button.title as NSString).size(withAttributes: [.font: button.font!]).width + 18))
                button.frame = NSRect(x: x, y: max(0, (bounds.height - TabMetrics.height) / 2), width: width, height: TabMetrics.height); x += width + TabMetrics.gap
                button.setAccessibilityRole(.radioButton); button.setAccessibilityLabel(entries[index].title); button.setAccessibilityValue(selected == entries[index].id ? 1 : 0); button.setAccessibilityHelp(LF("%d panes", entries[index].count)); button.toolTip = entries[index].title
            }
        }
        @objc func pressed(_ sender: NSButton) { if entries.indices.contains(sender.tag) { select?(entries[sender.tag].id) } }
        final class TabButton: NSButton {
            override func mouseDown(with event: NSEvent) { (superview as? Strip)?.mouseDown(with: event) }
            override func mouseDragged(with event: NSEvent) { (superview as? Strip)?.mouseDragged(with: event) }
            override func mouseUp(with event: NSEvent) { (superview as? Strip)?.mouseUp(with: event) }
            override func menu(for event: NSEvent) -> NSMenu? { (superview as? Strip)?.menu(for: event) }
        }
        override func menu(for event: NSEvent) -> NSMenu? {
            let x = convert(event.locationInWindow, from: nil).x
            guard let index = buttons.firstIndex(where: { $0.frame.minX <= x && x <= $0.frame.maxX }), entries.indices.contains(index) else { return nil }
            let menu = NSMenu(); menu.autoenablesItems = false
            let id = entries[index].id, rename = rename, close = close, move = move
            menu.addItem(ActionMenuItem("Rename Tab…", enabled: writable) { rename?(id) })
            menu.addItem(ActionMenuItem("Move Left", enabled: writable && index > 0) { move?(id, index - 1) })
            menu.addItem(ActionMenuItem("Move Right", enabled: writable && index + 1 < entries.count) { move?(id, index + 2) })
            menu.addItem(ActionMenuItem("Close Tab…", enabled: writable) { close?(id) })
            return menu
        }
        func revealSelection() {
            guard let scroll = enclosingScrollView as? HorizontalScrollView,
                  let index = entries.firstIndex(where: { $0.id == selected }), buttons.indices.contains(index) else { return }
            let rect = buttons[index].frame.insetBy(dx: -TabMetrics.inset, dy: 0), visible = scroll.contentView.bounds
            if rect.minX < visible.minX { scroll.scrollHorizontally(to: rect.minX) }
            else if rect.maxX > visible.maxX { scroll.scrollHorizontally(to: rect.maxX - visible.width) }
        }
        func stopDrag() { source = nil; insertion = nil; edgeTimer?.invalidate(); edgeTimer = nil; needsDisplay = true }
        override func viewWillMove(toWindow newWindow: NSWindow?) { if newWindow == nil { stopDrag() }; super.viewWillMove(toWindow: newWindow) }
        private func scrollEdge() {
            guard dragged, let scroll = enclosingScrollView, let source, entries.contains(where: { $0.id == source }) else { return }
            let point = convert(pointer, from: nil), visible = visibleRect
            let delta: CGFloat = point.x < visible.minX + 24 ? -18 : point.x > visible.maxX - 24 ? 18 : 0
            guard delta != 0 else { return }
            let x = min(max(0, scroll.contentView.bounds.minX + delta), max(0, bounds.width - scroll.contentView.bounds.width))
            scroll.contentView.scroll(to: NSPoint(x: x, y: 0)); scroll.reflectScrolledClipView(scroll.contentView)
            insertion = buttons.firstIndex { convert(pointer, from: nil).x < $0.frame.midX } ?? entries.count; needsDisplay = true
        }
        override func draw(_ dirtyRect: NSRect) {
            for (index, entry) in entries.enumerated() where buttons.indices.contains(index) {
                let active = selected == entry.id
                let path = NSBezierPath(roundedRect: buttons[index].frame.insetBy(dx: 0.5, dy: 0.5), xRadius: TabMetrics.radius, yRadius: TabMetrics.radius)
                (active ? Theme.accent.withAlphaComponent(0.11) : Theme.foreground.withAlphaComponent(hover == index ? 0.09 : 0.06)).setFill()
                path.fill()
                if active { Theme.accent.withAlphaComponent(0.45).setStroke(); path.lineWidth = 1; path.stroke() }
            }
            if let insertion {
                let x = insertion < buttons.count ? buttons[insertion].frame.minX - TabMetrics.gap / 2 : (buttons.last?.frame.maxX ?? 0) + TabMetrics.gap / 2
                Theme.accent.setFill()
                NSRect(x: x - 1, y: max(0, (bounds.height - TabMetrics.height) / 2), width: 2, height: TabMetrics.height).fill()
            }
        }
        override func mouseDown(with event: NSEvent) { renaming = event.clickCount == 2; origin = convert(event.locationInWindow, from: nil).x; source = buttons.firstIndex { $0.frame.minX <= origin && origin <= $0.frame.maxX }.map { entries[$0].id }; dragged = false; if renaming, writable, let source { rename?(source); stopDrag() } }
        override func mouseDragged(with event: NSEvent) {
            guard writable, !renaming, source != nil else { return }
            let x = convert(event.locationInWindow, from: nil).x; guard abs(x - origin) > 4 || dragged else { return }; dragged = true; pointer = event.locationInWindow
            if edgeTimer == nil { let timer = Timer(timeInterval: 0.06, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.scrollEdge() } }; edgeTimer = timer; RunLoop.main.add(timer, forMode: .common) }
            scrollEdge()
            insertion = buttons.firstIndex { x < $0.frame.midX } ?? entries.count; needsDisplay = true
        }
        override func mouseUp(with event: NSEvent) {
            defer { stopDrag(); renaming = false }
            guard !renaming else { return }
            guard let source, entries.contains(where: { $0.id == source }) else { return }
            if dragged, let insertion { move?(source, insertion) } else { select?(source) }
        }
    }
}
