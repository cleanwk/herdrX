import SwiftUI
import AppKit
import GhosttyTerminal
import HerdCore
import Sparkle
import UserNotifications

struct Preferences: View {
    @EnvironmentObject var desk: Desk
    @State private var selected: String? = "Appearance"
    private let sections = [("Appearance", "circle.lefthalf.filled"), ("Terminal", "terminal"), ("Agents", "sparkles"), ("Notifications", "bell"), ("Devices", "server.rack"), ("Tailcat", "network"), ("Plugins", "puzzlepiece.extension"), ("Updates", "arrow.down.circle"), ("About", "info.circle")]
    var body: some View {
        NavigationSplitView {
            List(sections, id: \.0, selection: $selected) { entry in Label(LocalizedStringKey(entry.0), systemImage: entry.1).tag(entry.0) }.listStyle(.sidebar).navigationSplitViewColumnWidth(150)
        } detail: {
            Group {
                switch selected {
                case "Terminal": TerminalSettings()
                case "Agents": AgentSettings()
                case "Notifications": Notifications()
                case "Devices": Devices()
                case "Tailcat": TailcatSettings()
                case "Plugins": ExtensionSettings()
                case "Updates": Updates()
                case "About": About()
                default: Appearance()
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.frame(width: 740, height: 560)
    }

}
private struct Devices: View {
    @EnvironmentObject var desk: Desk
    @State private var name = ""
    @State private var target = ""
    @State private var socket = ""
    @State private var port = ""
    @State private var sshConfig = ""
    @State private var local = false
    @State private var editing: String?
    var body: some View {
        Form {
            Section("Saved devices") {
                Button("Discover Local Herdr Sessions") { desk.discoverSessions() }
                Button("Import Enabled Herdr Machines") { desk.importHerdrMachines() }
                ForEach(desk.devices) { device in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(device.displayName).fontWeight(.medium); Spacer()
                            Button("Edit") { editing = device.id; name = device.displayName; target = device.endpoint.target ?? ""; socket = device.endpoint.socketPath; port = device.endpoint.port.map(String.init) ?? ""; local = device.endpoint.kind == "local"; sshConfig = device.endpoint.sshConfig ?? "" }.disabled(device.endpoint.kind == "tailcat")
                            Button("Retry") { desk.connect(device) }
                            Button("Remove") {
                                let alert = NSAlert(); alert.messageText = "Forget \(device.displayName)?"; alert.informativeText = L("Only this connection is removed. Server sessions and processes continue."); alert.addButton(withTitle: L("Forget Connection")); alert.addButton(withTitle: L("Cancel"))
                                if alert.runModal() == .alertFirstButtonReturn { desk.remove(device.id) }
                            }
                        }
                        Text((device.endpoint.target.map { $0 + " · " } ?? "") + device.endpoint.socketPath).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                        Text(LocalizedStringKey(desk.connections[device.id] ?? "Disconnected")).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Section(LocalizedStringKey(editing == nil ? "Add a connection" : "Edit connection")) {
                TextField("Name", text: $name)
                Picker("Connection", selection: $local) { Text("SSH").tag(false); Text("Local Herdr session").tag(true) }.pickerStyle(.segmented)
                if !local { TextField("SSH host or config alias", text: $target); TextField("Port", text: $port, prompt: Text("Automatic")); TextField("SSH config file (optional)", text: $sshConfig) }
                TextField("Herdr socket", text: $socket, prompt: Text("/home/user/.config/herdr/herdr.sock"))
                Text("Use an absolute socket path for the intended named session. SSH uses your existing keys and SSH configuration.").font(.caption).foregroundStyle(.secondary)
                Button(LocalizedStringKey(editing == nil ? "Add Device" : "Save Changes")) {
                    guard socket.hasPrefix("/"), !socket.contains("\n"), local || (!target.hasPrefix("-") && !target.contains(where: \.isWhitespace)), port.isEmpty || Int(port).map({ (1...65535).contains($0) }) == true else { desk.message = "Enter a valid host, port and absolute socket path."; return }
                    let device = Device(id: editing ?? UUID().uuidString, displayName: name, endpoint: .init(kind: local ? "local" : "ssh", target: local ? nil : target, port: local ? nil : Int(port), socketPath: socket, sshConfig: local || sshConfig.isEmpty ? nil : sshConfig)); if editing != nil { desk.update(device) } else { desk.add(device) }; editing = nil; name = ""; target = ""; socket = ""
                }.disabled(name.isEmpty || socket.isEmpty || (!local && target.isEmpty))
                if editing != nil { Button("Cancel Editing") { editing = nil; name = ""; target = ""; socket = "" } }
            }
        }.formStyle(.grouped)
    }
}
private struct TerminalSettings: View {
    @AppStorage("fontSize") private var size = 13.0
    @AppStorage("fontFamily") private var family = "SF Mono"
    @AppStorage("lineSpacing") private var spacing = 1.0
    @AppStorage("fontWeight") private var weight = "Regular"
    @AppStorage("disableMouseReporting") private var noMouse = false
    @AppStorage("thinStrokes") private var thin = false
    @AppStorage("copyOnSelect") private var copy = false
    @State private var importError: String?
    @State private var families: [String] = ["SF Mono"]
    var body: some View {
        Form {
            Picker("Font", selection: $family) { ForEach(families, id: \.self) { Text($0).tag($0) } }
            HStack { Text("Size (pt)"); Slider(value: $size, in: 9...22, step: 0.5); Stepper(size.formatted(), value: $size, in: 9...22, step: 0.5).monospacedDigit() }
            HStack { Text("Line spacing"); Slider(value: $spacing, in: 1...1.4, step: 0.05); Text(spacing.formatted()).monospacedDigit() }
            Picker("Weight (system mono only)", selection: $weight) { ForEach(["Regular", "Medium", "Semibold", "Bold"], id: \.self) { Text(LocalizedStringKey($0)).tag($0) } }.disabled(family != "SF Mono")
            Toggle("Report mouse input to terminal apps", isOn: Binding(get: { !noMouse }, set: { noMouse = !$0 }))
            Toggle("Thin strokes", isOn: $thin)
            Toggle("Copy selection to clipboard", isOn: $copy)
            Button("Import Ghostty Font Once…") { importGhostty() }
            if let importError { Text(importError).font(.caption).foregroundStyle(.secondary) }
            Section("Preview") { Text("~/project $ herdr\n中文输入 · ASCII 0123456789").font(previewFont).lineSpacing(CGFloat((spacing - 1) * size)).padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6)) }
            Button("Restore Defaults") { size = 13; family = "SF Mono"; spacing = 1; thin = false; copy = false; noMouse = false; weight = "Regular" }
        }.formStyle(.grouped).onAppear {
            if families.count == 1 { families = Array(Set(NSFontManager.shared.availableFontFamilies.filter { NSFont(name: $0, size: 12)?.isFixedPitch == true } + ["SF Mono", family])).sorted() }
            apply()
        }.onChange(of: size) { apply() }.onChange(of: family) { apply() }.onChange(of: spacing) { apply() }.onChange(of: thin) { apply() }.onChange(of: copy) { apply() }.onChange(of: weight) { apply() }
    }
    func apply() { Theme.apply() }
    var previewFont: Font {
        guard family == "SF Mono" else { return .custom(family, size: size) }
        let selected: Font.Weight = switch weight { case "Medium": .medium; case "Semibold": .semibold; case "Bold": .bold; default: .regular }
        return .system(size: size, weight: selected, design: .monospaced)
    }
    func importGhostty() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/ghostty")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            var nextFamily = family, nextSize = size, found = false
            for line in text.components(separatedBy: .newlines) {
                let parts = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                guard parts.count == 2 else { continue }
                if parts[0] == "font-family", !parts[1].isEmpty { nextFamily = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\"")); found = true }
                if parts[0] == "font-size" { guard let value = Double(parts[1]), (9...22).contains(value) else { throw Failure("Font size must be between 9 and 22 pt.") }; nextSize = value; found = true }
            }
            guard found else { throw Failure("No font-family or font-size found.") }
            families = Array(Set(families + [nextFamily])).sorted(); family = nextFamily; size = nextSize; importError = nil
        } catch { importError = "Could not import \(url.path): " + error.localizedDescription }
    }

}
private struct Updates: View {
    @State private var updater: SPUStandardUpdaterController?
    var body: some View {
        Form {
            Text("Homebrew").font(.headline)
            Text("Install and upgrade from your existing cleanwk tap.")
            Text("brew install --cask cleanwk/tap/herdrx\nbrew update && brew upgrade --cask herdrx").font(.system(.body, design: .monospaced)).textSelection(.enabled)
            Text("Homebrew manages Brew installations. Signed direct downloads can use Sparkle when a release signing key is configured.").font(.caption).foregroundStyle(.secondary)
            Button("Check Direct Download Updates") { updater?.checkForUpdates(nil) }.disabled(updater == nil)
        }.formStyle(.grouped).onAppear {
            let brewOwned = ["/opt/homebrew/Caskroom/herdrx", "/usr/local/Caskroom/herdrx"].contains { FileManager.default.fileExists(atPath: $0) }
            let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
            if !brewOwned, !key.isEmpty, !key.contains("$(") { updater = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil) }
        }
    }
}


private struct Appearance: View {
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("palette") private var palette = "default"
    @AppStorage("accent") private var accent = "theme"
    @AppStorage("language") private var language = "system"
    var body: some View {
        Form {
            Picker("Appearance", selection: $appearance) { Text("System").tag("system"); Text("Light").tag("light"); Text("Dark").tag("dark") }.pickerStyle(.segmented)
            Picker("Language", selection: $language) { Text("System").tag("system"); Text("简体中文").tag("zh-Hans"); Text("English").tag("en") }
            Picker("Palette", selection: $palette) { Text("Default").tag("default"); Text("Follow Herdr").tag("herdr"); Text("Catppuccin").tag("catppuccin"); Text("Dracula").tag("dracula"); Text("Nord").tag("nord") }
            Text("Dracula and Nord use the default palette in light mode. Follow Herdr reads its theme when the app becomes active; unsupported theme families fall back to Default.").font(.caption).foregroundStyle(.secondary)
            Picker("Accent", selection: $accent) { ForEach(["theme", "graphite", "green", "blue", "purple", "amber", "pink", "red", "orange"], id: \.self) { Text(LocalizedStringKey($0.capitalized)).tag($0) } }
            Text("Applies to navigation, pane focus and existing terminals. Terminal sessions and scrollback are preserved.").font(.caption).foregroundStyle(.secondary)
        }.formStyle(.grouped)
    }
}
private struct Notifications: View {
    @AppStorage("notifications") private var enabled = false
    @AppStorage("silentNotifications") private var silent = false
    @State private var status = "Checking permission…"
    var body: some View {
        Form {
            Toggle("Notify when agents need input or finish", isOn: $enabled)
            Toggle("Play a sound", isOn: Binding(get: { !silent }, set: { silent = !$0 })).disabled(!enabled)
            Text("Agents you are currently watching stay quiet. Click a notification to return to its terminal.").font(.caption).foregroundStyle(.secondary)
            Text(LocalizedStringKey(status)).foregroundStyle(.secondary)
            Button("Open Notification Settings") { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!) }
        }.formStyle(.grouped).task { await permission() }.onChange(of: enabled) { _, value in
            Task { if value { _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) }; await permission() }
        }
    }
    func permission() async {
        let value = await UNUserNotificationCenter.current().notificationSettings()
        status = value.authorizationStatus == .denied ? "Notifications are disabled in macOS Settings." : value.authorizationStatus == .notDetermined ? "Enable notifications to request macOS permission." : "macOS notifications are allowed."
    }
}

private struct About: View {
    var body: some View {
        Form {
            Text("HerdrX").font(.title)
            Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"))")
            Link("Project", destination: URL(string: "https://github.com/cleanwk/herdrX")!)
            ScrollView { Text((try? String(contentsOf: Bundle.main.url(forResource: "Notices", withExtension: "txt") ?? URL(fileURLWithPath: "/nonexistent"), encoding: .utf8)) ?? "See Resources/Notices.txt and Resources/Licenses in the source distribution.").font(.caption).textSelection(.enabled) }
        }.formStyle(.grouped)
    }
}
