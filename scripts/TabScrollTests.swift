import AppKit
import SwiftUI

// Compile the production view and color derivation; only app-wide dependencies are stubbed.
func L(_ value: String) -> String { value }
func LF(_ value: String, _ count: Int) -> String { String(format: value, count) }
enum Theme {
    private static func color(_ hex: UInt32) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
    }
    private static func role(_ path: KeyPath<ThemeColors, NSColor>) -> NSColor {
        NSColor(name: nil) { appearance in
            let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return ThemeColors(background: color(dark ? 0x1e1e2e : 0xeff1f5), foreground: color(dark ? 0xcdd6f4 : 0x4c4f69), accent: color(dark ? 0x82aaff : 0x2463eb), dark: dark,
                chrome: color(dark ? 0x181825 : 0xe6e9ef), secondary: color(dark ? 0xa6adc8 : 0x676b80))[keyPath: path]
        }
    }
    static let selectedText = role(\.selectedText), selectedSecondary = role(\.selectedSecondary)
    static let tabWash = role(\.tabWash), accentStroke = role(\.accentStroke), foreground = role(\.foreground)
    static let tabInactiveWash = role(\.tabInactiveWash), tabHoverWash = role(\.tabHoverWash), tabText = role(\.tabText), chrome = role(\.chrome)
}
final class ActionMenuItem: NSMenuItem {
    let invoke: () -> Void
    init(_ title: String, enabled: Bool, action: @escaping () -> Void) { invoke = action; super.init(title: title, action: nil, keyEquivalent: ""); isEnabled = enabled }
    required init(coder: NSCoder) { fatalError() }
}
final class TabSnapshotBackground: NSView {
    override func draw(_ dirtyRect: NSRect) { Theme.chrome.setFill(); dirtyRect.fill() }
}

@main struct TabScrollTests {
    @MainActor static func main() {
        _ = NSApplication.shared
        let scroll = Tabs.HorizontalScrollView(frame: NSRect(x: 0, y: 0, width: 260, height: 28))
        let strip = Tabs.Strip(); scroll.documentView = strip
        strip.entries = (0..<20).map { TabEntry(id: String($0), title: "Tab \($0)", count: 1) }
        strip.selected = "0"; strip.syncButtons(); scroll.layout()
        let initialFrames = strip.buttons.map(\.frame)
        for entry in strip.entries {
            strip.selected = entry.id; strip.syncButtons()
            precondition(strip.buttons.map(\.frame) == initialFrames, "Selecting a tab moved adjacent tabs")
        }
        strip.selected = "0"; strip.syncButtons()
        func centered(_ label: String) {
            precondition(scroll.contentView.bounds.minY == 0, label + ": vertical origin moved")
            precondition(strip.frame.height == scroll.contentSize.height, label + ": document height drifted")
            for button in strip.buttons {
                precondition(button.frame.height == 22 && button.frame.minY == 3, label + ": pill is not centered")
            }
        }
        func wheel(x: Int32, y: Int32, unit: CGScrollEventUnit = .pixel, shift: Bool = false, target: NSView? = nil) {
            // Input is sent only to this offscreen view, never posted to the system event queue.
            let cg = CGEvent(scrollWheelEvent2Source: nil, units: unit, wheelCount: 2, wheel1: y, wheel2: x, wheel3: 0)!
            if shift { cg.flags = .maskShift }
            (target ?? scroll).scrollWheel(with: NSEvent(cgEvent: cg)!)
        }
        centered("initial")
        for delta: Int32 in [1, -1, 300, -300] { wheel(x: 0, y: delta); centered("vertical wheel") }
        precondition(scroll.contentView.bounds.minX == 0, "Vertical input changed horizontal position")
        wheel(x: -90, y: 200); centered("diagonal trackpad")
        precondition(scroll.contentView.bounds.minX > 0, "Horizontal overflow cannot scroll")
        let beforeButton = scroll.contentView.bounds.minX
        wheel(x: -40, y: 0, target: strip.buttons[0]); centered("button input")
        precondition(scroll.contentView.bounds.minX > beforeButton, "Tab button swallowed horizontal input")
        let x = scroll.contentView.bounds.minX
        wheel(x: 0, y: -1, unit: .line, shift: true); centered("shift wheel")
        precondition(scroll.contentView.bounds.minX > x, "Shift wheel cannot scroll horizontally")
        scroll.contentView.scroll(to: NSPoint(x: x, y: 99)); centered("programmatic scroll")
        scroll.scrollHorizontally(to: .greatestFiniteMagnitude); centered("right boundary")
        precondition(scroll.contentView.bounds.maxX <= strip.bounds.maxX, "Scrolled beyond trailing edge")
        strip.selected = "19"; strip.revealSelection()
        scroll.setFrameSize(NSSize(width: 180, height: 28)); scroll.layout(); centered("resize")
        precondition(scroll.contentView.bounds.contains(strip.buttons[19].frame), "Resize hid the selected tab")
        strip.selected = "0"; strip.revealSelection(); centered("selection reveal")
        precondition(scroll.contentView.bounds.minX == 0, "First tab did not reveal")
        strip.entries = Array(strip.entries.prefix(2)); strip.syncButtons(); scroll.fitDocument(); centered("short strip")
        wheel(x: -500, y: -500); centered("no overflow")
        precondition(scroll.contentView.bounds.minX == 0, "A short strip scrolled")
        // Native context menus target the clicked tab without selecting it first.
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 260, height: 28), styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = scroll
        func menu(at index: Int) -> NSMenu {
            let point = strip.convert(NSPoint(x: strip.buttons[index].frame.midX, y: strip.buttons[index].frame.midY), to: nil)
            let event = NSEvent.mouseEvent(with: .rightMouseDown, location: point, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
            return strip.menu(for: event)!
        }
        var clicked: String?
        strip.rename = { clicked = $0 }
        let second = menu(at: 1)
        (second.items.first as? ActionMenuItem)?.invoke()
        precondition(clicked == "1" && strip.selected == "0", "Context rename lost its clicked target")
        precondition(second.items.contains { $0.title == "Move Left" && $0.isEnabled })
        precondition(second.items.contains { $0.title == "Move Right" && !$0.isEnabled })
        precondition(second.items[second.items.count - 2].isSeparatorItem, "Close is not separated")
        strip.writable = false
        precondition(menu(at: 0).items.filter { !$0.isSeparatorItem }.allSatisfy { !$0.isEnabled }, "Offline menu permits writes")
        strip.entries = Array(strip.entries.prefix(1)); strip.syncButtons(); scroll.fitDocument()
        precondition(menu(at: 0).items.filter { !$0.isSeparatorItem }.map(\.title) == ["Rename Tab…", "Close Tab…"], "A single tab offers redundant moves")
        strip.entries = []; strip.syncButtons(); scroll.fitDocument(); centered("empty strip")
        precondition(scroll.contentView.bounds.origin == .zero, "Empty strip retained an offset")
        strip.entries = [TabEntry(id: "long", title: "Very long release review · 很长的发布检查标签", count: 12), TabEntry(id: "number", title: "1", count: 2), TabEntry(id: "plain", title: "Terminal", count: 1)]
        strip.selected = "long"; strip.syncButtons(); scroll.fitDocument()
        let long = strip.buttons[0]
        precondition(long.frame.width == 200 && long.labelRect.maxX < long.countRect.minX, "Long title overlaps the independent count")
        precondition(long.bounds.contains(long.countRect) && long.countWidth > 0, "Pane count is clipped")
        precondition(strip.buttons[2].countWidth == 0, "Single-pane tab reserves redundant count space")
        let countFrames = strip.buttons.map(\.frame)
        strip.selected = "number"; strip.syncButtons()
        precondition(strip.buttons.map(\.frame) == countFrames, "Count-bearing tabs shift on selection")
        // Opaque native backgrounds make both appearances readable in artifact viewers.
        // This is the production control in isolation, not the running application.
        let host = TabSnapshotBackground(frame: NSRect(x: 0, y: 0, width: strip.frame.width, height: TabMetrics.barHeight))
        window.setContentSize(host.frame.size); window.contentView = host
        scroll.frame = host.bounds; host.addSubview(scroll); scroll.layout()
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            host.appearance = NSAppearance(named: appearance)
            host.effectiveAppearance.performAsCurrentDrawingAppearance {
                guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { preconditionFailure("Cannot render native tab evidence") }
                host.cacheDisplay(in: host.bounds, to: bitmap)
                try! bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "build/tests/tab-chrome-\(name).png"))
            }
        }
        testDragging()
        print("PASS: tab scroll containment, stable selection geometry, clicked context target, grouped/conditional/offline menus, bidirectional drag/drop, cancellation and edge scrolling; 28pt bar / 22pt pills / 3pt insets")
    }

    @MainActor static func testDragging() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 28), styleMask: .borderless, backing: .buffered, defer: false)
        let scroll = Tabs.HorizontalScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 28))
        let strip = Tabs.Strip(); scroll.documentView = strip; window.contentView = scroll
        let initial = [TabEntry(id: "wide", title: "A very wide tab that must reach both ends", count: 12), TabEntry(id: "b", title: "B", count: 1), TabEntry(id: "c", title: "C", count: 1)]
        var moves: [(String, Int)] = []
        strip.select = { strip.selected = $0 }
        strip.move = { id, insertion in
            moves.append((id, insertion))
            let old = strip.entries.firstIndex { $0.id == id }!
            let entry = strip.entries.remove(at: old)
            strip.entries.insert(entry, at: insertion > old ? insertion - 1 : insertion)
            strip.syncButtons(); scroll.fitDocument()
        }
        func settle() { RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.24)) }
        func reset() {
            strip.stopDrag(); strip.writable = true; strip.entries = initial; strip.selected = "b"
            strip.syncButtons(); scroll.fitDocument(); scroll.scrollHorizontally(to: 0); settle(); moves = []
        }
        func event(_ type: NSEvent.EventType, x: CGFloat) -> NSEvent {
            NSEvent.mouseEvent(with: type, location: strip.convert(NSPoint(x: x, y: 14), to: nil), modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: type == .leftMouseUp ? 0 : 1)!
        }
        reset()
        let wide = strip.buttons[0], start = wide.frame.midX, end = strip.contentWidth + 50
        strip.mouseDown(with: event(.leftMouseDown, x: start))
        strip.mouseDragged(with: event(.leftMouseDragged, x: end))
        precondition(strip.dragged && wide.lifted && wide.frame.minY == 3, "Dragged pill did not lift or left the horizontal track")
        precondition(strip.buttons[1].targetFrame.minX == TabMetrics.inset, "Neighbours did not make room")
        precondition(strip.entries.map(\.id) == initial.map(\.id) && moves.isEmpty, "Drag preview committed before release")
        strip.mouseUp(with: event(.leftMouseUp, x: end)); settle()
        precondition(moves.count == 1 && moves[0].0 == "wide" && moves[0].1 == 3, "Wide tab cannot move past short tabs")
        precondition(strip.entries.map(\.id) == ["b", "c", "wide"] && strip.buttons[2] === wide, "Drop lost tab identity/order")
        precondition(strip.selected == "b" && !wide.lifted, "Reordering changed selection or left the drag appearance active")
        strip.mouseDown(with: event(.leftMouseDown, x: wide.frame.midX))
        strip.mouseDragged(with: event(.leftMouseDragged, x: -50))
        strip.mouseUp(with: event(.leftMouseUp, x: -50)); settle()
        precondition(moves.count == 2 && moves[1].1 == 0 && strip.buttons[0] === wide, "Cannot drag back to the first slot")

        reset()
        strip.mouseDown(with: event(.leftMouseDown, x: start))
        strip.mouseDragged(with: event(.leftMouseDragged, x: start + 2))
        strip.mouseUp(with: event(.leftMouseUp, x: start + 2))
        precondition(moves.isEmpty && strip.selected == "wide", "Click jitter became a reorder")
        strip.mouseDown(with: event(.leftMouseDown, x: start))
        strip.mouseDragged(with: event(.leftMouseDragged, x: end))
        strip.mouseUp(with: event(.leftMouseUp, x: start)); settle()
        precondition(moves.isEmpty && strip.buttons[0].frame.minX == TabMetrics.inset, "Returning to the original slot emitted a move")

        reset(); strip.writable = false
        strip.mouseDown(with: event(.leftMouseDown, x: start)); strip.syncButtons()
        strip.mouseUp(with: event(.leftMouseUp, x: start))
        precondition(strip.selected == "wide" && moves.isEmpty, "Read-only tabs lost ordinary selection")

        for cancellation in ["escape", "offline", "removed", "changed-order", "window"] {
            reset()
            strip.mouseDown(with: event(.leftMouseDown, x: start))
            strip.mouseDragged(with: event(.leftMouseDragged, x: end))
            switch cancellation {
            case "escape": strip.cancelOperation(nil)
            case "offline": strip.writable = false; strip.syncButtons()
            case "removed": strip.entries.removeFirst(); strip.syncButtons()
            case "changed-order": strip.entries.swapAt(1, 2); strip.syncButtons()
            default: NotificationCenter.default.post(name: NSWindow.didResignKeyNotification, object: window)
            }
            strip.mouseUp(with: event(.leftMouseUp, x: end)); settle()
            precondition(moves.isEmpty && strip.source == nil && !strip.dragged, "Cancelled drag committed: " + cancellation)
            precondition(strip.buttons.allSatisfy { !$0.lifted }, "Cancelled drag retained a lifted tab")
        }

        reset()
        strip.entries = (0..<20).map { TabEntry(id: String($0), title: "Overflow tab \($0)", count: 1) }
        strip.syncButtons(); window.setContentSize(NSSize(width: 260, height: 28)); scroll.frame.size.width = 260; scroll.layout(); settle()
        strip.mouseDown(with: event(.leftMouseDown, x: strip.buttons[0].frame.midX))
        strip.mouseDragged(with: event(.leftMouseDragged, x: scroll.contentView.bounds.maxX - 2)); settle()
        precondition(scroll.contentView.bounds.minX > 0 && scroll.contentView.bounds.minY == 0, "Edge drag did not scroll horizontally")
        strip.cancelOperation(nil)
        let offset = scroll.contentView.bounds.minX; settle()
        precondition(scroll.contentView.bounds.minX == offset && moves.isEmpty, "Cancelled edge drag kept scrolling")
    }
}
