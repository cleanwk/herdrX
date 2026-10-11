import AppKit
import SwiftUI

// The production tab view is compiled directly; only app-wide presentation dependencies are stubbed.
func L(_ value: String) -> String { value }
func LF(_ value: String, _ count: Int) -> String { String(format: value, count) }
enum Theme {
    static let foreground = NSColor.labelColor, secondary = NSColor.secondaryLabelColor, accent = NSColor.systemBlue
}
final class ActionMenuItem: NSMenuItem {
    let invoke: () -> Void
    init(_ title: String, enabled: Bool, action: @escaping () -> Void) { invoke = action; super.init(title: title, action: nil, keyEquivalent: ""); isEnabled = enabled }
    required init(coder: NSCoder) { fatalError() }
}
final class TabSnapshotBackground: NSView {
    override func draw(_ dirtyRect: NSRect) { NSColor.windowBackgroundColor.setFill(); dirtyRect.fill() }
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
        print("PASS: tab scroll containment, stable selection geometry, clicked context target, grouped/conditional/offline menus; 28pt bar / 22pt pills / 3pt insets")
    }
}
