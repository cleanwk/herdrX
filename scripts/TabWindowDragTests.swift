import AppKit
import SwiftUI

// Drags a tab with real HID mouse events in a SwiftUI `Window` with a hidden
// title bar, the same shape as the app. Synthetic `sendEvent` tests bypass the
// window server and missed the title-bar window drag that ate tab drags.
func L(_ value: String) -> String { value }
func LF(_ value: String, _ count: Int) -> String { String(format: value, count) }
enum Theme {
    static let selectedText = NSColor.labelColor, selectedSecondary = NSColor.secondaryLabelColor
    static let tabWash = NSColor.selectedControlColor, accentStroke = NSColor.controlAccentColor, foreground = NSColor.labelColor
    static let tabInactiveWash = NSColor.quaternaryLabelColor, tabHoverWash = NSColor.tertiaryLabelColor, tabText = NSColor.labelColor, chrome = NSColor.windowBackgroundColor
}
final class ActionMenuItem: NSMenuItem {
    init(_ title: String, enabled: Bool, action: @escaping () -> Void) { super.init(title: title, action: nil, keyEquivalent: ""); isEnabled = enabled }
    required init(coder: NSCoder) { fatalError() }
}
final class Model: ObservableObject {
    static let shared = Model()
    @Published var entries = [TabEntry(id: "a", title: "Alpha", count: 1), TabEntry(id: "b", title: "Bravo", count: 1), TabEntry(id: "c", title: "Charlie", count: 1)]
    var order: String { entries.map(\.id).joined() }
    func move(_ id: String, _ insertion: Int) {
        let old = entries.firstIndex { $0.id == id }!
        let entry = entries.remove(at: old); entries.insert(entry, at: insertion > old ? insertion - 1 : insertion)
    }
}
// Mirrors WindowBehavior: the rest of the window stays draggable by its background.
struct Background: NSViewRepresentable {
    final class View: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); window?.isMovableByWindowBackground = true }
    }
    func makeNSView(context: Context) -> View { View() }
    func updateNSView(_ view: View, context: Context) {}
}
// Mirrors Workbench: sidebar, then the tab bar pulled into the title bar area.
struct Root: View {
    @ObservedObject var model = Model.shared
    var body: some View {
        HStack(spacing: 0) {
            Color.secondary.opacity(0.1).frame(width: 260)
            VStack(spacing: 0) {
                HStack(spacing: 4) {
                    Tabs(scope: "s", entries: model.entries, selected: "b", select: { _ in }, move: model.move, rename: { _ in }, close: { _ in }, writable: true)
                    Button {} label: { Image(systemName: "plus") }
                }.buttonStyle(.borderless).frame(height: TabMetrics.barHeight).background(Color(nsColor: .windowBackgroundColor)).zIndex(1)
                Divider()
                Color.gray.opacity(0.2)
            }
        }.background(Color.black.opacity(0.05)).background(Background()).ignoresSafeArea(.container, edges: .top)
    }
}
func findStrip(_ view: NSView) -> Tabs.Strip? {
    if let strip = view as? Tabs.Strip { return strip }
    for sub in view.subviews { if let strip = findStrip(sub) { return strip } }
    return nil
}
func post(_ type: CGEventType, _ point: CGPoint) {
    CGEvent(mouseEventSource: CGEventSource(stateID: .hidSystemState), mouseType: type, mouseCursorPosition: point, mouseButton: .left)!.post(tap: .cghidEventTap)
}
func drag(from start: CGPoint, by delta: CGVector) {
    post(.mouseMoved, start); Thread.sleep(forTimeInterval: 0.4)
    post(.leftMouseDown, start); Thread.sleep(forTimeInterval: 0.15)
    for step in 1...24 {
        post(.leftMouseDragged, CGPoint(x: start.x + delta.dx * CGFloat(step) / 24, y: start.y + delta.dy * CGFloat(step) / 24)); Thread.sleep(forTimeInterval: 0.03)
    }
    Thread.sleep(forTimeInterval: 0.15); post(.leftMouseUp, CGPoint(x: start.x + delta.dx, y: start.y + delta.dy)); Thread.sleep(forTimeInterval: 0.6)
}
func onMain<T>(_ body: @MainActor () -> T) -> T { DispatchQueue.main.sync { MainActor.assumeIsolated { body() } } }
func screenPoint(_ window: NSWindow, _ point: NSPoint) -> CGPoint {
    let p = window.convertPoint(toScreen: point)
    return CGPoint(x: p.x, y: NSScreen.screens[0].frame.height - p.y)
}
var failures: [String] = []
func expect(_ condition: Bool, _ message: String) { if !condition { failures.append(message) } }

final class Delegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard CGPreflightPostEventAccess() else {
            print("tab window drag tests: cannot post HID events (grant Accessibility to the terminal)")
            exit(ProcessInfo.processInfo.environment["CI"] == nil ? 0 : 1)
        }
        Thread.detachNewThread {
            Thread.sleep(forTimeInterval: 2)
            let (window, tab, titleBackground) = onMain { () -> (NSWindow, CGPoint, CGPoint) in
                let window = NSApp.windows.first { $0.contentView.flatMap(findStrip) != nil }!
                NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil)
                let button = findStrip(window.contentView!)!.buttons[0]
                let tab = screenPoint(window, button.convert(NSPoint(x: button.bounds.midX, y: button.bounds.midY), to: nil))
                // Sidebar top: inside the hidden title bar but outside the tab strip.
                let titleBackground = screenPoint(window, NSPoint(x: 130, y: window.frame.height - 14))
                return (window, tab, titleBackground)
            }
            let origin = onMain { window.frame.origin }
            drag(from: tab, by: CGVector(dx: 240, dy: 0))
            let afterTabDrag = onMain { window.frame.origin }
            expect(Model.shared.order == "bca", "dragging Alpha past Charlie should reorder to bca, got \(Model.shared.order)")
            expect(afterTabDrag == origin, "tab drag moved the window \(origin) -> \(afterTabDrag)")
            drag(from: titleBackground, by: CGVector(dx: 0, dy: 50))
            onMain {
                expect(window.frame.origin != afterTabDrag, "title-bar background drag should still move the window")
                expect(window.isMovable, "window should be movable again once the pointer leaves the tabs")
                if failures.isEmpty { print("tab window drag tests passed") } else { failures.forEach { print("FAIL:", $0) } }
                exit(failures.isEmpty ? 0 : 1)
            }
        }
    }
}
@main struct TabWindowDragTests: App {
    @NSApplicationDelegateAdaptor(Delegate.self) var delegate
    var body: some Scene {
        Window("Tab drag", id: "tab-drag") { Root().frame(minWidth: 900, minHeight: 400) }.windowStyle(.hiddenTitleBar)
    }
}
