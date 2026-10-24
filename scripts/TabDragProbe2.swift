import AppKit
import SwiftUI

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
let variant = ProcessInfo.processInfo.environment["VARIANT"] ?? "baseline"
final class Model: ObservableObject {
    static let shared = Model()
    @Published var entries = [TabEntry(id: "a", title: "Alpha", count: 1), TabEntry(id: "b", title: "Bravo", count: 1), TabEntry(id: "c", title: "Charlie", count: 1)]
    func move(_ id: String, _ insertion: Int) {
        let old = entries.firstIndex { $0.id == id }!
        let e = entries.remove(at: old); entries.insert(e, at: insertion > old ? insertion - 1 : insertion)
    }
}
struct Bg: NSViewRepresentable {
    final class V: NSView { override var mouseDownCanMoveWindow: Bool { true }
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); if variant != "nomovablebg" { window?.isMovableByWindowBackground = true } } }
    func makeNSView(context: Context) -> V { V() }
    func updateNSView(_ v: V, context: Context) {}
}
struct Root: View {
    @ObservedObject var model = Model.shared
    var body: some View {
        HStack(spacing: 0) {
            Color.secondary.opacity(0.1).frame(width: 260)
            VStack(spacing: 0) {
                HStack(spacing: 4) {
                    Tabs(scope: "s", entries: model.entries, selected: "b", select: { _ in }, move: model.move, rename: { _ in }, close: { _ in }, writable: true)
                    Button { } label: { Image(systemName: "plus") }
                }.buttonStyle(.borderless).frame(height: TabMetrics.barHeight).background(Color(nsColor: .windowBackgroundColor)).zIndex(1)
                Divider()
                Color.gray.opacity(0.2)
            }
        }.background(Color.black.opacity(0.05)).background(Bg()).ignoresSafeArea(.container, edges: variant == "safearea" ? [] : .top)
    }
}
func findStrip(_ view: NSView) -> Tabs.Strip? {
    if let s = view as? Tabs.Strip { return s }
    for sub in view.subviews { if let s = findStrip(sub) { return s } }
    return nil
}
func post(_ type: CGEventType, _ p: CGPoint) {
    CGEvent(mouseEventSource: CGEventSource(stateID: .hidSystemState), mouseType: type, mouseCursorPosition: p, mouseButton: .left)!.post(tap: .cghidEventTap)
}
func onMain<T>(_ f: @MainActor () -> T) -> T { DispatchQueue.main.sync { MainActor.assumeIsolated { f() } } }
final class Delegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Tabs.Strip.pressMode = ["baseline", "safearea", "movableoff", "bgdisabled"].contains(variant) ? "none" : variant
        Thread.detachNewThread {
            Thread.sleep(forTimeInterval: 2)
            let (window, start) = onMain { () -> (NSWindow, CGPoint) in
                let window = NSApp.windows.first { $0.contentView.flatMap(findStrip) != nil }!
                NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil)
                if variant == "movableoff" { window.isMovable = false }
                let button = findStrip(window.contentView!)!.buttons[0]
                let p = window.convertPoint(toScreen: button.convert(NSPoint(x: button.bounds.midX, y: button.bounds.midY), to: nil))
                return (window, CGPoint(x: p.x, y: NSScreen.screens[0].frame.height - p.y))
            }
            let origin = onMain { window.frame.origin }
            post(.mouseMoved, CGPoint(x: start.x - 30, y: start.y + 60)); Thread.sleep(forTimeInterval: 0.2)
            post(.mouseMoved, start); Thread.sleep(forTimeInterval: 0.4)
            post(.leftMouseDown, start); Thread.sleep(forTimeInterval: 0.15)
            for step in 1...24 { post(.leftMouseDragged, CGPoint(x: start.x + CGFloat(step) * 10, y: start.y)); Thread.sleep(forTimeInterval: 0.03) }
            Thread.sleep(forTimeInterval: 0.15); post(.leftMouseUp, CGPoint(x: start.x + 240, y: start.y)); Thread.sleep(forTimeInterval: 0.6)
            // Then a plain background drag in the title area must still move the window.
            let bgStart = CGPoint(x: start.x + 380, y: start.y)
            let mid = onMain { window.frame.origin }
            post(.mouseMoved, bgStart); Thread.sleep(forTimeInterval: 0.4)
            post(.leftMouseDown, bgStart); Thread.sleep(forTimeInterval: 0.15)
            for step in 1...10 { post(.leftMouseDragged, CGPoint(x: bgStart.x, y: bgStart.y + CGFloat(step) * 5)); Thread.sleep(forTimeInterval: 0.03) }
            post(.leftMouseUp, CGPoint(x: bgStart.x, y: bgStart.y + 50)); Thread.sleep(forTimeInterval: 0.6)
            onMain {
                print("[\(variant)] \(type(of: window)) order=\(Model.shared.entries.map(\.id).joined()) tabDragMovedWindow=\(window.frame.origin != origin ? "\(origin)->\(mid)" : "no") backgroundDragMovesWindow=\(window.frame.origin != mid) movable=\(window.isMovable)")
                exit(0)
            }
        }
    }
}
@main struct ProbeMain: App {
    @NSApplicationDelegateAdaptor(Delegate.self) var delegate
    var body: some Scene {
        #if BGDISABLED
        Window("Probe", id: "p") { Root().frame(minWidth: 900, minHeight: 400) }.windowStyle(.hiddenTitleBar).windowBackgroundDragBehavior(.disabled)
        #else
        Window("Probe", id: "p") { Root().frame(minWidth: 900, minHeight: 400) }.windowStyle(.hiddenTitleBar)
        #endif
    }
}
