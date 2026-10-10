import SwiftUI
import AppKit
import GhosttyTerminal
import HerdCore
import Sparkle
import UserNotifications

struct Preferences: View {
    @EnvironmentObject var desk: Desk
    var body: some View {
        TabView {
            Devices().tabItem { Label("Devices", systemImage: "server.rack") }
            TerminalSettings().tabItem { Label("Terminal", systemImage: "terminal") }
            ExtensionSettings().tabItem { Label("Plugins", systemImage: "puzzlepiece.extension") }
            Updates().tabItem { Label("Updates", systemImage: "arrow.down.circle") }
        }.padding(16).frame(width: 680, height: 560)
    }
}
private struct Devices: View {
    @EnvironmentObject var desk: Desk
    @State private var name = ""
    @State private var target = ""
    @State private var socket = ""
    @State private var port = "22"
    @State private var local = false
    var body: some View {
        Form {
            Section("Saved devices") { ForEach(desk.devices) { device in HStack { VStack(alignment: .leading) { Text(device.displayName); Text(device.endpoint.socketPath).font(.caption).foregroundStyle(.secondary) }; Spacer(); Text(device.endpoint.kind).foregroundStyle(.secondary); Button("Remove") { desk.remove(device.id) }.help("Forget this connection; server sessions continue") } } }
            Section("Add a connection") {
                TextField("Name", text: $name); Toggle("Local named session", isOn: $local)
                if !local { TextField("SSH host or config alias", text: $target); TextField("Port", text: $port) }
                TextField("Absolute Herdr socket path", text: $socket)
                Text("Use an absolute socket path for the intended named session. SSH uses your existing keys and SSH configuration.").font(.caption).foregroundStyle(.secondary)
                Button("Add Device") {
                    guard socket.hasPrefix("/"), !socket.contains("\n"), local || (!target.hasPrefix("-") && !target.contains(where: \.isWhitespace)), let port = Int(port), (1...65535).contains(port) else { desk.message = "Enter a valid host, port and absolute socket path."; return }
                    desk.add(Device(displayName: name, endpoint: .init(kind: local ? "local" : "ssh", target: local ? nil : target, port: port, socketPath: socket))); name = ""; target = ""; socket = ""
                }.disabled(name.isEmpty || socket.isEmpty || (!local && target.isEmpty))
            }
        }.formStyle(.grouped)
    }
}
private struct TerminalSettings: View {
    @AppStorage("fontSize") private var size = 13.0
    @AppStorage("fontFamily") private var family = "SF Mono"
    @AppStorage("lineSpacing") private var spacing = 1.0
    @AppStorage("notifications") private var notifications = false
    @State private var families: [String] = ["SF Mono"]
    var body: some View {
        Form {
            Picker("Font", selection: $family) { ForEach(families, id: \.self) { Text($0).tag($0) } }
            HStack { Text("Size"); Slider(value: $size, in: 9...22, step: 0.5); Text(size.formatted()).monospacedDigit() }
            HStack { Text("Line spacing"); Slider(value: $spacing, in: 1...1.4, step: 0.05); Text(spacing.formatted()).monospacedDigit() }
            Toggle("Notify when agents need attention or finish", isOn: $notifications).onChange(of: notifications) { _, enabled in if enabled { UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in } } }
            Text("The terminal follows macOS light and dark appearance. Hidden panes keep their terminal size and suspend drawing.").font(.caption).foregroundStyle(.secondary)
        }.formStyle(.grouped).onAppear {
            if families.count == 1 { families = Array(Set(NSFontManager.shared.availableFontFamilies.filter { NSFont(name: $0, size: 12)?.isFixedPitch == true } + ["SF Mono", family])).sorted() }
            apply()
        }.onChange(of: size) { apply() }.onChange(of: family) { apply() }.onChange(of: spacing) { apply() }
    }
    func apply() {
        Terminal.controller.setTerminalConfiguration(TerminalConfiguration { builder in
            builder.withFontFamily(family); builder.withFontSize(Float(size)); builder.withCustom("adjust-cell-height", "\(Int((spacing - 1) * 100))%"); builder.withCustom("macos-option-as-alt", "true")
        })
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
            let brewOwned = ["/opt/homebrew/Caskroom/herdrx", "/usr/local/Caskroom/herdrx", "/opt/homebrew/Caskroom/herd-x", "/usr/local/Caskroom/herd-x"].contains { FileManager.default.fileExists(atPath: $0) }
            let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
            if !brewOwned, !key.isEmpty, !key.contains("$(") { updater = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil) }
        }
    }
}
