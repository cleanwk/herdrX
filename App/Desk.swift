import AppKit
import SwiftUI
import HerdCore
import UserNotifications
import GhosttyTerminal

indirect enum Layout {
    case pane(PaneKey)
    case split(Bool, Double, Layout, Layout)
    init?(_ value: JSON, device: String) {
        if value["type"].string == "pane", let id = value["pane_id"].string { self = .pane(PaneKey(device: device, pane: id)) }
        else if value["type"].string == "split", let first = Layout(value["first"], device: device), let second = Layout(value["second"], device: device), case .number(let ratio) = value["ratio"] {
            self = .split(value["direction"].string == "right", ratio, first, second)
        } else { return nil }
    }
    struct Divider { let path: [Bool]; let horizontal: Bool; let ratio: Double; let box: CGRect; let panes: Set<PaneKey> }
    func dividers(in box: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1), path: [Bool] = []) -> [Divider] {
        guard case .split(let horizontal, let rawRatio, let a, let b) = self else { return [] }
        let ratio = min(0.9, max(0.1, rawRatio))
        let first = horizontal ? CGRect(x: box.minX, y: box.minY, width: box.width * ratio, height: box.height) : CGRect(x: box.minX, y: box.minY, width: box.width, height: box.height * ratio)
        let second = horizontal ? CGRect(x: first.maxX, y: box.minY, width: box.width - first.width, height: box.height) : CGRect(x: box.minX, y: first.maxY, width: box.width, height: box.height - first.height)
        return [Divider(path: path, horizontal: horizontal, ratio: ratio, box: box, panes: Set(rects().map(\.0)))] + a.dividers(in: first, path: path + [false]) + b.dividers(in: second, path: path + [true])
    }
    func setting(_ path: ArraySlice<Bool>, ratio: Double) -> Layout {
        guard case .split(let axis, let old, let a, let b) = self else { return self }
        guard let next = path.first else { return .split(axis, min(0.9, max(0.1, ratio)), a, b) }
        return .split(axis, old, next ? a : a.setting(path.dropFirst(), ratio: ratio), next ? b.setting(path.dropFirst(), ratio: ratio) : b)
    }
    func rects(in box: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)) -> [(PaneKey, CGRect)] {
        switch self {
        case .pane(let key): return [(key, box)]
        case .split(let horizontal, let ratio, let a, let b):
            let ratio = min(0.9, max(0.1, ratio))
            let first = horizontal ? CGRect(x: box.minX, y: box.minY, width: box.width * ratio, height: box.height) : CGRect(x: box.minX, y: box.minY, width: box.width, height: box.height * ratio)
            let second = horizontal ? CGRect(x: first.maxX, y: box.minY, width: box.width - first.width, height: box.height) : CGRect(x: box.minX, y: first.maxY, width: box.width, height: box.height - first.height)
            return a.rects(in: first) + b.rects(in: second)
        }
    }
    func splitting(_ key: PaneKey, with other: PaneKey, horizontal: Bool) -> Layout {
        switch self {
        case .pane(let leaf): return leaf == key ? .split(horizontal, 0.5, self, .pane(other)) : self
        case .split(let axis, let ratio, let a, let b): return .split(axis, ratio, a.splitting(key, with: other, horizontal: horizontal), b.splitting(key, with: other, horizontal: horizontal))
        }
    }
    func removing(_ key: PaneKey) -> Layout? {
        switch self {
        case .pane(let leaf): return leaf == key ? nil : self
        case .split(let axis, let ratio, let a, let b):
            let left = a.removing(key), right = b.removing(key)
            if let left, let right { return .split(axis, ratio, left, right) }; return left ?? right
        }
    }
}
struct AgentRow: Identifiable { let device: String; let pane: Item; var id: PaneKey { PaneKey(device: device, pane: pane.id) } }
struct ShellTab: Identifiable { let id: String; var label: String; var layout: Layout }
struct JumpRow: Identifiable { let id: String; let device: String?; let space: String?; let tab: String?; let pane: String?; let label: String; let detail: String }

@MainActor
final class Desk: ObservableObject {
    @Published var devices: [Device] = []
    @Published var sessions: [String: Session] = [:]
    @Published var connections: [String: String] = [:]
    @Published var shellTabs: [ShellTab] = []
    @Published var selectedDevice: String?
    @Published var selectedSpace: String?
    @Published var selectedTab: String = ""
    @Published var focused: PaneKey?
    @Published var ended: Set<PaneKey> = []
    @Published var message: String?
    @Published var showSearch = false
    @Published var zoomed = false
    @Published var search = Search([])
    @Published var agents: [AgentRow] = []
    @Published var jumpRows: [String: JumpRow] = [:]
    var terminals: [PaneKey: Terminal] = [:]
    private var notificationRouter: NotificationRouter?
    private var tunnels: [String: Process] = [:]
    private var paths: [String: String] = [:]
    private var connectionIDs: [String: UUID] = [:]
    private var shellNumber = 0
    private var polls: [String: Task<Void, Never>] = [:]
    private var remoteLayouts: [String: Layout] = [:]
    private var layoutTask: Task<Void, Never>?
    var dividers: [Layout.Divider] {
        guard !zoomed else { return [] }
        let layout = selectedDevice.flatMap { remoteLayouts[$0 + "|" + selectedTab] } ?? shellTabs.first { $0.id == selectedTab }?.layout
        return layout?.dividers() ?? []
    }
    func setRatio(_ divider: Layout.Divider, ratio: Double) {
        guard dividers.contains(where: { $0.path == divider.path && $0.panes == divider.panes }) else { return }
        if selectedDevice != nil {
            let tab = selectedTab
            perform { _ = try await $0.call("layout.set_split_ratio", ["tab_id": .string(tab), "path": .array(divider.path.map(JSON.bool)), "ratio": .number(min(0.9, max(0.1, ratio)))]) }
        } else if let index = shellTabs.firstIndex(where: { $0.id == selectedTab }) { shellTabs[index].layout = shellTabs[index].layout.setting(divider.path[...], ratio: ratio) }
    }
    func resize(_ direction: String) {
        guard let focused else { return }
        if selectedDevice != nil { perform { _ = try await $0.call("pane.resize", ["pane_id": .string(focused.pane), "direction": .string(direction), "amount": .number(0.05)]) } }
        else if let divider = dividers.last(where: { $0.panes.contains(focused) && $0.horizontal == ["left", "right"].contains(direction) }) { setRatio(divider, ratio: divider.ratio + (["right", "down"].contains(direction) ? 0.05 : -0.05)) }
    }
    private let saveURL = Desk.support.appendingPathComponent("devices.json")
    static var support: URL { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/HerdrX") }
    var currentDevice: Device? { devices.first { $0.id == selectedDevice } }
    var currentPane: Item? { guard let focused else { return nil }; return sessions[focused.device]?.panes.first { $0.id == focused.pane } }
    var activeRects: [(PaneKey, CGRect)] {
        if let device = selectedDevice, let snapshot = sessions[device] {
            let panes = snapshot.panes.filter { $0.tab == selectedTab }
            if zoomed, let focused { return [(focused, CGRect(x: 0, y: 0, width: 1, height: 1))] }
            if let layout = snapshot.layouts.array.first(where: { $0["tab_id"].string == selectedTab }),
               let width = layout["area"]["width"].int, let height = layout["area"]["height"].int, width > 0, height > 0 {
                return layout["panes"].array.compactMap { leaf in
                    guard let id = leaf["pane_id"].string else { return nil }; let r = leaf["rect"]
                    return (PaneKey(device: device, pane: id), CGRect(x: Double(r["x"].int ?? 0) / Double(width), y: Double(r["y"].int ?? 0) / Double(height), width: Double(r["width"].int ?? width) / Double(width), height: Double(r["height"].int ?? height) / Double(height)))
                }
            }
            return panes.enumerated().map { (PaneKey(device: device, pane: $0.element.id), CGRect(x: Double($0.offset) / Double(max(1, panes.count)), y: 0, width: 1 / Double(max(1, panes.count)), height: 1)) }
        }
        if zoomed, let focused { return [(focused, CGRect(x: 0, y: 0, width: 1, height: 1))] }
        return shellTabs.first { $0.id == selectedTab }?.layout.rects() ?? []
    }
    var canvas: [(PaneKey, Terminal, CGRect)] {
        let rects = Dictionary(uniqueKeysWithValues: activeRects)
        return terminals.map { ($0.key, $0.value, rects[$0.key] ?? .zero) }
    }
    init() {
        try? FileManager.default.createDirectory(at: Self.support, withIntermediateDirectories: true)
        devices = (try? JSONDecoder().decode([Device].self, from: Data(contentsOf: saveURL))) ?? [Device(id: "local", displayName: "This Mac", endpoint: .init(kind: "local", socketPath: NSHomeDirectory() + "/.config/herdr/herdr.sock"))]
        newShell(cwd: NSHomeDirectory())
        for device in devices { connect(device) }
        notificationRouter = NotificationRouter(desk: self)
        UNUserNotificationCenter.current().delegate = notificationRouter
        let defaults = UserDefaults.standard
        Terminal.controller.setTerminalConfiguration(TerminalConfiguration {
            $0.withFontSize(Float(defaults.double(forKey: "fontSize") > 0 ? defaults.double(forKey: "fontSize") : 13))
            $0.withFontFamily(defaults.string(forKey: "fontFamily") ?? "SF Mono")
            $0.withCustom("adjust-cell-height", "\(Int(max(0, defaults.double(forKey: "lineSpacing") - 1) * 100))%")
            $0.withCustom("macos-option-as-alt", "true")
        })
    }
    func save() { do { try JSONEncoder().encode(devices).write(to: saveURL, options: .atomic) } catch { message = error.localizedDescription } }
    func add(_ device: Device) { devices.append(device); save(); connect(device) }
    private func detach(_ id: String) {
        connectionIDs[id] = nil
        polls.removeValue(forKey: id)?.cancel()
        if let tunnel = tunnels.removeValue(forKey: id), tunnel.isRunning { tunnel.terminate() }
        if let path = paths.removeValue(forKey: id), path.hasPrefix("/tmp/hx-") { try? FileManager.default.removeItem(atPath: path) }
    }
    func remove(_ id: String) {
        detach(id); devices.removeAll { $0.id == id }; sessions[id] = nil; connections[id] = nil
        for key in Array(terminals.keys) where key.device == id { terminals.removeValue(forKey: key)?.process.stop(); ended.remove(key) }
        if selectedDevice == id { select(device: nil) }; save(); reindex()
    }
    func connect(_ device: Device) {
        detach(device.id); connections[device.id] = "Connecting…"
        guard device.endpoint.socketPath.hasPrefix("/"), !device.endpoint.socketPath.contains(where: { $0.isNewline || $0 == "\0" || $0 == ":" }),
              ["local", "ssh"].contains(device.endpoint.kind) else { connections[device.id] = "Enter an absolute Herdr socket path without colons or control characters."; return }
        if device.endpoint.kind == "ssh" {
            guard let target = device.endpoint.target, !target.isEmpty, !target.hasPrefix("-"), !target.contains(where: \.isWhitespace) else { connections[device.id] = "Enter a valid SSH host or config alias."; return }
        }
        let generation = UUID(); connectionIDs[device.id] = generation
        polls[device.id] = Task { [weak self] in
            guard let self else { return }
            var delay = 1
            while !Task.isCancelled {
                let remote = device.endpoint.kind == "ssh"
                let path = remote ? "/tmp/hx-" + UUID().uuidString.prefix(12) + ".sock" : device.endpoint.socketPath
                let diagnostic = URL(fileURLWithPath: path + ".log")
                var tunnel: Process?
                do {
                    defer {
                        if let tunnel, tunnel.isRunning { tunnel.terminate() }
                        if self.connectionIDs[device.id] == generation, self.paths[device.id] == path { self.paths[device.id] = nil; self.tunnels[device.id] = nil }
                        if remote { try? FileManager.default.removeItem(atPath: path); try? FileManager.default.removeItem(at: diagnostic) }
                    }
                    if remote {
                        FileManager.default.createFile(atPath: diagnostic.path, contents: nil, attributes: [.posixPermissions: 0o600])
                        let output = try FileHandle(forWritingTo: diagnostic); defer { try? output.close() }
                        let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
                        process.arguments = ["-N", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10", "-o", "ServerAliveInterval=10", "-o", "ServerAliveCountMax=2", "-o", "ExitOnForwardFailure=yes", "-o", "StreamLocalBindUnlink=yes", "-p", String(device.endpoint.port ?? 22), "-L", path + ":" + device.endpoint.socketPath, device.endpoint.target!]
                        process.standardError = output; process.standardOutput = FileHandle.nullDevice
                        try process.run(); tunnel = process; self.tunnels[device.id] = process
                        for _ in 0..<100 {
                            try Task.checkCancellation()
                            if FileManager.default.fileExists(atPath: path) { break }
                            guard process.isRunning else {
                                let reason = (try? String(contentsOf: diagnostic, encoding: .utf8)) ?? ""
                                throw Failure(reason.isEmpty ? "SSH failed. Check keys and host trust in Terminal." : String(reason.suffix(800)).trimmingCharacters(in: .whitespacesAndNewlines))
                            }
                            try await Task.sleep(for: .milliseconds(100))
                        }
                    }
                    try Task.checkCancellation(); self.paths[device.id] = path
                    while !Task.isCancelled {
                        if let tunnel, !tunnel.isRunning { throw Failure("SSH connection closed") }
                        try await self.refresh(device.id, client: RPC(path: path)); delay = 1
                        let paneIDs = Set(self.sessions[device.id]?.panes.map(\.id) ?? [])
                        let feed = EventFeed(path: path, panes: Array(paneIDs)); defer { feed.stop() }
                        for try await _ in feed.signals {
                            try Task.checkCancellation()
                            try await self.refresh(device.id, client: RPC(path: path))
                            if Set(self.sessions[device.id]?.panes.map(\.id) ?? []) != paneIDs { break }
                        }
                    }
                } catch is CancellationError { return }
                catch {
                    guard !Task.isCancelled else { return }
                    self.connections[device.id] = error.localizedDescription + " · Retrying in \(delay)s"
                }
                do { try await Task.sleep(for: .seconds(delay)) } catch { return }
                delay = min(30, delay * 2)
            }
        }
    }
    func rpc(_ id: String) throws -> RPC { guard let path = paths[id] else { throw Failure("Device is disconnected") }; return RPC(path: path) }
    private var refreshIDs: [String: UUID] = [:]
    func refresh(_ id: String, client: RPC) async throws {
        let token = UUID(); refreshIDs[id] = token
        let snapshot = try await Session.load(client)
        try Task.checkCancellation()
        guard refreshIDs[id] == token, devices.contains(where: { $0.id == id }) else { return }
        if sessions[id] != snapshot { notifyChanges(device: id, old: sessions[id], new: snapshot); sessions[id] = snapshot; reconcile(id); reindex() }
        connections[id] = "Connected"
    }
    func select(device: String?, space: String? = nil, tab: String? = nil) {
        selectedDevice = device; selectedSpace = space; zoomed = false
        if let device {
            selectedTab = tab ?? sessions[device]?.tabs.first { $0.workspace == space }?.id ?? ""
            focused = sessions[device]?.panes.first { $0.tab == selectedTab }.map { PaneKey(device: device, pane: $0.id) }
            ensureAttachments()
        } else {
            selectedTab = tab ?? shellTabs.first?.id ?? ""; focused = shellTabs.first { $0.id == selectedTab }?.layout.rects().first?.0
        }
    }
    func ensureAttachments() {
        guard let device = currentDevice, let session = sessions[device.id] else { return }
        layoutTask?.cancel(); let tab = selectedTab
        layoutTask = Task { [weak self] in
            guard let self else { return }
            if let value = try? await rpc(device.id).call("layout.export", ["tab_id": .string(tab)]), !Task.isCancelled,
               let layout = Layout(value["layout"]["root"] == .null ? value["root"] : value["layout"]["root"], device: device.id),
               Set(layout.rects().map { $0.0.pane }) == Set(session.panes.filter { $0.tab == tab }.map(\.id)) { remoteLayouts[device.id + "|" + tab] = layout; objectWillChange.send() }
        }
        for pane in session.panes where pane.tab == selectedTab {
            let key = PaneKey(device: device.id, pane: pane.id)
            guard terminals[key] == nil else { continue }
            let args: String
            if pane.agent != nil { args = "agent attach " + quote(pane.id) + " --takeover" }
            else if let terminal = pane.terminal { args = "terminal attach " + quote(terminal) + " --takeover" }
            else { continue }
            let script = "export HERDR_SOCKET_PATH=" + quote(device.endpoint.socketPath) + "; exec herdr " + args
            let command = device.endpoint.kind == "ssh" ? "exec /usr/bin/ssh -tt -p \(device.endpoint.port ?? 22) \(quote(device.endpoint.target ?? "")) \(quote("/bin/sh -lc " + quote("export PATH=\"$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH\"; " + script)))" : script
            makeTerminal(key, command: command)
        }
    }
    private func makeTerminal(_ key: PaneKey, command: String) {
        let terminal = Terminal(command: command)
        terminal.focused = { [weak self] in if self?.focused != key { self?.focused = key } }
        terminal.onExit = { [weak self] in self?.ended.insert(key) }
        terminal.process.inputRejected = { [weak self] in self?.message = "Terminal input is waiting for the process. Try a smaller paste when it responds." }
        terminals[key] = terminal
    }
    func newShell(cwd: String? = nil) {
        let path = cwd ?? (selectedDevice == nil ? focused.flatMap { terminals[$0]?.process.cwd() } : nil) ?? NSHomeDirectory()
        let key = PaneKey(device: "shell", pane: UUID().uuidString)
        makeTerminal(key, command: "cd \(quote(path)) && exec /bin/zsh -l")
        shellNumber += 1
        let directory = path == NSHomeDirectory() ? "~" : URL(fileURLWithPath: path).lastPathComponent
        let tab = ShellTab(id: UUID().uuidString, label: "Shell \(shellNumber) · " + directory, layout: .pane(key))
        shellTabs.append(tab); select(device: nil, tab: tab.id); reindex()
    }
    func split(horizontal: Bool) {
        guard let key = focused else { return }
        if selectedDevice != nil {
            let tab = selectedTab
            Task { do {
                let rpc = try rpc(key.device)
                let pane = try await rpc.call("pane.get", ["pane_id": .string(key.pane)])["pane"]
                guard let cwd = pane["foreground_cwd"].string ?? pane["cwd"].string else { throw Failure("Cannot read current directory; split cancelled") }
                let result = try await rpc.call("pane.split", ["target_pane_id": .string(key.pane), "direction": .string(horizontal ? "right" : "down"), "cwd": .string(cwd), "focus": .bool(false)])
                try await refresh(key.device, client: rpc)
                if selectedDevice == key.device, selectedTab == tab, let id = result["pane"]["pane_id"].string { focused = PaneKey(device: key.device, pane: id) }
            } catch { message = error.localizedDescription } }
        } else {
            guard let index = shellTabs.firstIndex(where: { $0.id == selectedTab }), let cwd = terminals[key]?.process.cwd() else { message = "Cannot read current directory"; return }
            let next = PaneKey(device: "shell", pane: UUID().uuidString)
            makeTerminal(next, command: "cd \(quote(cwd)) && exec /bin/zsh -l")
            shellTabs[index].layout = shellTabs[index].layout.splitting(key, with: next, horizontal: horizontal); focused = next
        }
    }
    func create() {
        guard let id = selectedDevice, let space = selectedSpace else { newShell(); return }
        Task { do { try await createTab(device: id, workspace: space, agent: nil, args: []) } catch { message = error.localizedDescription } }
    }
    func createTab(device: String, workspace: String, agent: String?, args: [String]) async throws {
        let client = try rpc(device)
        var params: [String: JSON] = ["focus": .bool(false), "workspace_id": .string(workspace)]
        if device == selectedDevice, workspace == selectedSpace, let cwd = currentPane?.cwd { params["cwd"] = .string(cwd) }
        let result = try await client.call("tab.create", params)
        guard let paneID = result["root_pane"]["pane_id"].string else { throw Failure("Herdr did not return the new pane") }
        // Publish and select the created terminal even if the agent fails to start.
        try await refresh(device, client: client)
        if let pane = sessions[device]?.panes.first(where: { $0.id == paneID }) { select(device: device, space: pane.workspace, tab: pane.tab) }
        if let agent {
            _ = try await client.call("agent.start", ["kind": .string(agent), "name": .string(agent + "-" + UUID().uuidString.prefix(6)), "pane_id": .string(paneID), "args": .array(args.map(JSON.string)), "timeout_ms": .number(30000)], timeout: 45)
            try await refresh(device, client: client)
        }
    }
    func createSpace(device: String, name: String, cwd: String) async throws {
        let client = try rpc(device)
        let result = try await client.call("workspace.create", ["focus": .bool(false), "label": .string(name), "cwd": .string(cwd)])
        try await refresh(device, client: client)
        if let id = result["workspace"]["workspace_id"].string { select(device: device, space: id) }
    }
    func renameSpace(device: String, space: Item) {
        let prompt = NSAlert(); prompt.messageText = "Rename Space"; prompt.addButton(withTitle: "Rename"); prompt.addButton(withTitle: "Cancel")
        let field = NSTextField(string: space.label); field.frame = NSRect(x: 0, y: 0, width: 300, height: 24); prompt.accessoryView = field
        guard prompt.runModal() == .alertFirstButtonReturn, !field.stringValue.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let name = field.stringValue
        Task { do { let client = try rpc(device); _ = try await client.call("workspace.rename", ["workspace_id": .string(space.id), "label": .string(name)]); try await refresh(device, client: client) } catch { message = error.localizedDescription } }
    }
    func perform(_ action: @escaping (RPC) async throws -> Void) {
        guard let id = selectedDevice else { return }
        Task { do { let client = try rpc(id); try await action(client); try await refresh(id, client: client) } catch { message = error.localizedDescription } }
    }
    func closePane() {
        guard let key = focused else { return }
        if selectedDevice != nil {
            let alert = NSAlert(); alert.messageText = "Close this server pane?"; alert.informativeText = "This ends its terminal and agent. Closing the window only detaches."; alert.addButton(withTitle: "Close Pane"); alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            perform { _ = try await $0.call("pane.close", ["pane_id": .string(key.pane)]) }
        } else if let index = shellTabs.firstIndex(where: { $0.id == selectedTab }) {
            terminals.removeValue(forKey: key)?.process.stop()
            if let layout = shellTabs[index].layout.removing(key) { shellTabs[index].layout = layout; focused = layout.rects().first?.0 }
            else { shellTabs.remove(at: index); if shellTabs.isEmpty { NSApp.keyWindow?.close() } else { select(device: nil) } }
            reindex()
        }
    }
    func reconcile(_ device: String) {
        if selectedDevice == device {
            if sessions[device]?.tabs.contains(where: { $0.id == selectedTab }) != true { selectedTab = sessions[device]?.tabs.first { $0.workspace == selectedSpace }?.id ?? "" }
            if sessions[device]?.panes.contains(where: { $0.id == focused?.pane && $0.tab == selectedTab }) != true { focused = sessions[device]?.panes.first { $0.tab == selectedTab }.map { PaneKey(device: device, pane: $0.id) } }
            ensureAttachments()
        }
        let valid = Set(sessions[device]?.panes.map(\.id) ?? [])
        for key in Array(terminals.keys) where key.device == device && !valid.contains(key.pane) { terminals.removeValue(forKey: key)?.process.stop(); ended.remove(key) }
    }
    private func rank(_ status: String) -> Int { status == "blocked" ? 0 : status == "done" ? 1 : status == "working" ? 2 : 3 }
    func reindex() {
        agents = sessions.flatMap { device, session in session.panes.filter { $0.agent != nil }.map { AgentRow(device: device, pane: $0) } }.sorted { (rank($0.pane.status), $0.device + $0.pane.id) < (rank($1.pane.status), $1.device + $1.pane.id) }
        var rows = shellTabs.map { JumpRow(id: "shell|" + $0.id, device: nil, space: nil, tab: $0.id, pane: nil, label: $0.label, detail: "Local shell") }
        for device in devices {
            guard let session = sessions[device.id] else { continue }
            rows += session.spaces.map { JumpRow(id: "space|" + device.id + "|" + $0.id, device: device.id, space: $0.id, tab: nil, pane: nil, label: $0.label, detail: device.displayName + " · Space") }
            rows += session.panes.map { JumpRow(id: "pane|" + device.id + "|" + $0.id, device: device.id, space: $0.workspace, tab: $0.tab, pane: $0.id, label: $0.label, detail: device.displayName + " · " + ($0.cwd ?? $0.status)) }
        }
        rows.sort { left, right in
            let a = left.device.flatMap { sessions[$0]?.panes.first { $0.id == left.pane } }.map { rank($0.status) } ?? 3
            let b = right.device.flatMap { sessions[$0]?.panes.first { $0.id == right.pane } }.map { rank($0.status) } ?? 3
            return (a, left.label, left.id) < (b, right.label, right.id)
        }
        jumpRows = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
        search = Search(rows.map { ($0.id, $0.label + " " + $0.detail) })
    }
    func jump(_ value: String) {
        if let row = jumpRows[value] {
            select(device: row.device, space: row.space, tab: row.tab)
            if let device = row.device, let pane = row.pane { focused = PaneKey(device: device, pane: pane) }
            showSearch = false; return
        }
        let parts = value.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2, let pane = sessions[parts[0]]?.panes.first(where: { $0.id == parts[1] }) else { return }
        select(device: parts[0], space: pane.workspace, tab: pane.tab); focused = PaneKey(device: parts[0], pane: pane.id); showSearch = false
    }
    func focusDirection(_ direction: String) {
        guard let key = focused, let origin = activeRects.first(where: { $0.0 == key })?.1 else { return }
        let candidates = activeRects.filter { other, rect in
            guard other != key else { return false }
            switch direction {
            case "left": return rect.midX < origin.midX
            case "right": return rect.midX > origin.midX
            case "up": return rect.midY < origin.midY
            default: return rect.midY > origin.midY
            }
        }.sorted { hypot($0.1.midX - origin.midX, $0.1.midY - origin.midY) < hypot($1.1.midX - origin.midX, $1.1.midY - origin.midY) }
        if let next = candidates.first { focused = next.0 }
    }
    func changeTab(_ offset: Int) {
        let ids = selectedDevice.flatMap { sessions[$0]?.tabs.filter { $0.workspace == selectedSpace }.map(\.id) } ?? shellTabs.map(\.id)
        guard !ids.isEmpty else { return }; let index = ids.firstIndex(of: selectedTab) ?? 0
        select(device: selectedDevice, space: selectedSpace, tab: ids[(index + offset + ids.count) % ids.count])
    }
    func attention() {
        let candidates = sessions.flatMap { device, session in session.panes.filter { ["blocked", "done"].contains($0.status) }.map { (device, $0) } }.sorted { $0.1.status == "blocked" && $1.1.status != "blocked" }
        if let next = candidates.first(where: { PaneKey(device: $0.0, pane: $0.1.id) != focused }) { jump(next.0 + "|" + next.1.id) }
    }
    private func notifyChanges(device: String, old: Session?, new: Session) {
        guard UserDefaults.standard.bool(forKey: "notifications"), let old else { return }
        let previous = Dictionary(uniqueKeysWithValues: old.panes.map { ($0.id, $0.status) })
        for pane in new.panes where pane.agent != nil && ["blocked", "done"].contains(pane.status) && previous[pane.id] != pane.status {
            if NSApp.isActive, focused == PaneKey(device: device, pane: pane.id) { continue }
            let content = UNMutableNotificationContent(); content.userInfo = ["device": device, "pane": pane.id]; content.title = pane.label; content.body = pane.status == "blocked" ? "Needs your input" : "Finished"; if !UserDefaults.standard.bool(forKey: "silentNotifications") { content.sound = .default }
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }
    func shutdown() { layoutTask?.cancel(); Array(polls.keys).forEach { detach($0) }; terminals.values.forEach { $0.process.stop() } }
}


@MainActor
private final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    weak var desk: Desk?
    init(desk: Desk) { self.desk = desk }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completion: @escaping () -> Void) {
        let route = response.notification.request.content.userInfo
        if let device = route["device"] as? String, let pane = route["pane"] as? String {
            Task { @MainActor [weak self] in NSApp.activate(ignoringOtherApps: true); NSApp.windows.first(where: { $0.title == "HerdrX" })?.makeKeyAndOrderFront(nil); self?.desk?.jump(device + "|" + pane) }
        }
        completion()
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completion: @escaping (UNNotificationPresentationOptions) -> Void) { completion([.banner, .sound]) }
}
