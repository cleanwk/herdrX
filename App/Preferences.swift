import SwiftUI
import AppKit
import GhosttyTerminal
import HerdCore
import UserNotifications

struct Preferences: View {
    @EnvironmentObject var desk: Desk
    @AppStorage("settingsPage") private var selected = "Appearance"
    var body: some View {
        TabView(selection: $selected) {
            Appearance().tabItem { Label("Appearance", systemImage: "paintbrush.pointed") }.tag("Appearance")
            TerminalSettings().tabItem { Label("Terminal", systemImage: "terminal") }.tag("Terminal")
            ConnectionsSettings().id(desk.connectionFormRevision).tabItem { Label("Connections", systemImage: "server.rack") }.tag("Connections")
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
                ViewThatFits(in: .horizontal) {
                    HStack { discoveryActions }
                    VStack(alignment: .leading) { discoveryActions }
                }
                if let status = desk.discoveryStatus {
                    HStack(spacing: 6) {
                        HStack(spacing: 6) {
                            if desk.discoveringDevices { ProgressView().controlSize(.small) }
                            Text(status).font(.caption).foregroundStyle(.secondary)
                        }.accessibilityElement(children: .combine)
                        if desk.discoveringDevices {
                            Spacer()
                            Button("Cancel") { desk.cancelDeviceDiscovery() }.disabled(desk.cancellingDiscovery).fixedSize()
                        }
                    }
                }
                if let error = desk.discoveryError { Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled).fixedSize(horizontal: false, vertical: true) }
                ForEach(desk.devices) { device in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(device.displayName).fontWeight(.medium).lineLimit(1).truncationMode(.middle).help(device.displayName); Spacer()
                            Button("Edit") {
                                if device.endpoint.kind == "tailcat" {
                                    desk.tailcatEditRequest = device.id
                                    UserDefaults.standard.set("Tailcat", forKey: "settingsPage")
                                } else { draft = ConnectionDraft(device); error = nil }
                            }.fixedSize()
                            Button("Remove") {
                                let alert = NSAlert(); alert.messageText = LF("Forget %@?", device.displayName); alert.informativeText = L("Only this connection is removed. Server sessions and processes continue."); alert.addButton(withTitle: L("Forget Connection")); alert.addButton(withTitle: L("Cancel"))
                                if alert.runModal() == .alertFirstButtonReturn { desk.remove(device.id); if draft.id == device.id { reset() } }
                            }
                        }
                        Text(DisplayTitle.detail([device.endpoint.target, device.endpoint.socketPath])).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                        if desk.canWrite(device.id) { Text("Connected").font(.caption).foregroundStyle(.secondary) }
                        else { ConnectionRecovery(device: device, showsSettings: false).padding(.top, 4) }
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
    @ViewBuilder private var discoveryActions: some View {
        Button("Find Local Sessions") { desk.discoverSessions() }.disabled(desk.discoveringDevices).help("Discover Local Herdr Sessions")
        Button("Import Herdr Machines") { desk.importHerdrMachines() }.disabled(desk.discoveringDevices).help("Import Enabled Herdr Machines")
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
        ScrollView {
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
                    Picker("Weight", selection: $weight) {
                        Text("Light weight").tag("Light"); Text("Regular").tag("Regular"); Text("Medium").tag("Medium")
                        if ["Semibold", "Bold"].contains(weight) { Text(LocalizedStringKey(weight)).tag(weight) }
                    }.labelsHidden().pickerStyle(.segmented).frame(minWidth: 150, alignment: .leading).fixedSize().disabled(family != "SF Mono").help("Font weight is available for SF Mono.")
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
        }.padding(.horizontal, 17).padding(.top, 20).padding(.bottom, 17).font(.system(size: 13))
        }.onAppear {
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
                if parts[0] == "font-size" { guard let value = Double(parts[1]), (9...22).contains(value) else { throw Failure(L("Font size must be between 9 and 22 pt.")) }; nextSize = value; found = true }
            }
            guard found else { throw Failure(L("No font-family or font-size found.")) }
            families = Array(Set(families + [nextFamily])).sorted(); family = nextFamily; size = nextSize; importError = nil
        } catch { importError = LF("Could not import %@: %@", url.lastPathComponent, error.localizedDescription) }
    }

}
private struct Updates: View {
    @EnvironmentObject var updater: AppUpdater
    private static let notices = Bundle.main.url(forResource: "Notices", withExtension: "txt").flatMap { try? String(contentsOf: $0, encoding: .utf8) }
    var body: some View {
        Form {
            Section("HerdrX") {
                HStack {
                    Text(LF("Version %@ (%@)", Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? L("Development"), Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"))
                    Spacer()
                    Link("Project", destination: URL(string: "https://github.com/cleanwk/herdrX")!)
                }
            }
            Section("Updates") {
                VStack(alignment: .leading, spacing: 3) {
                    Toggle("Automatically check for updates", isOn: Binding(get: { updater.automaticChecks }, set: updater.setAutomaticChecks)).disabled(!updater.ready)
                    Text("Check once a day while HerdrX is running.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Toggle("Automatically download and install updates", isOn: Binding(get: { updater.automaticDownloads }, set: updater.setAutomaticDownloads)).disabled(!updater.ready || !updater.allowsAutomaticUpdates)
                    Text("Download in the background and install when you quit. Herdr sessions keep running.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        if updater.checking { ProgressView().controlSize(.small) }
                        Text(updater.status).font(.system(size: 12, weight: .medium)).fixedSize(horizontal: false, vertical: true)
                    }.accessibilityElement(children: .combine)
                    if let date = updater.lastCheck { Text(LF("Last checked: %@", date.formatted(date: .abbreviated, time: .shortened))).font(.caption).foregroundStyle(.secondary) }
                    if let failure = updater.failure { Text(failure).font(.caption).foregroundStyle(.secondary).textSelection(.enabled).fixedSize(horizontal: false, vertical: true) }
                    HStack {
                        Button(updater.availableVersion == nil ? "Check for Updates…" : "View and Install Update…") { updater.check() }.disabled(!updater.ready || !updater.canCheck)
                        Link("Release Notes", destination: URL(string: "https://github.com/cleanwk/herdrX/releases/latest")!)
                    }.padding(.top, 2)
                }
            }
            DisclosureGroup("Open Source Notices") {
                Text(Self.notices ?? L("See Resources/Notices.txt and Resources/Licenses in the source distribution.")).font(.caption).textSelection(.enabled)
            }
        }.formStyle(.grouped)
    }
}

private struct Appearance: View {
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("palette") private var palette = "default"
    @AppStorage("accent") private var accent = "theme"
    @AppStorage("language") private var language = "system"
    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 7) {
            row("Mode") {
                VStack(alignment: .leading, spacing: 4) {
                    Picker("Color mode", selection: $appearance) { Text("System mode").tag("system"); Text("Light").tag("light"); Text("Dark").tag("dark") }.labelsHidden().pickerStyle(.segmented).frame(minWidth: 150, alignment: .leading).fixedSize()
                    Text("Session appearance follows the app theme.").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            row("Palette") { PreferenceMenu(label: "Palette", items: Theme.palettes, selection: $palette).frame(width: 120, height: 24) }
            row("Accent") {
                VStack(alignment: .leading, spacing: 4) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 6) { accentSwatches; followThemeButton }.fixedSize()
                        VStack(alignment: .leading, spacing: 4) { accentSwatches; followThemeButton }
                    }
                    Text("Pane focus, active tabs and selection.").font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            row("Language") { PreferenceMenu(label: "Language", items: [("system", "System"), ("zh-Hans", "简体中文"), ("en", "English")], selection: $language).frame(width: 100, height: 24) }
        }.font(.system(size: 13)).padding(.horizontal, 25).padding(.top, 20).padding(.bottom, 16)
        }
    }
    private var accentSwatches: some View {
        HStack(spacing: 6) {
            ForEach(Theme.accents, id: \.self) { name in
                Button { accent = name } label: {
                    Circle().fill(Color(nsColor: Theme.accent(name))).frame(width: 16, height: 16).padding(3)
                        .overlay(Circle().stroke(accent == name ? Color(nsColor: Theme.accent(name)) : .clear, lineWidth: 1.5))
                }.buttonStyle(.plain).help(L(name.capitalized)).accessibilityLabel(L(name.capitalized)).accessibilityAddTraits(accent == name ? .isSelected : [])
            }
        }
    }
    private var followThemeButton: some View {
        Button { accent = "theme" } label: {
            HStack(spacing: 3) {
                Image(systemName: "checkmark").opacity(accent == "theme" ? 1 : 0).accessibilityHidden(true)
                Text("Follow theme")
            }
        }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize().accessibilityAddTraits(accent == "theme" ? .isSelected : [])
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
        }.toggleStyle(.checkbox).font(.system(size: 13)).frame(maxWidth: .infinity, alignment: .leading).padding(24).onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in Task { await permission() } }.task { await permission() }.onChange(of: enabled) { _, value in
            Task { if value { _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) }; await permission() }
        }
    }
    func permission() async {
        let value = await UNUserNotificationCenter.current().notificationSettings()
        status = value.authorizationStatus == .denied ? "Notifications are disabled in macOS Settings." : value.authorizationStatus == .notDetermined ? "Enable notifications to request macOS permission." : "macOS notifications are allowed."
    }
}
