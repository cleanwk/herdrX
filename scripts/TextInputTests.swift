import AppKit
import SwiftUI

func L(_ value: String) -> String { value }

/// Exercise field-editor dispatch without posting events or using the user's IME.
@main struct TextInputTests {
    @MainActor final class Editor: NSTextView {
        var composing = false
        override func hasMarkedText() -> Bool { composing }
    }
    @MainActor static func main() {
        _ = NSApplication.shared
        let field = NSTextField(), editor = Editor()
        var value = "标签页"
        var saves = 0, cancels = 0, moves = 0
        let binding = Binding(get: { value }, set: { value = $0 })
        let rename = RenameInput.Coordinator(RenameInput(text: binding, submit: { saves += 1 }, cancel: { cancels += 1 }))
        let search = SearchInput.Coordinator(SearchInput(text: binding, move: { moves += $0 }, submit: { saves += 1 }, cancel: { cancels += 1 }))
        let enter = #selector(NSResponder.insertNewline(_:)), escape = #selector(NSResponder.cancelOperation(_:))
        let down = #selector(NSResponder.moveDown(_:))
        editor.composing = true
        for command in [enter, escape, down] {
            precondition(!rename.control(field, textView: editor, doCommandBy: command), "Rename consumed an IME command")
            precondition(!search.control(field, textView: editor, doCommandBy: command), "Search consumed an IME command")
        }
        precondition(saves == 0 && cancels == 0 && moves == 0)
        editor.composing = false
        precondition(rename.control(field, textView: editor, doCommandBy: enter))
        precondition(rename.control(field, textView: editor, doCommandBy: escape))
        precondition(!rename.control(field, textView: editor, doCommandBy: down))
        precondition(search.control(field, textView: editor, doCommandBy: down))
        precondition(search.control(field, textView: editor, doCommandBy: enter))
        precondition(search.control(field, textView: editor, doCommandBy: escape))
        precondition(saves == 2 && cancels == 2 && moves == 1)
        field.stringValue = "发布检查"
        rename.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: field))
        precondition(value == "发布检查", "Rename lost committed text")
        print("PASS: rename/search leave marked-text Enter, Escape and arrows to IME; committed text and ordinary commands still work")
    }
}
