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
struct AgentRow: Identifiable, Equatable { let device: String; let pane: Item; var id: PaneKey { PaneKey(device: device, pane: pane.id) } }
struct SpaceRequest: Identifiable { let id = UUID(); let device: String? }
struct JumpRow: Identifiable, Equatable { let id: String; let device: String?; let space: String?; let tab: String?; let pane: String?; let label: String; let detail: String }

@MainActor
final class Desk: ObservableObject {
    @Published var devices: [Device] = []
    @Published var sessions: [String: Session] = [:]
    @Published var connections: [String: ConnectionState] = [:]
    private var localStarts: [String: Task<Void, Never>] = [:]
    @Published var selectedDevice: String?
    @Published var selectedSpace: String?
    @Published var selectedTab: String = ""
    @Published var focused: PaneKey? {
        didSet {
            if oldValue != focused {
                attentionState.leave(oldValue)
                if let focused { searchActivity["pane|" + focused.device + "|" + focused.pane] = Date.timeIntervalSinceReferenceDate }
            }
            if let focused { paneMemory[(selectedDevice ?? "") + "|" + selectedTab] = focused }
        }
    }
    @Published var attentionState = Attention()
    @Published var deviceFilter = ""
    @Published var creatingSpace = false
    @Published var spaceRequest: SpaceRequest?
    @Published var renameRequest: RenameRequest?
    let renameQueue = SerialOperationQueue()
    @Published var tailcatEditRequest: String?
    @Published var connectionFormRevision = 0
    @Published var discoveringDevices = false
    @Published var cancellingDiscovery = false
    @Published var discoveryStatus: String?
    @Published var discoveryError: String?
    var discoveryTask: Task<Void, Never>?
    @Published var busy: Set<String> = []
    @Published var focusRevision = 0
    @Published var sidebarReveal: String?
    @Published var exitStatus: [PaneKey: Int32] = [:]
    weak var focusReturn: NSResponder?
    private var focusReturnRevision = 0
    private var focusReturnWasTerminal = false
    @Published var canvasSize: CGSize = .zero
    func requestFocus() { focusRevision += 1 }
    func captureFocus() {
        focusReturn = NSApp.keyWindow?.firstResponder; focusReturnRevision = focusRevision
        focusReturnWasTerminal = terminals.values.contains { $0.view === focusReturn }
    }
    func restoreFocus() {
        if focusRevision != focusReturnRevision { requestFocus() }
        else if let view = focusReturn as? NSView, let window = view.window, !view.isHiddenOrHasHiddenAncestor { window.makeFirstResponder(view) }
        else if focusReturnWasTerminal { requestFocus() }
        focusReturn = nil
    }
    func openSearch() { captureFocus(); reindex(); showSearch = true }
    func canWrite(_ device: String) -> Bool { connections[device] == .connected }
    func begin(_ key: String, device: String) -> Bool { guard canWrite(device), !busy.contains(key) else { return false }; busy.insert(key); return true }
    func creationID(_ device: String, _ space: String) -> String { device + "|createTab|" + space }
    var canCreate: Bool { guard let id = selectedDevice, let space = selectedSpace else { return false }; return canWrite(id) && !busy.contains(creationID(id, space)) }
    var creationDevice: String? {
        if !deviceFilter.isEmpty { return selectedDevice == nil || selectedDevice == deviceFilter ? deviceFilter : nil }
        return selectedDevice
    }
    var creationHelp: String { creationDevice.flatMap { id in devices.first { $0.id == id }?.displayName }.map { LF("New Space on %@ · ⌘⇧N", $0) } ?? L("Choose a device for New Space · ⌘⇧N") }
    func showSpaceForm(device: String? = nil) { captureFocus(); spaceRequest = SpaceRequest(device: device ?? creationDevice) }
    @Published var branches: [String: String] = [:]
    var branchRequests: [String: UUID] = [:]
    var branchUpdated: [String: Date] = [:]
    var branchContexts: [String: String] = [:]
    @Published var branchStates: [String: BranchState] = [:]
    @Published var tabOrders: [String: TabOrder] = [:]
    private var reorderTasks: [String: Task<Void, Never>] = [:]
    private var paneMemory: [String: PaneKey] = [:]
    private var searchActivity: [String: TimeInterval] = [:]
    @Published var ended: Set<PaneKey> = []
    @Published var message: String?
    @Published var showSearch = false
    @Published var zoomed = false
    @Published var draggingLayout: Layout?
    @Published var search = Search([])
    @Published var agents: [AgentRow] = []
    @Published var jumpRows: [String: JumpRow] = [:]
    private var indexedRows: [JumpRow] = []
    var terminals: [PaneKey: Terminal] = [:]
    private var notificationRouter: NotificationRouter?
    private var tailcats: [String: TailcatConnection] = [:]
    private var tunnels: [String: Process] = [:]
    private var paths: [String: String] = [:]
    private var connectionIDs: [String: UUID] = [:]
    private var polls: [String: Task<Void, Never>] = [:]
    private var remoteLayouts: [String: Layout] = [:]
    private var hiddenTask: Task<Void, Never>?
    private var layoutTask: Task<Void, Never>?
    var dividers: [Layout.Divider] {
        guard !zoomed else { return [] }
        let layout = draggingLayout ?? selectedDevice.flatMap { remoteLayouts[$0 + "|" + selectedTab] }
        return layout?.dividers() ?? []
    }
    func previewRatio(_ divider: Layout.Divider, ratio: Double) {
        guard dividers.contains(where: { $0.path == divider.path && $0.panes == divider.panes }) else { return }
        if let device = selectedDevice, let layout = draggingLayout ?? remoteLayouts[device + "|" + selectedTab] { draggingLayout = layout.setting(divider.path[...], ratio: ratio) }
        else { setRatio(divider, ratio: ratio) }
    }
    func setRatio(_ divider: Layout.Divider, ratio proposed: Double) {
        let dimension = divider.horizontal ? canvasSize.width * divider.box.width : canvasSize.height * divider.box.height
        let minimum = divider.horizontal ? minimumPaneSize.width : minimumPaneSize.height
        let edge = min(0.5, max(0.1, minimum / max(1, dimension)))
        let ratio = min(1 - edge, max(edge, proposed))
        guard dividers.contains(where: { $0.path == divider.path && $0.panes == divider.panes }) else { return }
        if selectedDevice != nil {
            let tab = selectedTab
            let device = selectedDevice!, key = selectedDevice! + "|layout|" + selectedTab
            guard begin(key, device: device) else { return }
            Task {
                defer { busy.remove(key) }
                defer { if selectedDevice == device && selectedTab == tab { draggingLayout = nil } }
                do { let client = try rpc(device); _ = try await client.call("layout.set_split_ratio", ["tab_id": .string(tab), "path": .array(divider.path.map(JSON.bool)), "ratio": .number(min(0.9, max(0.1, ratio)))]); try await refresh(device, client: client) } catch { message = error.localizedDescription }
            }
        }
    }
    func resize(_ direction: String) {
        guard let focused else { return }
        guard canAct(on: focused), let divider = dividers.last(where: { $0.panes.contains(focused) && $0.horizontal == ["left", "right"].contains(direction) }) else { return }
        setRatio(divider, ratio: divider.ratio + (["right", "down"].contains(direction) ? 0.05 : -0.05))
    }
    private let saveURL = Desk.support.appendingPathComponent("devices.json")
    static var support: URL {
        if let path = ProcessInfo.processInfo.environment["HERDRX_STATE_DIR"] { return URL(fileURLWithPath: path) }
        #if DEBUG
        // Sparkle relaunch does not preserve test environment variables.
        let directory = "Library/Application Support/HerdrX Development"
        #else
        let directory = "Library/Application Support/HerdrX"
        #endif
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(directory)
    }
    var currentDevice: Device? { devices.first { $0.id == selectedDevice } }
    var currentPane: Item? { guard let focused else { return nil }; return sessions[focused.device]?.panes.first { $0.id == focused.pane } }
    var activeRects: [(PaneKey, CGRect)] {
        if zoomed, let focused, layoutRects.contains(where: { $0.0 == focused }) {
            return [(focused, CGRect(x: 0, y: 0, width: 1, height: 1))]
        }
        return layoutRects
    }
    var layoutRects: [(PaneKey, CGRect)] {
        if let draggingLayout { return draggingLayout.rects() }
        if let device = selectedDevice, let snapshot = sessions[device] {
            let panes = snapshot.panes.filter { $0.tab == selectedTab }
            if let layout = snapshot.layouts.array.first(where: { $0["tab_id"].string == selectedTab }),
               let width = layout["area"]["width"].int, let height = layout["area"]["height"].int, width > 0, height > 0 {
                return layout["panes"].array.compactMap { leaf in
                    guard let id = leaf["pane_id"].string else { return nil }; let r = leaf["rect"]
                    return (PaneKey(device: device, pane: id), CGRect(x: Double(r["x"].int ?? 0) / Double(width), y: Double(r["y"].int ?? 0) / Double(height), width: Double(r["width"].int ?? width) / Double(width), height: Double(r["height"].int ?? height) / Double(height)))
                }
            }
            return panes.enumerated().map { (PaneKey(device: device, pane: $0.element.id), CGRect(x: Double($0.offset) / Double(max(1, panes.count)), y: 0, width: 1 / Double(max(1, panes.count)), height: 1)) }
        }
        return []
    }
    var canvas: [(PaneKey, Terminal, CGRect)] {
        let rects = Dictionary(uniqueKeysWithValues: activeRects)
        return terminals.map { ($0.key, $0.value, rects[$0.key] ?? .zero) }
    }
    init() {
        try? FileManager.default.createDirectory(at: Self.support, withIntermediateDirectories: true)
        devices = (try? JSONDecoder().decode([Device].self, from: Data(contentsOf: saveURL))) ?? (ProcessInfo.processInfo.environment["HERDRX_STATE_DIR"] != nil ? [] : [Device(id: "local", displayName: "Local", endpoint: .init(kind: "local", socketPath: NSHomeDirectory() + "/.config/herdr/herdr.sock"))])
        for device in devices { connect(device) }
        notificationRouter = NotificationRouter(desk: self)
        UNUserNotificationCenter.current().delegate = notificationRouter
        Theme.apply()
    }
    func save() { do { try JSONEncoder().encode(devices).write(to: saveURL, options: .atomic) } catch { message = error.localizedDescription } }
    func update(_ device: Device) {
        guard let index = devices.firstIndex(where: { $0.id == device.id }) else { return }
        if devices[index].endpoint != device.endpoint {
            detach(device.id); sessions[device.id] = nil; attentionState.remove(device: device.id)
            for key in Array(terminals.keys) where key.device == device.id { terminals.removeValue(forKey: key)?.process.stop(); ended.remove(key) }
        }
        devices[index] = device; save(); connect(device); reindex()
    }
    func add(_ device: Device) { devices.append(device); save(); connect(device) }
    private func detach(_ id: String) {
        localStarts.removeValue(forKey: id)?.cancel()
        connectionIDs[id] = nil; refreshIDs[id] = nil
        polls.removeValue(forKey: id)?.cancel(); tailcats.removeValue(forKey: id)?.stop()
        if let tunnel = tunnels.removeValue(forKey: id), tunnel.isRunning { tunnel.terminate() }
        if let path = paths.removeValue(forKey: id), path.hasPrefix("/tmp/hx-") { try? FileManager.default.removeItem(atPath: path) }
    }
    func remove(_ id: String) {
        detach(id); TailcatSecrets.remove("token." + id); attentionState.remove(device: id); devices.removeAll { $0.id == id }; sessions[id] = nil; connections[id] = nil
        for key in Array(terminals.keys) where key.device == id { terminals.removeValue(forKey: key)?.process.stop(); ended.remove(key) }
        if deviceFilter == id { deviceFilter = "" }
        if selectedDevice == id { select(device: nil) }; save(); reindex()
    }
    func connect(_ device: Device, preserving issue: ConnectionIssue? = nil) {
        detach(device.id); connections[device.id] = issue.map(ConnectionState.failed) ?? .connecting
        guard device.endpoint.socketPath.hasPrefix("/"), !device.endpoint.socketPath.contains(where: { $0.isNewline || $0 == "\0" || $0 == ":" }),
              ["local", "ssh", "tailcat"].contains(device.endpoint.kind) else { connections[device.id] = .failed(.init(.configuration, detail: "Enter an absolute Herdr socket path without colons or control characters.")); return }
        if device.endpoint.kind == "ssh" {
            guard let target = device.endpoint.target, !target.isEmpty, !target.hasPrefix("-"), !target.contains(where: \.isWhitespace) else { connections[device.id] = .failed(.init(.configuration, detail: "Enter a valid SSH host or config alias.")); return }
        }
        let generation = UUID(); connectionIDs[device.id] = generation
        polls[device.id] = Task { [weak self] in
            guard let self else { return }
            var delay = 1
            while !Task.isCancelled {
                let remote = device.endpoint.kind == "ssh"
                var path = remote ? "/tmp/hx-" + UUID().uuidString.prefix(12) + ".sock" : device.endpoint.socketPath
                let diagnostic = URL(fileURLWithPath: path + ".log")
                var tunnel: Process?
                var tailcat: TailcatConnection?
                do {
                    defer {
                        tailcat?.stop()
                        if self.connectionIDs[device.id] == generation { self.tailcats[device.id] = nil }
                        if let tunnel, tunnel.isRunning { tunnel.terminate() }
                        if self.connectionIDs[device.id] == generation, self.paths[device.id] == path { self.paths[device.id] = nil; self.tunnels[device.id] = nil }
                        if remote { try? FileManager.default.removeItem(atPath: path); try? FileManager.default.removeItem(at: diagnostic) }
                    }
                    if device.endpoint.kind == "tailcat" {
                        let bridge = try TailcatConnection(device: device.id); tailcat = bridge; self.tailcats[device.id] = bridge; path = bridge.path
                        for _ in 0..<100 {
                            try Task.checkCancellation()
                            if FileManager.default.fileExists(atPath: path) { break }
                            guard bridge.running else { throw Failure("Tailcat transport exited. Check credentials and host availability.") }
                            try await Task.sleep(for: .milliseconds(100))
                        }
                    }
                    if remote {
                        FileManager.default.createFile(atPath: diagnostic.path, contents: nil, attributes: [.posixPermissions: 0o600])
                        let output = try FileHandle(forWritingTo: diagnostic); defer { try? output.close() }
                        let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
                        process.arguments = (device.endpoint.sshConfig.map { ["-F", $0] } ?? []) + ["-N", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10", "-o", "ServerAliveInterval=10", "-o", "ServerAliveCountMax=2", "-o", "ExitOnForwardFailure=yes", "-o", "StreamLocalBindUnlink=yes", "-L", path + ":" + device.endpoint.socketPath] + (device.endpoint.port.map { ["-p", String($0)] } ?? []) + [device.endpoint.target!]
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
                    guard self.connectionIDs[device.id] == generation else { return }
                    let failure = ConnectionIssue(error: error, endpoint: device.endpoint)
                    self.connections[device.id] = .failed(failure.kind == .localStopped ? issue ?? failure : failure)
                    if !failure.automaticallyRetries { return }
                }
                do { try await Task.sleep(for: .seconds(delay)) } catch { return }
                delay = min(30, delay * 2)
            }
        }
    }
    func startLocalHerdr(_ device: Device) {
        guard devices.contains(where: { $0.id == device.id && $0.endpoint == device.endpoint }),
              let target = LocalHerdrTarget(endpoint: device.endpoint),
              connections[device.id]?.issue?.canStart == true,
              !devices.contains(where: { $0.endpoint == device.endpoint && connections[$0.id] == .starting }) else { return }
        detach(device.id)
        let generation = UUID(); connectionIDs[device.id] = generation
        connections[device.id] = .starting
        localStarts[device.id] = Task { [weak self] in
            guard let self else { return }
            var launch: LocalHerdrLaunch?
            do {
                try Task.checkCancellation()
                guard self.connectionIDs[device.id] == generation else { return }
                launch = try LocalHerdrLaunch(target: target)
                let deadline = Date().addingTimeInterval(10)
                while Date() < deadline {
                    try Task.checkCancellation()
                    do {
                        _ = try Session(try await RPC(path: device.endpoint.socketPath).call("session.snapshot", timeout: 1)["snapshot"])
                        try Task.checkCancellation()
                        guard self.connectionIDs[device.id] == generation,
                              self.devices.contains(where: { $0.id == device.id && $0.endpoint == device.endpoint }) else { return }
                        self.localStarts[device.id] = nil
                        self.connect(device)
                        return
                    } catch is CancellationError { throw CancellationError() }
                    catch {
                        if let launch, !launch.process.isRunning {
                            let detail = launch.diagnostic
                            throw Failure(detail.isEmpty ? error.localizedDescription : detail)
                        }
                    }
                    try await Task.sleep(for: .milliseconds(200))
                }
                let detail = launch?.diagnostic ?? ""
                throw Failure(detail.isEmpty ? "Herdr did not become ready within 10 seconds." : detail)
            } catch is CancellationError { return }
            catch {
                guard self.connectionIDs[device.id] == generation,
                      self.devices.contains(where: { $0.id == device.id && $0.endpoint == device.endpoint }) else { return }
                self.localStarts[device.id] = nil
                let kind: ConnectionIssue.Kind = error is LocalHerdrLaunch.MissingExecutable ? .notInstalled : .startFailed
                self.connect(device, preserving: .init(kind, detail: error.localizedDescription))
            }
        }
    }
    func rpc(_ id: String) throws -> RPC { guard let path = paths[id] else { throw Failure("Device is disconnected") }; return RPC(path: path) }
    private var refreshIDs: [String: UUID] = [:]
    func refresh(_ id: String, client: RPC) async throws {
        guard paths[id] == client.path else { throw CancellationError() }
        let connection = connectionIDs[id]
        let token = UUID(); refreshIDs[id] = token
        let snapshot = try await Session.load(client)
        try Task.checkCancellation()
        guard connectionIDs[id] == connection, paths[id] == client.path, refreshIDs[id] == token, devices.contains(where: { $0.id == id }) else { return }
        if sessions[id] != snapshot { let old = sessions[id]; attentionState.update(device: id, old: old, new: snapshot); notifyChanges(device: id, old: old, new: snapshot); sessions[id] = snapshot; reconcile(id, previous: old); reindex() }
        if connections[id] != .connected { connections[id] = .connected }
        if selectedDevice == nil, let space = snapshot.spaces.first { select(device: id, space: space.id) }
        if let device = devices.first(where: { $0.id == id }) { refreshBranches(device, snapshot: snapshot) }
    }
    func select(device: String?, space: String? = nil, tab: String? = nil, pane: PaneKey? = nil) {
        requestFocus()
        let rememberedTab = tab ?? (device == selectedDevice && space == selectedSpace && !selectedTab.isEmpty ? selectedTab : nil)
        let savedMemory = paneMemory
        selectedDevice = device; selectedSpace = space; zoomed = false; draggingLayout = nil
        if let device {
            selectedTab = rememberedTab ?? sessions[device]?.tabs.first { $0.workspace == space }?.id ?? ""
            let panes = sessions[device]?.panes.filter { $0.tab == selectedTab } ?? []
            let candidate = pane ?? savedMemory[device + "|" + selectedTab]
            focused = candidate.flatMap { key in panes.contains(where: { $0.id == key.pane }) ? key : nil } ?? panes.first.map { PaneKey(device: device, pane: $0.id) }
            ensureAttachments()
        } else {
            selectedTab = ""; focused = nil
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

            let args: String
            if pane.agent != nil { args = "agent attach " + quote(pane.id) + " --takeover" }
            else if let terminal = pane.terminal { args = "terminal attach " + quote(terminal) + " --takeover" }
            else { continue }
            let script = "export HERDR_SOCKET_PATH=" + quote(device.endpoint.kind == "tailcat" ? paths[device.id] ?? device.endpoint.socketPath : device.endpoint.socketPath) + "; exec herdr " + args
            let command = device.endpoint.kind == "ssh" ? "exec /usr/bin/ssh " + (device.endpoint.sshConfig.map { "-F " + quote($0) + " " } ?? "") + "-tt " + (device.endpoint.port.map { "-p \($0) " } ?? "") + "\(quote(device.endpoint.target ?? "")) \(quote("/bin/sh -lc " + quote("export PATH=\"$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH\"; " + script)))" : script
            if let terminal = terminals[key] { terminal.command = command } else { makeTerminal(key, command: command) }
        }
    }
    private func makeTerminal(_ key: PaneKey, command: String) {
        let terminal = Terminal(command: command)
        terminal.view.objectMenu = { [weak self] source in self?.paneMenu(key, source: source) }
        terminal.focused = { [weak self] in if self?.focused != key { self?.focused = key } }
        terminal.onExit = { [weak self] status in self?.ended.insert(key); self?.exitStatus[key] = status }
        terminal.process.inputRejected = { [weak self] in self?.message = L("Terminal input is waiting for the process. Try a smaller paste when it responds.") }
        terminals[key] = terminal
    }
    func split(horizontal: Bool, target: PaneKey? = nil) {
        guard let key = target ?? focused, canSplit(horizontal: horizontal, target: key) else { return }
        if selectedDevice != nil {
            let tab = selectedTab, action = key.device + "|pane|" + key.pane
            guard begin(action, device: key.device) else { return }
            let origin = focusRevision, originalFocus = focused, endpoint = currentDevice?.endpoint
            Task { defer { busy.remove(action) }; do {
                let rpc = try rpc(key.device)
                let pane = try await rpc.call("pane.get", ["pane_id": .string(key.pane)])["pane"]
                guard let cwd = pane["foreground_cwd"].string ?? pane["cwd"].string else { throw Failure("Cannot read current directory; split cancelled") }
                guard canWrite(key.device), devices.first(where: { $0.id == key.device })?.endpoint == endpoint,
                      sessions[key.device]?.panes.contains(where: { $0.id == key.pane && $0.tab == tab }) == true else { throw Failure(L("The creation target changed. Try again.")) }
                let result = try await rpc.call("pane.split", ["target_pane_id": .string(key.pane), "direction": .string(horizontal ? "right" : "down"), "cwd": .string(cwd), "focus": .bool(false)])
                try await refresh(key.device, client: rpc)
                if origin == focusRevision, focused == originalFocus, selectedDevice == key.device, selectedTab == tab, let id = result["pane"]["pane_id"].string { zoomed = false; focused = PaneKey(device: key.device, pane: id); requestFocus() }
            } catch { message = error.localizedDescription } }
        }
    }

    func orderedTabs(device: String, space: String?) -> [Item] {
        let tabs = sessions[device]?.tabs.filter { $0.workspace == space } ?? []
        guard let space, let order = tabOrders[device + "|" + space] else { return tabs }
        let byID = Dictionary(uniqueKeysWithValues: tabs.map { ($0.id, $0) })
        return order.visible.compactMap { byID[$0] } + tabs.filter { !order.visible.contains($0.id) }
    }
    func reorderTab(_ source: String, insertion: Int) {
        guard let device = selectedDevice, let space = selectedSpace, canWrite(device),
              sessions[device]?.tabs.contains(where: { $0.id == source && $0.workspace == space }) == true else { return }
        let key = device + "|" + space
        if tabOrders[key] == nil { tabOrders[key] = TabOrder(orderedTabs(device: device, space: space).map(\.id)) }
        tabOrders[key]?.enqueue(source: source, insertion: insertion)
        guard reorderTasks[key] == nil else { return }
        reorderTasks[key] = Task {
            defer { reorderTasks[key] = nil; tabOrders[key] = nil }
            while let order = tabOrders[key], let move = order.pending.first, !Task.isCancelled {
                do {
                    let client = try rpc(device)
                    _ = try await client.call("tab.move", ["tab_id": .string(move.source), "insert_index": .number(Double(order.serverIndex(move)))])
                    try await refresh(device, client: client)
                    let ids = sessions[device]?.tabs.filter { $0.workspace == space }.map(\.id) ?? []
                    tabOrders[key]?.complete(move.id, server: ids)
                } catch { tabOrders[key]?.complete(move.id, server: nil); message = "Tab reorder failed: " + error.localizedDescription }
            }
        }
    }
    func create() {
        guard canCreate else { return }
        guard let id = selectedDevice, let space = selectedSpace else { return }
        let key = creationID(id, space)
        guard begin(key, device: id) else { return }
        let pane = focused, origin = focusRevision
        Task {
            defer { busy.remove(key) }
            do {
                let endpoint = devices.first { $0.id == id }?.endpoint
                let client = try rpc(id)
                guard let pane, pane.device == id else { throw Failure(L("Select a pane before creating a terminal tab.")) }
                let value = try await client.call("pane.get", ["pane_id": .string(pane.pane)])["pane"]
                guard let cwd = value["foreground_cwd"].string ?? value["cwd"].string,
                      canWrite(id), devices.first(where: { $0.id == id })?.endpoint == endpoint,
                      sessions[id]?.panes.contains(where: { $0.id == pane.pane && $0.workspace == space }) == true else { throw Failure(L("The creation target changed. Try again.")) }
                let result = try await client.call("tab.create", ["workspace_id": .string(space), "cwd": .string(cwd), "focus": .bool(false)])
                try await refresh(id, client: client)
                if origin == focusRevision, let paneID = result["root_pane"]["pane_id"].string,
                   let created = sessions[id]?.panes.first(where: { $0.id == paneID }) { select(device: id, space: created.workspace, tab: created.tab) }
            } catch { message = error.localizedDescription }
        }
    }
    func createSpace(device: String, name: String, cwd: String) async throws {
        let key = device + "|createSpace"
        guard cwd.hasPrefix("/"), !cwd.contains(where: { $0.isNewline || $0 == "\0" }), begin(key, device: device) else { throw Failure(L("Connect the selected device and enter an absolute directory.")) }
        defer { busy.remove(key) }
        let origin = focusRevision, client = try rpc(device)
        var params: [String: JSON] = ["focus": .bool(false), "cwd": .string(cwd)]
        if let name = DisplayTitle.clean(name) { params["label"] = .string(name) }
        let result = try await client.call("workspace.create", params)
        try await refresh(device, client: client)
        if origin == focusRevision, let id = result["workspace"]["workspace_id"].string { select(device: device, space: id) }
    }
    func renameSpace(device: String, space: Item) {
        requestRename(device: device, target: .space(id: space.id), current: space.label)
    }
    func perform(_ action: @escaping (RPC) async throws -> Void) {
        guard let id = selectedDevice else { return }
        Task { do { let client = try rpc(id); try await action(client); try await refresh(id, client: client) } catch { message = error.localizedDescription } }
    }
    func closePane(_ target: PaneKey? = nil) {
        guard let key = target ?? focused, canAct(on: key) else { return }
        guard confirmClose(LF("Pane “%@”", paneTitles[key]?.main ?? key.pane), device: key.device, count: 1, action: "Close Pane") else { return }
        objectAction(device: key.device, method: "pane.close", params: ["pane_id": .string(key.pane)])
    }

    func reconcile(_ device: String, previous: Session? = nil) {
        if selectedDevice == device {
            let oldFocus = focused, ownedFocus = focused.flatMap { terminals[$0]?.view } === NSApp.keyWindow?.firstResponder
            selectedSpace = NeighbourSelection.resolve(selectedSpace, previous: previous?.spaces.map(\.id) ?? [], current: sessions[device]?.spaces.map(\.id) ?? [])
            selectedTab = NeighbourSelection.resolve(selectedTab, previous: previous?.tabs.filter { $0.workspace == selectedSpace }.map(\.id) ?? [], current: sessions[device]?.tabs.filter { $0.workspace == selectedSpace }.map(\.id) ?? []) ?? ""
            if sessions[device]?.panes.contains(where: { $0.id == focused?.pane && $0.tab == selectedTab }) != true { focused = sessions[device]?.panes.first { $0.tab == selectedTab }.map { PaneKey(device: device, pane: $0.id) } }
            if ownedFocus, focused != oldFocus { requestFocus() }
            ensureAttachments()
        }
        let valid = Set(sessions[device]?.panes.map(\.id) ?? [])
        for key in Array(terminals.keys) where key.device == device && !valid.contains(key.pane) { terminals.removeValue(forKey: key)?.process.stop(); ended.remove(key) }
    }
    private func rank(_ status: String) -> Int { Attention.rank(status) }
    func reindex() {
        let ordered = devices.flatMap { device -> [AgentRow] in
            guard let session = sessions[device.id] else { return [] }
            let tabs = Dictionary(grouping: session.tabs, by: \.workspace)
            let panes = Dictionary(grouping: session.panes.filter { $0.agent != nil }, by: \.tab)
            return session.spaces.flatMap { space in (tabs[space.id] ?? []).flatMap { tab in (panes[tab.id] ?? []).map { AgentRow(device: device.id, pane: $0) } } }
        }
        let ranked = ordered.enumerated().sorted { (rank($0.element.pane.status), $0.offset) < (rank($1.element.pane.status), $1.offset) }.map(\.element)
        if agents != ranked { agents = ranked }
        var rows: [JumpRow] = []
        var ranks: [String: Int] = [:]
        for device in devices {
            guard let session = sessions[device.id] else { continue }
            rows += session.spaces.map { JumpRow(id: "space|" + device.id + "|" + $0.id, device: device.id, space: $0.id, tab: nil, pane: nil, label: $0.label, detail: DisplayTitle.detail([device.displayName, spacePath(device: device.id, space: $0.id), branches[device.id + "|" + $0.id]])) }
            rows += session.panes.map { pane in JumpRow(id: "pane|" + device.id + "|" + pane.id, device: device.id, space: pane.workspace, tab: pane.tab, pane: pane.id, label: title(device: device.id, pane: pane), detail: DisplayTitle.detail([device.displayName, session.spaces.first { space in space.id == pane.workspace }?.label, pane.agent ?? L("Terminal"), pane.cwd, pane.terminalTitle])) }
            for pane in session.panes { ranks["pane|" + device.id + "|" + pane.id] = rank(pane.status) }
        }
        rows.sort { left, right in
            let a = ranks[left.id] ?? 3, b = ranks[right.id] ?? 3
            let leftType = left.id.hasPrefix("space|") ? 0 : left.pane == nil ? 2 : 1
            let rightType = right.id.hasPrefix("space|") ? 0 : right.pane == nil ? 2 : 1
            return (leftType, a, -(searchActivity[left.id] ?? 0), left.label, left.id) < (rightType, b, -(searchActivity[right.id] ?? 0), right.label, right.id)
        }
        // Branch refreshes and opening Search can reindex identical documents.
        // Only publish derived state when content or search ordering changes.
        if indexedRows != rows {
            indexedRows = rows
            let lookup = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
            if jumpRows != lookup { jumpRows = lookup }
            search.update(documents: rows.map { Search.Document(id: $0.id, name: $0.label, context: $0.detail) })
        }
    }
    func jump(_ value: String) {
        if let row = jumpRows[value] {
            guard valid(row) else { message = L("This terminal is no longer available."); return }
            reveal(device: row.device, space: row.space)
            select(device: row.device, space: row.space, tab: row.tab, pane: row.device.flatMap { device in row.pane.map { PaneKey(device: device, pane: $0) } })
            showSearch = false; return
        }
        let parts = value.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2, let pane = sessions[parts[0]]?.panes.first(where: { $0.id == parts[1] }) else { message = L("This terminal is no longer available."); return }
        reveal(device: parts[0], space: pane.workspace)
        select(device: parts[0], space: pane.workspace, tab: pane.tab, pane: PaneKey(device: parts[0], pane: pane.id)); showSearch = false
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
        if let next = candidates.first { focused = next.0; requestFocus() }
    }
    func changeTab(_ offset: Int) {
        let ids = selectedDevice.flatMap { orderedTabs(device: $0, space: selectedSpace).map(\.id) } ?? []
        guard !ids.isEmpty else { return }; let index = ids.firstIndex(of: selectedTab) ?? 0
        select(device: selectedDevice, space: selectedSpace, tab: ids[(index + offset + ids.count) % ids.count])
    }
    var attentionCandidates: [AgentRow] {
        agents.filter { (deviceFilter.isEmpty || $0.device == deviceFilter) && attentionState.needsAttention($0.id, status: $0.pane.status) }
    }
    func attention() {
        let rows = attentionCandidates
        guard !rows.isEmpty else { return }
        let index = rows.firstIndex { $0.id == focused }
        let next = rows[index.map { ($0 + 1) % rows.count } ?? 0]
        jump(next.device + "|" + next.pane.id)
    }
    func quickSpace() {
        guard !creatingSpace else { return }
        guard let device = creationDevice, canWrite(device), selectedDevice == device,
              let pane = focused, pane.device == device else { showSpaceForm(); return }
        creatingSpace = true
        let endpoint = devices.first { $0.id == device }?.endpoint
        Task {
            defer { creatingSpace = false }
            do {
                let value = try await rpc(device).call("pane.get", ["pane_id": .string(pane.pane)])["pane"]
                guard let cwd = value["foreground_cwd"].string ?? value["cwd"].string,
                      devices.first(where: { $0.id == device })?.endpoint == endpoint,
                      canWrite(device) else { throw Failure(L("The creation target changed. Try again.")) }
                try await createSpace(device: device, name: "", cwd: cwd)
            } catch { message = error.localizedDescription }
        }
    }
    private func notifyChanges(device: String, old: Session?, new: Session) {
        guard UserDefaults.standard.bool(forKey: "notifications"), let old else { return }
        let previous = Dictionary(uniqueKeysWithValues: old.panes.map { ($0.id, $0.status) })
        for pane in new.panes where pane.agent != nil && ["blocked", "done"].contains(pane.status) && previous[pane.id] != nil && previous[pane.id] != pane.status {
            if NSApp.isActive, focused == PaneKey(device: device, pane: pane.id) { continue }
            let content = UNMutableNotificationContent(); content.userInfo = ["device": device, "pane": pane.id]; content.title = title(device: device, pane: pane); content.body = L(pane.status == "blocked" ? "Needs your input" : "Finished"); if !UserDefaults.standard.bool(forKey: "silentNotifications") { content.sound = .default }
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }
    func applicationHidden() {
        hiddenTask?.cancel()
        hiddenTask = Task {
            do { try await Task.sleep(for: .milliseconds(1500)) } catch { return }
            guard NSApp.isHidden else { return }
            // Keep attachment ownership. Hidden surfaces stop drawing without
            // detaching and later stealing a pane from another client.
            terminals.values.forEach { $0.visible(false) }
        }
    }
    func applicationShown() {
        hiddenTask?.cancel(); hiddenTask = nil
        objectWillChange.send()
    }
    func shutdown() { discoveryTask?.cancel(); hiddenTask?.cancel(); reorderTasks.values.forEach { $0.cancel() }; layoutTask?.cancel(); Array(polls.keys).forEach { detach($0) }; terminals.values.forEach { $0.process.stop() } }
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
