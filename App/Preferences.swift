import SwiftUI
import AppKit
import GhosttyTerminal
import HerdCore
import Sparkle
import UserNotifications

struct Preferences: View {
    @EnvironmentObject var desk: Desk
    @AppStorage("settingsPage") private var selected = "Appearance"
    var body: some View {
        TabView(selection: $selected) {
            Appearance().tabItem { Label("Appearance", systemImage: "paintbrush.pointed") }.tag("Appearance")
            TerminalSettings().tabItem { Label("Terminal", systemImage: "terminal") }.tag("Terminal")
            ConnectionsSettings().tabItem { Label("Connections", systemImage: "server.rack") }.tag("Connections")
            Notifications().tabItem { Label("Notifications", systemImage: "bell") }.tag("Notifications")
            TailcatSettings().tabItem { Label("Tailcat", systemImage: "key") }.tag("Tailcat")
            Updates().tabItem { Label("About", systemImage: "info.circle") }.tag("About")
        }.frame(width: selected == "Connections" || selected == "Tailcat" ? 600 : 420, height: height)
    }
    var height: CGFloat {
        switch selected {
        case "Terminal": 410
        case "Connections", "Tailcat": 480
        case "Notifications": 220
        case "About": 410
        default: 190
        }
    }
}

private struct ConnectionsSettings: View {
    @State private var page = "Devices"
    var body: some View {
        VStack(spacing: 0) {
            Picker("Connections", selection: $page) { Text("Devices").tag("Devices"); Text("Advanced: Plugins").tag("Plugins") }.labelsHidden().pickerStyle(.segmented).padding(16)
            switch page { case "Plugins": ExtensionSettings(); default: Devices() }
        }
    }
}
private struct Devices: View {
    @EnvironmentObject var desk: Desk
    @State private var draft = ConnectionDraft()
    @State private var error: String?
    var body: some View {
        Form {
            Section("Saved devices") {
                HStack { Button("Discover Local Herdr Sessions") { desk.discoverSessions() }; Button("Import Enabled Herdr Machines") { desk.importHerdrMachines() } }
                ForEach(desk.devices) { device in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(device.displayName).fontWeight(.medium); Spacer()
                            Button("Edit") { draft = ConnectionDraft(device); error = nil }.disabled(device.endpoint.kind == "tailcat")
                            Button("Retry") { desk.connect(device) }
                            Button("Remove") {
                                let alert = NSAlert(); alert.messageText = LF("Forget %@?", device.displayName); alert.informativeText = L("Only this connection is removed. Server sessions and processes continue."); alert.addButton(withTitle: L("Forget Connection")); alert.addButton(withTitle: L("Cancel"))
                                if alert.runModal() == .alertFirstButtonReturn { desk.remove(device.id); if draft.id == device.id { reset() } }
                            }
                        }
                        Text(DisplayTitle.detail([device.endpoint.target, device.endpoint.socketPath])).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                        Text(L(desk.connections[device.id] ?? "Disconnected")).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Section(LocalizedStringKey(draft.id == nil ? "Add a connection" : "Edit connection")) {
                TextField("Name", text: $draft.name)
                Picker("Connection", selection: $draft.local) { Text("SSH").tag(false); Text("Local Herdr session").tag(true) }.pickerStyle(.segmented)
                if !draft.local { TextField("SSH host or config alias", text: $draft.target); TextField("Port", text: $draft.port, prompt: Text("Automatic")); TextField("SSH config file (optional)", text: $draft.sshConfig) }
                TextField("Herdr socket", text: $draft.socket, prompt: Text("/home/user/.config/herdr/herdr.sock"))
                Text("Use an absolute socket path for the intended named session. SSH uses your existing keys and SSH configuration.").font(.caption).foregroundStyle(.secondary)
                if let error { Text(error).font(.caption).foregroundStyle(.secondary) }
                HStack {
                    Button(LocalizedStringKey(draft.id == nil ? "Add Device" : "Save Changes")) {
                        do { let device = try draft.device(); if draft.id != nil { desk.update(device) } else { desk.add(device) }; reset() }
                        catch { self.error = L("Enter a valid name, host, port and absolute socket path.") }
                    }
                    Button(LocalizedStringKey(draft.id == nil ? "Clear Form" : "Cancel Editing")) { reset() }
                }
            }
        }.formStyle(.grouped)
    }
    func reset() { draft = ConnectionDraft(); error = nil }
}
private struct TerminalSettings: View {
    @AppStorage("fontSize") private var size = 13.5
    @AppStorage("fontFamily") private var family = Theme.defaultFont
    @AppStorage("lineSpacing") private var spacing = 1.0
    @AppStorage("fontWeight") private var weight = "Regular"
    @AppStorage("disableMouseReporting") private var noMouse = true
    @AppStorage("thinStrokes") private var thin = true
    @AppStorage("copyOnSelect") private var copy = true
    @State private var importError: String?
    @State private var families: [String] = ["SF Mono"]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 7) {
                GridRow {
                    Text("Font").gridColumnAlignment(.trailing)
                    PreferenceMenu(label: "Font", items: families.map { ($0, $0) }, selection: $family).frame(width: 256, height: 24).frame(maxWidth: .infinity, alignment: .leading)
                }
                GridRow {
                    Text("Size")
                    HStack(spacing: 10) {
                        Slider(value: $size, in: 9...22, step: 0.5).accessibilityLabel("Font size")
                        Text(size.formatted(.number.precision(.fractionLength(1))) + " pt").foregroundStyle(.secondary).monospacedDigit().frame(width: 47, alignment: .trailing)
                        Stepper("Font size", value: $size, in: 9...22, step: 0.5).labelsHidden().fixedSize()
                    }
                }
                GridRow {
                    Text("Weight")
                    Picker("Weight", selection: $weight) { Text("Light weight").tag("Light"); Text("Regular").tag("Regular"); Text("Medium").tag("Medium") }.labelsHidden().pickerStyle(.segmented).frame(width: 150).disabled(family != "SF Mono").help("Font weight is available for SF Mono.")
                }
                GridRow {
                    Text("Line spacing")
                    HStack(spacing: 12) { Slider(value: $spacing, in: 1...1.4, step: 0.05).accessibilityLabel("Line spacing"); Text("\(Int((spacing * 100).rounded()))%").monospacedDigit().foregroundStyle(.secondary).frame(width: 45, alignment: .trailing) }
                }
                GridRow {
                    Color.clear.frame(width: 0, height: 0)
                    VStack(alignment: .leading, spacing: 9) {
                        preferenceToggle("Thin strokes", description: "Use finer font strokes for clear, balanced Agent output.", value: $thin)
                        preferenceToggle("Mouse reporting", description: "Forward clicks to terminal apps. Hold Shift to select text locally.", value: Binding(get: { !noMouse }, set: { noMouse = !$0 }))
                        preferenceToggle("Copy on select", description: "Copy text to the clipboard when you finish selecting it.", value: $copy)
                        HStack(spacing: 10) {
                            Button("Restore Defaults") { size = 13.5; family = Theme.defaultFont; spacing = 1; thin = true; copy = true; noMouse = true; weight = "Regular" }
                            Button("Import from Ghostty…") { importGhostty() }
                        }.tint(.primary).padding(.top, 1)
                    }
                }
            }.fixedSize(horizontal: false, vertical: true)
            if let importError { Text(importError).font(.system(size: 11)).foregroundStyle(.secondary) }
            VStack(alignment: .leading, spacing: 6) {
                Text("Preview").font(.system(size: 11)).foregroundStyle(.secondary)
                Text("❯ herdr agent attach w1:p1 — 中文 ABC 0123").font(previewFont).lineLimit(2).lineSpacing(CGFloat((spacing - 1) * size)).padding(10).frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(Color(nsColor: Theme.foreground)).background(Color(nsColor: Theme.content), in: RoundedRectangle(cornerRadius: 7))
            }.padding(.top, 3)
            Spacer(minLength: 0)
        }.padding(.horizontal, 17).padding(.top, 20).padding(.bottom, 17).font(.system(size: 13)).onAppear {
            if families.count == 1 { families = Array(Set(NSFontManager.shared.availableFontFamilies.filter { NSFont(name: $0, size: 12)?.isFixedPitch == true } + ["SF Mono", family])).sorted() }
            apply()
        }.onChange(of: size) { apply() }.onChange(of: family) { apply() }.onChange(of: spacing) { apply() }.onChange(of: thin) { apply() }.onChange(of: copy) { apply() }.onChange(of: weight) { apply() }
    }
    func preferenceToggle(_ title: String, description: String, value: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle(LocalizedStringKey(title), isOn: value).toggleStyle(.checkbox)
            Text(LocalizedStringKey(description)).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).padding(.leading, 21)
        }
    }
    func apply() { Theme.apply() }
    var previewFont: Font {
        guard family == "SF Mono" else { return .custom(family, size: size) }
        let selected: Font.Weight = switch weight { case "Light": .light; case "Medium": .medium; case "Semibold": .semibold; case "Bold": .bold; default: .regular }
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
    @State private var channel = "Checking installation…"
    @State private var reason = ""
    @State private var copied = false
    private let brewCommand = "brew update && brew upgrade --cask herdrx"
    var body: some View {
        Form {
            Section("HerdrX") {
                Text(LF("Version %@ (%@)", Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? L("Development"), Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"))
                Text(channel).font(.caption).foregroundStyle(.secondary)
                Link("Project", destination: URL(string: "https://github.com/cleanwk/herdrX")!)
            }
            Section("Updates") {
                Text("Install and upgrade from your existing cleanwk tap.")
                Text(brewCommand).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                Button(LocalizedStringKey(copied ? "Copied" : "Copy Homebrew Update Command")) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(brewCommand, forType: .string); copied = true }
                Button("Check Direct Download Updates") { updater?.checkForUpdates(nil) }.disabled(updater == nil)
                Text(reason).font(.caption).foregroundStyle(.secondary)
            }
            DisclosureGroup("Open Source Notices") {
                Text((try? String(contentsOf: Bundle.main.url(forResource: "Notices", withExtension: "txt") ?? URL(fileURLWithPath: "/nonexistent"), encoding: .utf8)) ?? L("See Resources/Notices.txt and Resources/Licenses in the source distribution.")).font(.caption).textSelection(.enabled)
            }
        }.formStyle(.grouped).onAppear { identify() }
    }
    func identify() {
        let url = Bundle.main.bundleURL.resolvingSymlinksInPath()
        let verifiedBrew = ["/opt/homebrew/Caskroom/herdrx/", "/usr/local/Caskroom/herdrx/"].contains { url.path.hasPrefix($0) }
        let possibleBrew = ["/opt/homebrew/Caskroom/herdrx", "/usr/local/Caskroom/herdrx"].contains { FileManager.default.fileExists(atPath: $0) }
        channel = L(verifiedBrew ? "Homebrew installation" : possibleBrew ? "Homebrew is installed; ownership of this app is unverified." : "Direct download or development build")
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
        if verifiedBrew { reason = L("Use Homebrew to update this installation.") }
        else if key.isEmpty || key.contains("$(") { reason = L("Direct updates are unavailable because this build has no release signing key. Use Homebrew or download a release from the project.") }
        else { reason = L("Signed direct downloads can check for updates here."); if updater == nil { updater = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil) } }
    }
}

private struct Appearance: View {
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("palette") private var palette = "default"
    @AppStorage("accent") private var accent = "theme"
    @AppStorage("language") private var language = "system"
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            row("Color mode") {
                VStack(alignment: .leading, spacing: 4) {
                    Picker("Color mode", selection: $appearance) { Text("System mode").tag("system"); Text("Light").tag("light"); Text("Dark").tag("dark") }.labelsHidden().pickerStyle(.segmented).frame(width: 150)
                    Text("Session appearance follows the app theme.").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            row("Palette") { PreferenceMenu(label: "Palette", items: Theme.palettes, selection: $palette).frame(width: 120, height: 24) }
            row("Accent") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        ForEach(Theme.accents, id: \.self) { name in
                            Button { accent = name } label: {
                                Circle().fill(Color(nsColor: Theme.accent(name))).frame(width: 16, height: 16).padding(3)
                                    .overlay(Circle().stroke(accent == name ? Color(nsColor: Theme.accent(name)) : .clear, lineWidth: 1.5))
                            }.buttonStyle(.plain).help(L(name.capitalized)).accessibilityLabel(L(name.capitalized)).accessibilityAddTraits(accent == name ? .isSelected : [])
                        }
                        Button("Follow theme") { accent = "theme" }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize().accessibilityAddTraits(accent == "theme" ? .isSelected : [])
                    }
                    Text("Pane focus, active tabs and selection.").font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            row("Language") { PreferenceMenu(label: "Language", items: [("system", "System"), ("zh-Hans", "简体中文"), ("en", "English")], selection: $language).frame(width: 100, height: 24) }
            Spacer(minLength: 0)
        }.font(.system(size: 13)).padding(.horizontal, 25).padding(.top, 20)
    }
    func row<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(LocalizedStringKey(label)).frame(width: 48, alignment: .trailing).padding(.top, 3)
            content().frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct Notifications: View {
    @AppStorage("notifications") private var enabled = false
    @AppStorage("silentNotifications") private var silent = false
    @State private var status = "Checking permission…"
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Notify when agents need input or finish", isOn: $enabled)
            Toggle("Play a sound", isOn: Binding(get: { !silent }, set: { silent = !$0 })).disabled(!enabled)
            Text("Agents you are currently watching stay quiet. Click a notification to return to its terminal.").font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text(LocalizedStringKey(status)).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button("Open Notification Settings") { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!) }.tint(.primary)
            Spacer(minLength: 0)
        }.toggleStyle(.checkbox).font(.system(size: 13)).padding(24).onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in Task { await permission() } }.task { await permission() }.onChange(of: enabled) { _, value in
            Task { if value { _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) }; await permission() }
        }
    }
    func permission() async {
        let value = await UNUserNotificationCenter.current().notificationSettings()
        status = value.authorizationStatus == .denied ? "Notifications are disabled in macOS Settings." : value.authorizationStatus == .notDetermined ? "Enable notifications to request macOS permission." : "macOS notifications are allowed."
    }
}
