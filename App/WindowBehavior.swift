import AppKit
import SwiftUI

struct WindowBehavior: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowView { WindowView() }
    func updateNSView(_ view: WindowView, context: Context) {}
    final class WindowView: NSView {
        private var configured = false
        override var mouseDownCanMoveWindow: Bool { true }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window, !configured else { return }; configured = true
            window.isMovableByWindowBackground = true
            // The contract is the whole window, including the native title area.
            window.minSize = NSSize(width: 980, height: 620)
            #if DEBUG
            if let value = ProcessInfo.processInfo.environment["HERDRX_WINDOW_SIZE"] {
                let numbers = value.split(separator: "x").compactMap { Double($0) }
                if numbers.count == 2, numbers[0] >= 980, numbers[1] >= 620 {
                    DispatchQueue.main.async {
                        let area = window.screen?.visibleFrame ?? window.frame
                        window.setFrame(NSRect(x: area.minX + max(0, (area.width - numbers[0]) / 2), y: area.minY + max(0, (area.height - numbers[1]) / 2), width: numbers[0], height: numbers[1]), display: true)
                    }
                }
            }
            #endif
        }
    }
}

/// SwiftUI sheets have a separate responder chain from the workbench commands.
/// Consume only plain Cmd-W in the owning sheet; keep its presentation binding
/// authoritative instead of closing a server pane behind it.
struct SheetCloseHandler: NSViewRepresentable {
    let close: () -> Void
    func makeNSView(context: Context) -> KeyView { KeyView(close: close) }
    func updateNSView(_ view: KeyView, context: Context) { view.close = close }
    final class KeyView: NSView {
        var close: () -> Void
        private var monitor: Any?
        init(close: @escaping () -> Void) { self.close = close; super.init(frame: .zero) }
        required init?(coder: NSCoder) { fatalError() }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, event.window === self.window,
                      event.modifierFlags.intersection([.command, .shift, .option, .control]) == .command,
                      event.charactersIgnoringModifiers == "w" else { return event }
                self.close(); return nil
            }
        }
        deinit { if let monitor { NSEvent.removeMonitor(monitor) } }
    }
}

struct ResizeStrip: NSViewRepresentable {
    @Binding var width: Double
    var limits: ClosedRange<Double>
    var direction: Double = 1
    var reset: Double
    func makeNSView(context: Context) -> Strip { Strip() }
    func updateNSView(_ view: Strip, context: Context) { view.width = width; view.limits = limits; view.direction = direction; view.reset = reset; view.changed = { width = $0 } }
    final class Strip: NSView {
        var width = 260.0
        var limits = 200.0...480.0
        var direction = 1.0
        var reset = 260.0
        var changed: ((Double) -> Void)?
        private var origin = 0.0
        private var initial = 0.0
        override var mouseDownCanMoveWindow: Bool { false }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func resetCursorRects() { addCursorRect(bounds, cursor: .resizeLeftRight) }
        override func mouseDown(with event: NSEvent) {
            if event.clickCount == 2 { changed?(reset); return }
            origin = event.locationInWindow.x; initial = width
        }
        override func mouseDragged(with event: NSEvent) { changed?(min(limits.upperBound, max(limits.lowerBound, initial + (event.locationInWindow.x - origin) * direction))) }
        override func mouseUp(with event: NSEvent) {}
    }
}
