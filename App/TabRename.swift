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
