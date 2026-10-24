import AppKit
import ApplicationServices

// Drives a running HerdrX through the window server: Accessibility for geometry,
// HID-level CGEvents for input. Usage: driver <pid> dump|click <label>|drag <from> <to>
func attr(_ e: AXUIElement, _ a: String) -> AnyObject? { var v: AnyObject?; return AXUIElementCopyAttributeValue(e, a as CFString, &v) == .success ? v : nil }
func text(_ e: AXUIElement, _ a: String) -> String { (attr(e, a) as? String) ?? "" }
func frame(_ e: AXUIElement) -> CGRect? {
    guard let p = attr(e, kAXPositionAttribute), let s = attr(e, kAXSizeAttribute) else { return nil }
    var point = CGPoint.zero, size = CGSize.zero
    AXValueGetValue(p as! AXValue, .cgPoint, &point); AXValueGetValue(s as! AXValue, .cgSize, &size)
    return CGRect(origin: point, size: size)
}
struct Node { let role: String; let label: String; let frame: CGRect; let element: AXUIElement }
func walk(_ e: AXUIElement, _ depth: Int = 0, into out: inout [Node]) {
    guard depth < 40 else { return }
    let label = [text(e, kAXTitleAttribute), text(e, kAXDescriptionAttribute), (attr(e, kAXValueAttribute) as? String) ?? ""].first { !$0.isEmpty } ?? ""
    out.append(Node(role: text(e, kAXRoleAttribute), label: label, frame: frame(e) ?? .zero, element: e))
    for child in (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] { walk(child, depth + 1, into: &out) }
}
let args = CommandLine.arguments
let pid = pid_t(args[1])!
let app = AXUIElementCreateApplication(pid)
func window() -> AXUIElement? { (attr(app, kAXWindowsAttribute) as? [AXUIElement])?.first }
func nodes() -> [Node] { var out: [Node] = []; if let w = window() { walk(w, into: &out) }; return out }
func tabs() -> [Node] { nodes().filter { $0.role == "AXRadioButton" && $0.label.hasPrefix("T-") }.sorted { $0.frame.minX < $1.frame.minX } }
func post(_ type: CGEventType, _ p: CGPoint) {
    CGEvent(mouseEventSource: CGEventSource(stateID: .hidSystemState), mouseType: type, mouseCursorPosition: p, mouseButton: .left)!.post(tap: .cghidEventTap)
}
func center(_ r: CGRect) -> CGPoint { CGPoint(x: r.midX, y: r.midY) }
NSRunningApplication(processIdentifier: pid)?.activate()
Thread.sleep(forTimeInterval: 0.3)
switch args[2] {
case "dump":
    print("window:", window().flatMap(frame).map { "\($0)" } ?? "none")
    for n in nodes() where !n.label.isEmpty || n.role == "AXRadioButton" { print(" ", n.role, "|", n.label, "|", n.frame) }
case "click":
    guard let n = nodes().first(where: { $0.label == args[3] && $0.frame.width > 0 }) else { print("NOT FOUND", args[3]); exit(2) }
    let p = center(n.frame); print("click", n.role, n.frame)
    post(.leftMouseDown, p); Thread.sleep(forTimeInterval: 0.06); post(.leftMouseUp, p)
case "drag":
    let list = tabs()
    print("tabs before:", list.map { "\($0.label)@\(Int($0.frame.minX))" })
    guard let from = list.first(where: { $0.label == args[3] }), let to = list.first(where: { $0.label == args[4] }) else { print("TABS NOT FOUND"); exit(2) }
    let windowBefore = window().flatMap(frame)
    let start = center(from.frame), end = CGPoint(x: to.frame.maxX + 12, y: start.y)
    post(.leftMouseDown, start); Thread.sleep(forTimeInterval: 0.15)
    for step in 1...24 {
        post(.leftMouseDragged, CGPoint(x: start.x + (end.x - start.x) * CGFloat(step) / 24, y: start.y)); Thread.sleep(forTimeInterval: 0.03)
    }
    Thread.sleep(forTimeInterval: 0.15); post(.leftMouseUp, end); Thread.sleep(forTimeInterval: 0.5)
    print("window before/after:", windowBefore.map { "\($0)" } ?? "?", window().flatMap(frame).map { "\($0)" } ?? "?")
    print("tabs right after release:", tabs().map { "\($0.label)@\(Int($0.frame.minX))" })
case "order":
    print("tabs:", tabs().map(\.label).joined(separator: ","))
default: exit(64)
}
