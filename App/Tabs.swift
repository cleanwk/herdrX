import AppKit
import SwiftUI

struct Tabs: NSViewRepresentable {
    let scope: String
    let entries: [(String, String)]
    let selected: String
    let select: (String) -> Void
    let move: (String, Int) -> Void
    let rename: (String) -> Void
    let close: (String) -> Void
    func makeNSView(context: Context) -> NSScrollView { let scroll = NSScrollView(); scroll.hasHorizontalScroller = false; scroll.drawsBackground = false; scroll.documentView = Strip(); return scroll }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let strip = scroll.documentView as? Strip else { return }
        if strip.scope != scope { strip.source = nil; strip.insertion = nil }; strip.scope = scope
        strip.entries = entries; strip.selected = selected; strip.select = select; strip.move = move; strip.rename = rename; strip.close = close
        strip.syncButtons(); strip.frame.size = NSSize(width: max(scroll.bounds.width, strip.buttons.last?.frame.maxX ?? 0), height: 28); strip.needsDisplay = true
    }
    final class Strip: NSView {
        var scope = ""
        var entries: [(String, String)] = []; var selected = ""
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
            var x: CGFloat = 2
            for (index, button) in buttons.enumerated() {
                button.tag = index; button.title = entries[index].1
                button.font = .systemFont(ofSize: 12, weight: selected == entries[index].0 ? .semibold : .regular)
                let width = min(200, max(40, (button.title as NSString).size(withAttributes: [.font: button.font!]).width + 20))
                button.frame = NSRect(x: x, y: 2, width: width, height: 24); x += width + 2
                button.setAccessibilityLabel(entries[index].1 + (selected == entries[index].0 ? ", selected tab" : ", tab")); button.toolTip = entries[index].1
            }
        }
        @objc func pressed(_ sender: NSButton) { if entries.indices.contains(sender.tag) { select?(entries[sender.tag].0) } }
        final class TabButton: NSButton {
            override func mouseDown(with event: NSEvent) { (superview as? Strip)?.mouseDown(with: event) }
            override func mouseDragged(with event: NSEvent) { (superview as? Strip)?.mouseDragged(with: event) }
            override func mouseUp(with event: NSEvent) { (superview as? Strip)?.mouseUp(with: event) }
            override func menu(for event: NSEvent) -> NSMenu? { (superview as? Strip)?.menu(for: event) }
        }
        override func menu(for event: NSEvent) -> NSMenu? {
            let x = convert(event.locationInWindow, from: nil).x
            guard let index = buttons.firstIndex(where: { $0.frame.minX <= x && x <= $0.frame.maxX }), entries.indices.contains(index) else { return nil }
            let menu = NSMenu()
            for (title, action) in [("Rename…", #selector(renameItem(_:))), ("Close Tab…", #selector(closeItem(_:)))] { let item = NSMenuItem(title: L(title), action: action, keyEquivalent: ""); item.target = self; item.representedObject = entries[index].0; menu.addItem(item) }
            return menu
        }
        @objc func renameItem(_ item: NSMenuItem) { if let id = item.representedObject as? String { rename?(id) } }
        @objc func closeItem(_ item: NSMenuItem) { if let id = item.representedObject as? String { close?(id) } }
        override func draw(_ dirtyRect: NSRect) {
            if let hover, buttons.indices.contains(hover), entries.indices.contains(hover), selected != entries[hover].0 {
                NSColor.labelColor.withAlphaComponent(0.06).setFill()
                NSBezierPath(roundedRect: buttons[hover].frame.insetBy(dx: 0.5, dy: 0.5), xRadius: 5, yRadius: 5).fill()
            }
            for (index, entry) in entries.enumerated() where buttons.indices.contains(index) && selected == entry.0 {
                let path = NSBezierPath(roundedRect: buttons[index].frame.insetBy(dx: 0.5, dy: 0.5), xRadius: 5, yRadius: 5)
                Theme.accent.withAlphaComponent(effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? 0.20 : 0.18).setFill(); path.fill(); Theme.accent.withAlphaComponent(0.22).setStroke(); path.lineWidth = 1; path.stroke()
            }
            if let insertion { let x = insertion < buttons.count ? buttons[insertion].frame.minX : buttons.last?.frame.maxX ?? 0; Theme.accent.setFill(); NSRect(x: x, y: 2, width: 2, height: 24).fill() }
        }
        override func mouseDown(with event: NSEvent) { origin = convert(event.locationInWindow, from: nil).x; source = buttons.firstIndex { $0.frame.minX <= origin && origin <= $0.frame.maxX }.map { entries[$0].0 }; dragged = false }
        override func mouseDragged(with event: NSEvent) {
            let x = convert(event.locationInWindow, from: nil).x; guard abs(x - origin) > 4 || dragged else { return }; dragged = true
            insertion = buttons.firstIndex { x < $0.frame.midX } ?? entries.count; needsDisplay = true
        }
        override func mouseUp(with event: NSEvent) {
            defer { source = nil; insertion = nil; needsDisplay = true }
            guard let source, entries.contains(where: { $0.0 == source }) else { return }
            if dragged, let insertion { move?(source, insertion) } else { select?(source) }
        }
    }
}
