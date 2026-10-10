import AppKit
import SwiftUI
import HerdCore

struct TabRenameRequest: Identifiable {
    let id = UUID()
    let device: String
    let tab: String
    let space: String
    let endpoint: Device.Endpoint
    let current: String
}

struct TabRenameSheet: View {
    @EnvironmentObject private var desk: Desk
    @Environment(\.dismiss) private var dismiss
    let request: TabRenameRequest
    @State private var name: String
    @State private var busy = false
    @State private var error: String?

    init(request: TabRenameRequest) {
        self.request = request
        _name = State(initialValue: request.current)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rename Tab").font(.headline)
            RenameInput(text: $name, submit: submit, cancel: cancel).frame(height: 24).disabled(busy)
            Text("Use Chinese, spaces or symbols to name this tab.").font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if let error { Text(error).foregroundStyle(.red).textSelection(.enabled).fixedSize(horizontal: false, vertical: true) }
            HStack {
                Spacer()
                Button("Cancel", action: cancel).keyboardShortcut(.cancelAction).disabled(busy)
                Button(LocalizedStringKey(busy ? "Renaming…" : "Rename"), action: submit)
                    .keyboardShortcut(.defaultAction).disabled(busy || TabName.changed(name, from: request.current) == nil)
            }
        }.padding(24).frame(width: 400).interactiveDismissDisabled(busy).background(SheetCloseHandler(close: cancel))
    }
    private func cancel() { if !busy { dismiss() } }
    private func submit() {
        guard !busy, TabName.changed(name, from: request.current) != nil else { return }
        busy = true; error = nil
        Task {
            do { try await desk.submitTabRename(request, name: name); dismiss() }
            catch { self.error = LF("Could not rename the tab: %@", error.localizedDescription) }
            busy = false
        }
    }
}

/// Select once when the sheet mounts; later validation must not reset the editor/IME.
private struct RenameInput: NSViewRepresentable {
    @Environment(\.isEnabled) private var enabled
    @Binding var text: String
    let submit: () -> Void
    let cancel: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: text)
        field.delegate = context.coordinator
        field.setAccessibilityLabel(L("Name"))
        DispatchQueue.main.async { [weak field] in
            guard let field, let window = field.window else { return }
            window.makeFirstResponder(field); field.selectText(nil)
        }
        return field
    }
    func updateNSView(_ field: NSTextField, context: Context) { context.coordinator.parent = self; field.isEnabled = enabled }
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: RenameInput
        init(_ parent: RenameInput) { self.parent = parent }
        func controlTextDidChange(_ notification: Notification) {
            if let field = notification.object as? NSTextField { parent.text = field.stringValue }
        }
        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            if selector == #selector(NSResponder.insertNewline(_:)) { parent.submit(); return true }
            if selector == #selector(NSResponder.cancelOperation(_:)) { parent.cancel(); return true }
            return false
        }
    }
}
