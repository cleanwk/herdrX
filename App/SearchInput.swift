import AppKit
import SwiftUI

/// Field-editor commands keep IME composition intact and handle navigation once.
struct SearchInput: NSViewRepresentable {
    @Binding var text: String
    let move: (Int) -> Void
    let submit: () -> Void
    let cancel: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> Field {
        let field = Field(); field.isBordered = false; field.drawsBackground = false; field.focusRingType = .none
        field.font = .systemFont(ofSize: 14); field.placeholderString = L("Jump to a space, terminal or agent"); field.setAccessibilityLabel(L("Search")); field.delegate = context.coordinator
        return field
    }
    func updateNSView(_ field: Field, context: Context) { context.coordinator.parent = self; if field.stringValue != text { field.stringValue = text } }
    final class Field: NSTextField {
        private var focusedOnce = false
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); if let window, !focusedOnce { focusedOnce = true; DispatchQueue.main.async { window.makeFirstResponder(self) } } }
    }
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: SearchInput
        init(_ parent: SearchInput) { self.parent = parent }
        func controlTextDidChange(_ obj: Notification) { if let field = obj.object as? NSTextField { parent.text = field.stringValue } }
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            guard !textView.hasMarkedText() else { return false }
            switch commandSelector {
            case #selector(NSResponder.moveDown(_:)): parent.move(1)
            case #selector(NSResponder.moveUp(_:)): parent.move(-1)
            case #selector(NSResponder.insertNewline(_:)): parent.submit()
            case #selector(NSResponder.cancelOperation(_:)): parent.cancel()
            default: return false
            }
            return true
        }
    }
}
