import AppKit
import GhosttyTerminal
import GhosttyKit

/// A left gesture belongs to either the local selection or the terminal app.
/// Delaying captured clicks lets a drag choose selection without leaking input.
class SelectionTerminalView: AppTerminalView {
    private var keyDownDepth = 0

    // A preedit caret is not the host document's insertion point. Keep it
    // stable while asynchronous input methods (including Doubao) compose.
    override func selectedRange() -> NSRange { NSRange(location: 0, length: 0) }
    override func markedRange() -> NSRange { hasMarkedText() ? super.markedRange() : NSRange(location: 0, length: 0) }

    override func keyDown(with event: NSEvent) {
        keyDownDepth += 1
        defer { keyDownDepth -= 1 }
        super.keyDown(with: event)
    }

    override func insertText(_ string: Any, replacementRange: NSRange) {
        // The pinned adapter must collect synchronous commits while it
        // interprets a physical key, preserving modifiers and key encoding.
        guard keyDownDepth == 0 else {
            super.insertText(string, replacementRange: replacementRange)
            return
        }
        guard let text = (string as? NSAttributedString)?.string ?? (string as? String) else { return }
        unmarkText()
        guard !text.isEmpty else { return }
        // Dictation can commit after the shortcut is released, with no current
        // NSEvent. The adapter drops that case or treats it as clipboard paste.
        // Ghostty's supported text action writes the committed UTF-8 without
        // paste framing. Escape every byte for its Zig string-literal parser.
        let escaped = text.utf8.map { String(format: "\\x%02x", $0) }.joined()
        _ = performBindingAction("text:" + escaped)
    }

    static let configurationWillChange = Notification.Name("HerdrXTerminalConfigurationWillChange")
    weak var hostSurface: TerminalSurface? {
        willSet { if hostSurface !== newValue { cancelSelectionGesture() } }
    }
    private enum Gesture { case idle, pending(NSEvent), local }
    private var gesture = Gesture.idle
    private var origin: NSEvent?
    private var restoresReporting = false
    private var copyEligible = false
    private var observers: [NSObjectProtocol] = []
    private var feedbackRevision = 0
    private let feedback = CopyFeedback(labelWithString: "")
    var allowsRemoteScroll = true
    var onRemoteScroll: ((NSEvent) -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        feedback.isHidden = true
        feedback.font = .systemFont(ofSize: 11, weight: .medium)
        feedback.textColor = Theme.success
        feedback.backgroundColor = Theme.content
        feedback.drawsBackground = true
        addSubview(feedback)
        for name in [NSWindow.didResignKeyNotification, Self.configurationWillChange] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                MainActor.assumeIsolated {
                    guard let self, name == Self.configurationWillChange || (note.object as? NSWindow) === self.window else { return }
                    self.cancelSelectionGesture()
                }
            })
        }
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    deinit { for observer in observers { NotificationCenter.default.removeObserver(observer) } }

    override func scrollWheel(with event: NSEvent) {
        guard allowsRemoteScroll else {
            showFeedback(L("Viewing only — reconnect to scroll."), color: Theme.secondary, coalesce: true)
            return
        }
        guard case .idle = gesture, hostSurface != nil else {
            // A selection drag retains the engine's local scroll/anchor behavior.
            super.scrollWheel(with: event)
            return
        }
        if let onRemoteScroll { onRemoteScroll(event); return }
        forwardRemoteScroll(with: event)
    }

    /// Called only after the owner has chosen live-TUI routing. Do not re-enter the gate.
    func forwardRemoteScroll(with event: NSEvent) {
        guard allowsRemoteScroll, case .idle = gesture, let surface = hostSurface else { return }
        // Herdr renders a viewport into our surface. Its history and the Agent's
        // TUI scrolling live upstream, so wheel reports must reach `terminal
        // attach` even when the user prefers local clicks and text selection.
        let reporting = !(UserDefaults.standard.object(forKey: "disableMouseReporting") as? Bool ?? true)
        if reporting { _ = surface.performBindingAction("toggle_mouse_reporting") }
        // Refresh position/modifiers without emitting a DEC 1003 hover event.
        let point = convert(event.locationInWindow, from: nil)
        surface.sendMousePos(x: -1, y: -1)
        surface.sendMousePos(x: point.x, y: bounds.height - point.y,
            modifiers: TerminalInputModifiers(from: event.modifierFlags))
        _ = surface.performBindingAction("toggle_mouse_reporting")
        defer { if !reporting { _ = surface.performBindingAction("toggle_mouse_reporting") } }
        // Keep native precision, direction and momentum; Ghostty accumulates
        // small trackpad deltas and encodes the requested mouse protocol.
        super.scrollWheel(with: event)
    }
    func scrollFailed() {
        showFeedback(L("Could not verify terminal state. Try scrolling again."), color: Theme.secondary, coalesce: true)
    }

    override func mouseDown(with event: NSEvent) {
        cancelSelectionGesture()
        feedbackRevision += 1; feedback.isHidden = true
        window?.makeFirstResponder(self)
        origin = event
        let reporting = !(UserDefaults.standard.object(forKey: "disableMouseReporting") as? Bool ?? true)
        if reporting, hostSurface?.isMouseCaptured == true,
           event.modifierFlags.isDisjoint(with: [.shift, .command]), event.clickCount == 1 {
            gesture = .pending(event)
        } else {
            beginLocal(event)
        }
    }

    private func beginLocal(_ event: NSEvent) {
        // The pinned engine's Shift means "extend the old selection". Use its
        // supported reporting toggle instead of inventing Shift for a new anchor.
        // Disable reporting even before a TUI requests capture during this drag.
        let reporting = !(UserDefaults.standard.object(forKey: "disableMouseReporting") as? Bool ?? true)
        restoresReporting = reporting && hostSurface?.performBindingAction("toggle_mouse_reporting") == true
        gesture = .local
        copyEligible = event.clickCount > 1 || event.modifierFlags.contains(.shift)
        if event.modifierFlags.contains(.command), hostSurface?.isMouseCaptured == true {
            // Captured links require Shift for hover discovery in this engine.
            // Its embedded adapter drops same-position modifier changes, so
            // refresh hover before pressing. No key or shifted press is sent.
            let point = convert(event.locationInWindow, from: nil)
            hostSurface?.sendMousePos(x: -1, y: -1)
            hostSurface?.sendMousePos(x: point.x, y: bounds.height - point.y,
                modifiers: TerminalInputModifiers(from: event.modifierFlags).union(.shift))
        }
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        if case let .pending(start) = gesture {
            guard hypot(event.locationInWindow.x - start.locationInWindow.x,
                        event.locationInWindow.y - start.locationInWindow.y) >= 4 else { return }
            beginLocal(start)
        }
        guard case .local = gesture else { return }
        if let origin, hypot(event.locationInWindow.x - origin.locationInWindow.x,
                             event.locationInWindow.y - origin.locationInWindow.y) >= 4 { copyEligible = true }
        let point = convert(event.locationInWindow, from: nil)
        var y = bounds.height - point.y
        // One engine-owned timer drives stationary edge selection. Keep x and
        // the original anchor; don't scroll toward the selection's upper left.
        if y < 12 { y = -max(1, 12 - y) }
        else if y > bounds.height - 12 { y = bounds.height + max(1, y - (bounds.height - 12)) }
        hostSurface?.sendMousePos(x: point.x, y: y, modifiers: TerminalInputModifiers(from: event.modifierFlags))
    }

    override func mouseUp(with event: NSEvent) {
        switch gesture {
        case let .pending(start):
            // Position updates must not manufacture a DEC 1003 hover report
            // while replaying the deferred click. Real button modifiers remain.
            for (sample, state) in [(start, GHOSTTY_MOUSE_PRESS), (event, GHOSTTY_MOUSE_RELEASE)] {
                let point = convert(sample.locationInWindow, from: nil)
                let mods = TerminalInputModifiers(from: sample.modifierFlags)
                _ = hostSurface?.performBindingAction("toggle_mouse_reporting")
                hostSurface?.sendMousePos(x: point.x, y: bounds.height - point.y, modifiers: mods)
                _ = hostSurface?.performBindingAction("toggle_mouse_reporting")
                hostSurface?.sendMouseButton(state: state, button: GHOSTTY_MOUSE_LEFT, modifiers: mods)
            }
        case .local:
            if event.modifierFlags.contains(.command), hostSurface?.isMouseCaptured == true {
                let point = convert(event.locationInWindow, from: nil)
                let mods = TerminalInputModifiers(from: event.modifierFlags)
                // Preserve captured-link hover through the final position. A
                // plain position update clears it even with reporting disabled.
                hostSurface?.sendMousePos(x: point.x, y: bounds.height - point.y, modifiers: mods.union(.shift))
                hostSurface?.sendMouseButton(state: GHOSTTY_MOUSE_RELEASE, button: GHOSTTY_MOUSE_LEFT, modifiers: mods)
            } else {
                super.mouseUp(with: event)
            }
            if copyEligible, UserDefaults.standard.object(forKey: "copyOnSelect") as? Bool ?? true {
                _ = copySelectedTextToPasteboard()
            }
        case .idle: return
        }
        finishGesture()
    }

    func cancelSelectionGesture() {
        if case .local = gesture {
            // Release without a new position or Command modifier: no link open,
            // clipboard commit, scroll wheel, or TUI input on cancellation.
            hostSurface?.sendMouseButton(state: GHOSTTY_MOUSE_RELEASE, button: GHOSTTY_MOUSE_LEFT)
        }
        finishGesture()
    }
    private func finishGesture() {
        if restoresReporting { _ = hostSurface?.performBindingAction("toggle_mouse_reporting") }
        restoresReporting = false
        gesture = .idle; origin = nil; copyEligible = false
    }
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        cancelSelectionGesture()
        super.viewWillMove(toWindow: newWindow)
    }
    override func resignFirstResponder() -> Bool {
        cancelSelectionGesture()
        return super.resignFirstResponder()
    }
    override var isHidden: Bool {
        didSet { if isHidden { cancelSelectionGesture() } }
    }
    override func copySelectedTextToPasteboard() -> Bool {
        guard let text = hostSurface?.readSelection(), !text.isEmpty else { return false }
        let pasteboard = NSPasteboard.general
        let before = pasteboard.changeCount
        guard hostSurface?.performBindingAction("copy_to_clipboard:plain") == true,
              pasteboard.changeCount != before, pasteboard.string(forType: .string) == text else { return false }
        showFeedback(L("Copied"), color: Theme.success)
        return true
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if window?.firstResponder === self, !hasMarkedText(),
           event.modifierFlags.intersection([.command, .shift, .option, .control]) == .command,
           event.charactersIgnoringModifiers == "c", hostSurface?.hasSelection() == true {
            _ = copySelectedTextToPasteboard()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
    private func showFeedback(_ message: String, color: NSColor, coalesce: Bool = false) {
        // A trackpad gesture contains many events; announce the same visible
        // feedback once instead of flooding VoiceOver on every wheel sample.
        guard !coalesce || feedback.isHidden || feedback.stringValue != message else { return }
        feedbackRevision += 1
        let revision = feedbackRevision
        feedback.stringValue = message
        feedback.textColor = color
        feedback.sizeToFit()
        feedback.frame.origin = NSPoint(x: max(4, bounds.width - feedback.frame.width - 8), y: 4)
        feedback.isHidden = false
        NSAccessibility.post(element: self, notification: .announcementRequested, userInfo: [
            .announcement: message, .priority: NSAccessibilityPriorityLevel.low.rawValue
        ])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            guard let self, self.feedbackRevision == revision else { return }
            self.feedback.isHidden = true
        }
    }
    private final class CopyFeedback: NSTextField {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
