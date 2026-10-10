import SwiftUI
import AppKit
import HerdCore

@MainActor
final class FileBrowser: ObservableObject {
    @Published var root = ""
    @Published var rows: [String: [FileEntry]] = [:]
    @Published var expanded: Set<String> = []
    @Published var hidden = false
    @Published var selected: FileEntry?
    @Published var text: String?
    @Published var image: NSImage?
    @Published var error: String?
    @Published var loading = false
    var service = FileService()
    private var generation = UUID()
    private var previewID = UUID()
    private var pending: Set<String> = []
    func open(endpoint: Device.Endpoint, path: String?) async {
        let token = UUID(); generation = token; previewID = UUID(); pending = []; rows = [:]; expanded = []; selected = nil; text = nil; image = nil; error = nil; loading = true
        service = FileService(endpoint: endpoint)
        do {
            let resolved: String
            if let path { resolved = path } else { resolved = try await service.home() }
            guard generation == token, !Task.isCancelled else { return }
            root = resolved
            let entries = try await service.list(resolved, hidden: hidden)
            guard generation == token, !Task.isCancelled else { return }
            rows[resolved] = entries
        } catch { if generation == token, !Task.isCancelled { self.error = error.localizedDescription } }
        if generation == token { loading = false }
    }
    func toggle(_ entry: FileEntry) {
        guard entry.kind == "directory" else { show(entry); return }
        if expanded.remove(entry.path) != nil { return }
        expanded.insert(entry.path)
        guard rows[entry.path] == nil, !pending.contains(entry.path) else { return }
        pending.insert(entry.path)
        let token = generation, service = service, hidden = hidden
        Task {
            do { let children = try await service.list(entry.path, hidden: hidden); guard token == generation else { return }; rows[entry.path] = children }
            catch { if token == generation { self.error = error.localizedDescription; expanded.remove(entry.path) } }
            if token == generation { pending.remove(entry.path) }
        }
    }
    func show(_ entry: FileEntry) {
        selected = entry; text = nil; image = nil; error = nil
        let token = UUID(), rootToken = generation, service = service; previewID = token
        Task {
            do {
                let bytes = try await service.preview(entry.path)
                guard token == previewID, rootToken == generation else { return }
                if let image = NSImage(data: bytes) { self.image = image }
                else if ["png", "jpg", "jpeg", "gif", "webp", "heic", "tiff", "bmp"].contains(URL(fileURLWithPath: entry.path).pathExtension.lowercased()) { error = "The image could not be decoded." }
                else if let text = String(data: bytes, encoding: .utf8), !text.contains("\0") { self.text = text }
                else { error = "This file is binary or is not valid UTF-8. It cannot be previewed." }
            } catch { if token == previewID, rootToken == generation { self.error = error.localizedDescription } }
        }
    }
    func cancel() { generation = UUID(); previewID = UUID() }
}

struct FilesPanel: View {
    let endpoint: Device.Endpoint
    let path: String?
    let close: () -> Void
    @StateObject private var browser = FileBrowser()
    private var request: [String] { [endpoint.kind, endpoint.target ?? "", endpoint.port.map(String.init) ?? "", endpoint.sshConfig ?? "", endpoint.socketPath, path ?? ""] }
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    if geometry.size.width < 520, browser.selected != nil { Button { browser.selected = nil; browser.error = nil } label: { Image(systemName: "arrow.left") }.help("Back to directory") }
                    Text("Files").font(.system(size: 12, weight: .medium)); Spacer()
                    Toggle(isOn: $browser.hidden) { Image(systemName: "eye") }.toggleStyle(.button).help("Show hidden files")
                    Button { reload() } label: { Image(systemName: "arrow.clockwise") }.help("Refresh")
                    Button(action: close) { Image(systemName: "xmark") }.help("Close Files · ⌘⇧E")
                }.buttonStyle(.borderless).padding(.horizontal, 10).frame(height: 36)
                Text(browser.root).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle).textSelection(.enabled).help(browser.root).padding(.horizontal, 10)
                Divider()
                if browser.loading { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
                else if geometry.size.width >= 520 {
                    HStack(spacing: 0) { tree.frame(width: 210); Divider(); preview }
                } else if browser.selected != nil { preview }
                else { tree }
            }
        }.background(Color(nsColor: .windowBackgroundColor), ignoresSafeAreaEdges: [])
        .task(id: request) { await browser.open(endpoint: endpoint, path: path) }
        .onChange(of: browser.hidden) { reload() }.onDisappear { browser.cancel() }
    }
    func reload() { Task { await browser.open(endpoint: endpoint, path: path) } }
    var tree: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let error = browser.error { Text(LocalizedStringKey(error)).font(.caption).foregroundStyle(.secondary).padding(10) }
                if browser.rows[browser.root]?.isEmpty == true { Text("Empty directory").foregroundStyle(.secondary).padding(10) }
                FileTree(path: browser.root, depth: 0, browser: browser)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    var preview: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let selected = browser.selected { Text(selected.name).font(.headline).lineLimit(2); Text(ByteCountFormatter.string(fromByteCount: selected.size, countStyle: .file)).font(.caption).foregroundStyle(.secondary) }
            if let error = browser.error { Text(LocalizedStringKey(error)).foregroundStyle(.secondary).textSelection(.enabled) }
            else if let image = browser.image { ScrollView([.horizontal, .vertical]) { Image(nsImage: image).resizable().scaledToFit() } }
            else if let text = browser.text { ScrollView([.horizontal, .vertical]) { Text(text.isEmpty ? L("Empty file") : text).font(.system(size: 12, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) } }
            else if browser.selected != nil { ProgressView() }
            else { Text("Select a file to preview").foregroundStyle(.secondary) }
            Spacer(minLength: 0)
        }.padding(12).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
private struct FileTree: View {
    let path: String
    let depth: Int
    @ObservedObject var browser: FileBrowser
    var body: some View {
        ForEach(browser.rows[path] ?? []) { entry in
            Button { browser.toggle(entry) } label: {
                HStack(spacing: 6) {
                    Image(systemName: entry.kind == "directory" ? browser.expanded.contains(entry.path) ? "folder.fill" : "folder" : entry.kind == "symlink" ? "link" : "doc").frame(width: 14)
                    Text(entry.name).lineLimit(1).truncationMode(.middle); Spacer(minLength: 0)
                }.font(.system(size: 12)).padding(.leading, CGFloat(depth * 12 + 10)).padding(.trailing, 8).frame(height: 28).contentShape(Rectangle())
                    .background(browser.selected?.path == entry.path ? Color.accentColor.opacity(0.18) : .clear)
            }.buttonStyle(.plain).help(entry.path)
            if browser.expanded.contains(entry.path) { AnyView(FileTree(path: entry.path, depth: depth + 1, browser: browser)) }
        }
    }
}

struct FileManagerSheet: View {
    @EnvironmentObject var desk: Desk
    @Environment(\.dismiss) private var dismiss
    @State private var device = ""
    @State private var localPath = NSHomeDirectory()
    @State private var remotePath = ""
    @State private var localRows: [FileEntry] = []
    @State private var remoteRows: [FileEntry] = []
    @State private var localSelection: String?
    @State private var remoteSelection: String?
    @State private var hidden = false
    @State private var conflict = FileConflict.cancel
    @State private var status = ""
    @State private var transferred: Int64 = 0
    @State private var total: Int64 = 0
    @State private var transfer: Task<Void, Never>?
    @State private var requestID = UUID()
    @State private var localHistory: [String] = []
    @State private var remoteHistory: [String] = []
    @State private var loadedLocal = ""
    @State private var loadedRemote = ""
    var remote: FileService { FileService(endpoint: desk.devices.first { $0.id == device }?.endpoint ?? .init(kind: "unavailable", socketPath: "")) }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("File Manager").font(.title2); Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.cancelAction).disabled(transfer != nil) }
            Picker("Target Device", selection: $device) { Text("Select device").tag(""); ForEach(desk.devices) { Text($0.displayName).tag($0.id) } }.disabled(transfer != nil)
            HStack {
                listing("This Mac", path: $localPath, rows: localRows, selection: $localSelection, local: true)
                listing("Target", path: $remotePath, rows: remoteRows, selection: $remoteSelection, local: false)
            }
            HStack {
                Toggle("Hidden files", isOn: $hidden)
                Picker("If destination exists", selection: $conflict) { Text("Cancel").tag(FileConflict.cancel); Text("Replace").tag(FileConflict.replace); Text("Keep Both").tag(FileConflict.keepBoth) }
            }.disabled(transfer != nil)
            HStack {
                Button("Upload →") { copy(upload: true) }.disabled(transfer != nil || !regular(localRows, localSelection) || remotePath.isEmpty)
                Button("← Download") { copy(upload: false) }.disabled(transfer != nil || !regular(remoteRows, remoteSelection))
                Spacer()
                if transfer != nil { ProgressView(value: Double(transferred), total: Double(max(total, 1))).frame(width: 130); Button("Cancel Transfer") { transfer?.cancel() } }
                Text("\(transferred) / \(total) bytes").font(.caption).monospacedDigit()
            }
            Text(LocalizedStringKey(status)).font(.caption).textSelection(.enabled)
        }.padding(20).frame(width: 800, height: 560)
        .task(id: device) { remotePath = ""; remoteHistory = []; loadedRemote = ""; await reload() }
        .onChange(of: hidden) { Task { await reload() } }
        .onDisappear { requestID = UUID(); transfer?.cancel() }
    }
    func regular(_ rows: [FileEntry], _ id: String?) -> Bool { rows.contains { $0.path == id && $0.kind == "file" } }
    func listing(_ title: String, path: Binding<String>, rows: [FileEntry], selection: Binding<String?>, local: Bool) -> some View {
        VStack(alignment: .leading) {
            Text(LocalizedStringKey(title)).font(.headline)
            HStack {
                Button {
                    if local, let previous = localHistory.popLast() { localPath = previous }
                    if !local, let previous = remoteHistory.popLast() { remotePath = previous }
                    Task { await reload(recordHistory: false) }
                } label: { Image(systemName: "arrow.left") }.disabled(local ? localHistory.isEmpty : remoteHistory.isEmpty).help("Back")
                Button { path.wrappedValue = URL(fileURLWithPath: path.wrappedValue).deletingLastPathComponent().path; Task { await reload() } } label: { Image(systemName: "arrow.up") }.help("Parent directory")
                TextField("Absolute directory", text: path).onSubmit { Task { await reload() } }
                Button { Task { await reload() } } label: { Image(systemName: "arrow.clockwise") }.help("Refresh")
            }
            HStack { Text("Name").frame(maxWidth: .infinity, alignment: .leading); Text("Size").frame(width: 60, alignment: .trailing); Text("Modified").frame(width: 95, alignment: .trailing) }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 10)
            List(rows, selection: selection) { entry in
                HStack(spacing: 4) {
                    Image(systemName: entry.kind == "directory" ? "folder" : entry.kind == "symlink" ? "link" : "doc")
                    Text(entry.name).lineLimit(1).truncationMode(.middle).frame(maxWidth: .infinity, alignment: .leading)
                    Text(entry.kind == "file" ? ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file) : "—").font(.caption).frame(width: 60, alignment: .trailing)
                    Text(Date(timeIntervalSince1970: entry.modified), format: .dateTime.month(.twoDigits).day(.twoDigits).hour().minute()).font(.system(size: 10)).foregroundStyle(.secondary).frame(width: 95, alignment: .trailing)
                }.tag(entry.path).help(entry.path + "\n" + Date(timeIntervalSince1970: entry.modified).formatted()).onTapGesture(count: 2) { if entry.kind == "directory" { path.wrappedValue = entry.path; Task { await reload() } } }
            }
        }.disabled(transfer != nil)
    }
    func reload(recordHistory: Bool = true) async {
        let token = UUID(); requestID = token; let service = remote, nextLocal = localPath, nextRemote = remotePath, showHidden = hidden
        do {
            let local = try await FileService().list(nextLocal, hidden: showHidden)
            guard token == requestID, !Task.isCancelled else { return }
            if recordHistory, !loadedLocal.isEmpty, loadedLocal != nextLocal { localHistory.append(loadedLocal) }
            loadedLocal = nextLocal; localRows = local; localSelection = nil
            guard !device.isEmpty else { remoteRows = []; status = "Select a target device to transfer files."; return }
            let path = try await nextRemote.isEmpty ? service.home() : nextRemote
            let other = try await service.list(path, hidden: showHidden)
            guard token == requestID, !Task.isCancelled else { return }
            if recordHistory, !loadedRemote.isEmpty, loadedRemote != path { remoteHistory.append(loadedRemote) }
            loadedRemote = path; remoteRows = other; remotePath = path; remoteSelection = nil; status = ""
        } catch { if token == requestID, !Task.isCancelled { status = error.localizedDescription; remoteRows = []; remoteSelection = nil } }
    }
    func copy(upload: Bool) {
        guard let path = upload ? localSelection : remoteSelection else { return }
        let source = upload ? FileService() : remote, target = upload ? remote : FileService()
        let dest = URL(fileURLWithPath: upload ? remotePath : localPath).appendingPathComponent(URL(fileURLWithPath: path).lastPathComponent).path
        transferred = 0; total = 0; status = "Transferring…"
        transfer = Task {
            defer { transfer = nil }
            do {
                let result = try await source.transfer(path, to: target, destination: dest, conflict: conflict) { done, size in await MainActor.run { transferred = done; total = size } }
                await reload(); status = "Completed: " + result
            } catch is CancellationError { status = "Cancelled. Partial file removed; destination unchanged." }
            catch { status = "Transfer failed: " + error.localizedDescription }
        }
    }
}
