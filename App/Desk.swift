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
    private var tunnels: [String: Process] = [:]
    private var paths: [String: String] = [:]
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
        polls[device.id] = Task { [weak self] in
            guard let self else { return }
            do {
                guard device.endpoint.socketPath.hasPrefix("/"), !device.endpoint.socketPath.contains(where: { $0 == "\n" || $0 == "\0" || $0 == ":" }) else { throw Failure("Use an absolute Herdr socket path without colons or control characters") }
                let path: String
                if device.endpoint.kind == "ssh" {
                    guard let target = device.endpoint.target, !target.hasPrefix("-"), !target.contains(where: \.isWhitespace) else { throw Failure("Invalid SSH host") }
                    self.tunnels[device.id]?.terminate()
                    path = "/tmp/hx-" + UUID().uuidString.prefix(12) + ".sock"
                    self.paths[device.id] = path
                    let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
                    process.arguments = ["-N", "-o", "BatchMode=yes", "-o", "ExitOnForwardFailure=yes", "-o", "StreamLocalBindUnlink=yes", "-p", String(device.endpoint.port ?? 22), "-L", path + ":" + device.endpoint.socketPath, target]
                    process.standardError = FileHandle.nullDevice; process.standardOutput = FileHandle.nullDevice
                    try process.run(); self.tunnels[device.id] = process
                    for _ in 0..<100 {
                        try Task.checkCancellation()
                        if FileManager.default.fileExists(atPath: path) { break }
                        guard process.isRunning else { throw Failure("SSH tunnel failed. Check SSH keys and host trust in Terminal.") }
                        try await Task.sleep(for: .milliseconds(100))
                    }
                } else if device.endpoint.kind == "local" { path = device.endpoint.socketPath }
                else { throw Failure("Unsupported connection type. Use local or SSH.") }
                self.paths[device.id] = path
                while !Task.isCancelled {
                    do {
                        try await self.refresh(device.id, client: RPC(path: path))
                        let paneIDs = Set(self.sessions[device.id]?.panes.map(\.id) ?? [])
                        let feed = EventFeed(path: path, panes: Array(paneIDs)); defer { feed.stop() }
                        for try await _ in feed.signals {
                            try Task.checkCancellation()
                            try await self.refresh(device.id, client: RPC(path: path))
                            if Set(self.sessions[device.id]?.panes.map(\.id) ?? []) != paneIDs { break }
                        }
                    } catch is CancellationError { return }
                    catch {
                        if Task.isCancelled { return }
                        // Older servers can keep working through bounded snapshot polling.
                        do { try await self.refresh(device.id, client: RPC(path: path)) }
                        catch { if !Task.isCancelled { self.connections[device.id] = error.localizedDescription } }
                    }
                    try await Task.sleep(for: .seconds(2))
                }
            } catch is CancellationError {} catch { self.connections[device.id] = error.localizedDescription }
        }
    }
    func rpc(_ id: String) throws -> RPC { guard let path = paths[id] else { throw Failure("Device is disconnected") }; return RPC(path: path) }
    private var refreshIDs: [String: UUID] = [:]
    func refresh(_ id: String, client: RPC) async throws {
        let token = UUID(); refreshIDs[id] = token
        let snapshot = try await Session.load(client)
        try Task.checkCancellation()
        guard refreshIDs[id] == token, devices.contains(where: { $0.id == id }) else { return }
        if sessions[id] != snapshot { notifyChanges(old: sessions[id], new: snapshot); sessions[id] = snapshot; reconcile(id); reindex() }
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
        let tab = ShellTab(id: UUID().uuidString, label: URL(fileURLWithPath: path).lastPathComponent, layout: .pane(key))
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
    func create(space: Bool = false, agent: String? = nil) {
        guard let id = selectedDevice else { newShell(); if let agent, let key = focused { terminals[key]?.process.write(Data((agent + "\n").utf8)) }; return }
        let key = focused, workspace = selectedSpace
        Task { do {
            let rpc = try rpc(id)
            var params: [String: JSON] = ["focus": .bool(false)]
            if let key {
                let pane = try await rpc.call("pane.get", ["pane_id": .string(key.pane)])["pane"]
                guard let cwd = pane["foreground_cwd"].string ?? pane["cwd"].string else { throw Failure("Cannot read current directory") }; params["cwd"] = .string(cwd)
            }
            if !space, let workspace { params["workspace_id"] = .string(workspace) }
            let result = try await rpc.call(space ? "workspace.create" : "tab.create", params)
            let paneID = result["root_pane"]["pane_id"].string
            if let agent, let paneID {
                _ = try await rpc.call("agent.start", ["kind": .string(agent), "name": .string(""), "pane_id": .string(paneID), "args": .array([])])
            }
            try await refresh(id, client: rpc); guard let snapshot = sessions[id] else { return }
            if let pane = snapshot.panes.first(where: { $0.id == paneID }) { select(device: id, space: pane.workspace, tab: pane.tab) }
        } catch { message = error.localizedDescription } }
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
    func reindex() {
        agents = sessions.flatMap { device, session in session.panes.filter { $0.agent != nil }.map { AgentRow(device: device, pane: $0) } }
        var rows = shellTabs.map { JumpRow(id: "shell|" + $0.id, device: nil, space: nil, tab: $0.id, pane: nil, label: $0.label, detail: "Local shell") }
        for device in devices {
            guard let session = sessions[device.id] else { continue }
            rows += session.spaces.map { JumpRow(id: "space|" + device.id + "|" + $0.id, device: device.id, space: $0.id, tab: nil, pane: nil, label: $0.label, detail: device.displayName + " · Space") }
            rows += session.panes.map { JumpRow(id: "pane|" + device.id + "|" + $0.id, device: device.id, space: $0.workspace, tab: $0.tab, pane: $0.id, label: $0.label, detail: device.displayName + " · " + ($0.cwd ?? $0.status)) }
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
    private func notifyChanges(old: Session?, new: Session) {
        guard UserDefaults.standard.bool(forKey: "notifications"), let old else { return }
        let previous = Dictionary(uniqueKeysWithValues: old.panes.map { ($0.id, $0.status) })
        for pane in new.panes where ["blocked", "done"].contains(pane.status) && previous[pane.id] != pane.status {
            let content = UNMutableNotificationContent(); content.title = pane.label; content.body = pane.status == "blocked" ? "Needs your input" : "Finished"; content.sound = .default
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }
    func shutdown() { layoutTask?.cancel(); Array(polls.keys).forEach { detach($0) }; terminals.values.forEach { $0.process.stop() } }
}
