import AppKit
import SwiftUI
import ObjectiveC

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

final class ProbeApp: NSApplication {
    var counts: [String: Int] = [:]
    var log = false
    override func sendEvent(_ event: NSEvent) {
        if [.leftMouseDown, .leftMouseDragged, .leftMouseUp].contains(event.type) {
            counts["\(event.type.rawValue)", default: 0] += 1
            if log { print("  app event", event.type.rawValue, event.locationInWindow, event.window?.windowNumber ?? -1) }
        }
        super.sendEvent(event)
    }
}

final class Model: ObservableObject {
    @Published var entries = [TabEntry(id: "a", title: "Alpha tab", count: 1), TabEntry(id: "b", title: "Bravo", count: 1), TabEntry(id: "c", title: "Charlie", count: 1), TabEntry(id: "d", title: "Delta", count: 1)]
    var moves: [(String, Int)] = []
    func move(_ id: String, _ insertion: Int) {
        moves.append((id, insertion))
        let old = entries.firstIndex { $0.id == id }!
        let e = entries.remove(at: old); entries.insert(e, at: insertion > old ? insertion - 1 : insertion)
    }
}
struct Bg: NSViewRepresentable {
    final class V: NSView { override var mouseDownCanMoveWindow: Bool { true }
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); window?.isMovableByWindowBackground = true } }
    func makeNSView(context: Context) -> V { V() }
    func updateNSView(_ v: V, context: Context) {}
}
struct Root: View {
    @ObservedObject var model: Model
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Tabs(scope: "s", entries: model.entries, selected: "b", select: { _ in }, move: model.move, rename: { _ in }, close: { _ in }, writable: true)
                Button("+") {}
            }.padding(.leading, 78).frame(height: TabMetrics.barHeight)
            Color.gray.opacity(0.2)
        }.background(Bg()).ignoresSafeArea(.container, edges: .top)
    }
}

func inject() {
    let block: @convention(block) (NSView) -> NSRect = { $0.bounds }
    let imp = imp_implementationWithBlock(block)
    let sel = NSSelectorFromString("_opaqueRectForWindowMoveWhenInTitlebar")
    print("NSView responds to private selector:", NSView.instancesRespond(to: sel))
    for cls: AnyClass in [Tabs.Strip.TabButton.self, Tabs.Strip.self, Tabs.HorizontalScrollView.self, Tabs.HorizontalClipView.self] {
        print("  add", cls, class_addMethod(cls, sel, imp, "{CGRect={CGPoint=dd}{CGSize=dd}}@:"))
    }
}

func findStrip(_ view: NSView) -> Tabs.Strip? {
    if let s = view as? Tabs.Strip { return s }
    for sub in view.subviews { if let s = findStrip(sub) { return s } }
    return nil
}

@MainActor func makeWindow(swiftUI: Bool, fullSize: Bool, model: Model) -> NSWindow {
    var mask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
    if fullSize { mask.insert(.fullSizeContentView) }
    let w = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 900, height: 400), styleMask: mask, backing: .buffered, defer: false)
    w.isReleasedWhenClosed = false
    w.titleVisibility = .hidden; w.titlebarAppearsTransparent = true; w.isMovableByWindowBackground = true
    if swiftUI { w.contentView = NSHostingView(rootView: Root(model: model)) }
    else {
        let host = w.contentView!
        let scroll = Tabs.HorizontalScrollView(frame: NSRect(x: 78, y: host.bounds.maxY - 28, width: host.bounds.width - 120, height: 28))
        scroll.autoresizingMask = [.width, .minYMargin]
        let strip = Tabs.Strip(); scroll.documentView = strip; host.addSubview(scroll)
        strip.entries = model.entries; strip.selected = "b"; strip.writable = true
        strip.move = { id, i in model.move(id, i); strip.entries = model.entries; strip.syncButtons(); scroll.fitDocument() }
        strip.select = { _ in }
        strip.syncButtons(); scroll.fitDocument()
    }
    w.center(); w.makeKeyAndOrderFront(nil)
    return w
}

func post(_ type: CGEventType, _ p: CGPoint) {
    let e = CGEvent(mouseEventSource: CGEventSource(stateID: .hidSystemState), mouseType: type, mouseCursorPosition: p, mouseButton: .left)!
    e.post(tap: .cghidEventTap)
}
func onMain<T>(_ f: @MainActor () -> T) -> T { DispatchQueue.main.sync { MainActor.assumeIsolated { f() } } }

func scenario(_ name: String, swiftUI: Bool, fullSize: Bool) {
    let model = Model()
    let window = onMain { makeWindow(swiftUI: swiftUI, fullSize: fullSize, model: model) }
    Thread.sleep(forTimeInterval: 1.0)
    let (start, frame, info): (CGPoint, NSRect, String) = onMain {
        NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil)
        window.contentView?.layoutSubtreeIfNeeded()
        let strip = findStrip(window.contentView!)!
        let button = strip.buttons[0]
        let local = NSPoint(x: button.bounds.midX, y: button.bounds.midY)
        let screen = window.convertPoint(toScreen: button.convert(local, to: nil))
        let h = NSScreen.screens[0].frame.height
        let titlebarHeight = window.frame.height - window.contentLayoutRect.height
        let inTitlebar = window.contentLayoutRect.maxY < button.convert(local, to: nil).y
        return (CGPoint(x: screen.x, y: h - screen.y), window.frame, "titlebarHeight=\(titlebarHeight) pointInTitlebar=\(inTitlebar) hit=\(String(describing: window.contentView?.superview?.hitTest(button.convert(local, to: nil)).map { type(of: $0) }))")
    }
    // Activate with a click on the content body first.
    let body = CGPoint(x: start.x, y: start.y + 200)
    post(.leftMouseDown, body); Thread.sleep(forTimeInterval: 0.08); post(.leftMouseUp, body); Thread.sleep(forTimeInterval: 0.4)
    onMain { (NSApp as! ProbeApp).counts = [:] }
    post(.leftMouseDown, start); Thread.sleep(forTimeInterval: 0.15)
    var dragged = false
    for step in 1...20 {
        post(.leftMouseDragged, CGPoint(x: start.x + CGFloat(step) * 15, y: start.y)); Thread.sleep(forTimeInterval: 0.03)
        if step == 15 { dragged = onMain { findStrip(window.contentView!)!.dragged } }
    }
    Thread.sleep(forTimeInterval: 0.1)
    post(.leftMouseUp, CGPoint(x: start.x + 300, y: start.y)); Thread.sleep(forTimeInterval: 0.6)
    let result = onMain { () -> String in
        let moved = window.frame.origin != frame.origin
        let s = "[\(name)] \(info) appEvents=\((NSApp as! ProbeApp).counts) stripDraggedMid=\(dragged) moves=\(model.moves) order=\(model.entries.map(\.id).joined()) windowMoved=\(moved) (\(frame.origin) -> \(window.frame.origin))"
        window.orderOut(nil); window.close(); return s
    }
    print(result)
}

final class Delegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("CGPreflightPostEventAccess:", CGPreflightPostEventAccess(), "AXIsProcessTrusted:", AXIsProcessTrusted(), "macOS:", ProcessInfo.processInfo.operatingSystemVersionString)
        Thread.detachNewThread {
            scenario("appkit-below-titlebar(control)", swiftUI: false, fullSize: false)
            scenario("appkit-fullsize-titlebar", swiftUI: false, fullSize: true)
            scenario("swiftui-fullsize-titlebar", swiftUI: true, fullSize: true)
            onMain { inject() }
            scenario("appkit-fullsize-titlebar+opaqueRect", swiftUI: false, fullSize: true)
            scenario("swiftui-fullsize-titlebar+opaqueRect", swiftUI: true, fullSize: true)
            exit(0)
        }
    }
}

@main struct Probe {
    static func main() {
        let app = ProbeApp.shared as! ProbeApp
        app.setActivationPolicy(.regular)
        let d = Delegate(); app.delegate = d
        app.run()
    }
}
