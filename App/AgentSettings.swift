import SwiftUI

struct AgentSettings: View {
    static let tools = [("claude", "Claude"), ("codex", "Codex"), ("cursor", "Cursor"), ("gemini", "Gemini"), ("grok", "Grok"), ("kimi", "Kimi"), ("opencode", "OpenCode"), ("pi", "Pi"), ("omp", "Oh My Pi"), ("copilot", "Copilot")]
    var body: some View {
        Form {
            Section("Local command overrides") { ForEach(Self.tools, id: \.0) { AgentCommand(kind: $0.0, title: $0.1) } }
            Text("Overrides apply only to local devices. Leave blank for Herdr’s automatic launch. Commands are parsed as argv without shell expansion. Finder launches use a login shell with ~/.local/bin, /opt/homebrew/bin and /usr/local/bin in PATH.").font(.caption).foregroundStyle(.secondary)
        }.formStyle(.grouped)
    }
}
private struct AgentCommand: View {
    let kind: String
    let title: String
    @AppStorage private var command: String
    @AppStorage private var attachmentMode: String
    init(kind: String, title: String) { self.kind = kind; self.title = title; _command = AppStorage(wrappedValue: "", "agentCommand." + kind); _attachmentMode = AppStorage(wrappedValue: "unknown", "attachmentMode." + kind) }
    var body: some View { VStack(alignment: .leading) { TextField(title, text: $command, prompt: Text("Automatic")); Picker("File capability", selection: $attachmentMode) { Text("Unknown — do not deliver").tag("unknown"); Text("Accepts file path references").tag("path"); Text("Local clipboard images via Ctrl-V").tag("clipboard") }.font(.caption) } }
}
