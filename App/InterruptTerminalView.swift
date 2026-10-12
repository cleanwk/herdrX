import AppKit

/// Keep the physical interrupt usable even when Kitty encodes Ctrl-C as CSI u.
/// The callback sends ETX; recovery still verifies the foreground shell first.
class InterruptTerminalView: SelectionTerminalView {
    var onInterrupt: (() -> Bool)?
    private var interruptedKeys: Set<UInt16> = []

    private func isInterrupt(_ event: NSEvent) -> Bool {
        !hasMarkedText()
            && event.modifierFlags.intersection([.command, .control, .option, .shift]) == .control
            && event.charactersIgnoringModifiers?.lowercased() == "c"
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.type == .keyDown, window?.firstResponder === self, isInterrupt(event), onInterrupt != nil {
            keyDown(with: event)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if isInterrupt(event), onInterrupt?() == true {
            interruptedKeys.insert(event.keyCode)
            return
        }
        super.keyDown(with: event)
    }

    override func keyUp(with event: NSEvent) {
        // Match the physical key even if Control was released before C.
        if interruptedKeys.remove(event.keyCode) != nil { return }
        super.keyUp(with: event)
    }
}
